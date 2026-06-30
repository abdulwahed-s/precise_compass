// MIT License — part of precise_compass.
import CoreLocation
import CoreMotion
import Flutter
import UIKit

/// Acquires heading from CoreLocation (and pitch/roll from CoreMotion) and emits
/// a versioned payload over an event channel. All fusion/accuracy/calibration
/// logic lives in pure Dart; this layer only delivers raw native signals,
/// including the continuous `CLHeading.headingAccuracy` and the magnetic-field
/// magnitude derived from `CLHeading.{x,y,z}`.
public class PreciseCompassPlugin: NSObject, FlutterPlugin, FlutterStreamHandler,
  CLLocationManagerDelegate
{
  private var eventSink: FlutterEventSink?
  private let locationManager = CLLocationManager()
  private let motionManager = CMMotionManager()
  private var suppressCalibrationHud = false

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.headingFilter = 1
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PreciseCompassPlugin()
    let events = FlutterEventChannel(
      name: "precise_compass/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    let methods = FlutterMethodChannel(
      name: "precise_compass/methods", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
  }

  // MARK: - MethodChannel

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCapabilities":
      result(capabilities())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func capabilities() -> [String: Any] {
    return [
      "hasRotationVector": motionManager.isDeviceMotionAvailable,
      "hasGeomagneticRotationVector": false,
      "hasMagnetometer": motionManager.isMagnetometerAvailable
        || CLLocationManager.headingAvailable(),
      "hasGyroscope": motionManager.isGyroAvailable,
      "hasAccelerometer": motionManager.isAccelerometerAvailable,
      "supportsTrueHeading": CLLocationManager.headingAvailable(),
    ]
  }

  // MARK: - EventChannel

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    if let args = arguments as? [String: Any] {
      suppressCalibrationHud = args["suppressIosCalibrationHud"] as? Bool ?? false
      if let rate = args["rate"] as? String {
        locationManager.headingFilter = headingFilter(for: rate)
      }
    }
    guard CLLocationManager.headingAvailable() else {
      events(unavailablePayload())
      return nil
    }
    if motionManager.isDeviceMotionAvailable {
      motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
      motionManager.startDeviceMotionUpdates()
    }
    locationManager.startUpdatingHeading()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    locationManager.stopUpdatingHeading()
    motionManager.stopDeviceMotionUpdates()
    eventSink = nil
    return nil
  }

  // MARK: - CLLocationManagerDelegate

  public func locationManager(
    _ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading
  ) {
    guard let sink = eventSink else { return }
    let offset = interfaceOrientationOffset()

    var payload: [String: Any] = [
      "source": 3,  // platformHeading
      "magneticHeading": normalize(newHeading.magneticHeading + offset),
      "accuracyDegrees": newHeading.headingAccuracy,  // < 0 => Dart treats unknown
      "timestamp": Int(Date().timeIntervalSince1970 * 1000),
    ]
    if newHeading.trueHeading >= 0 {
      payload["trueHeading"] = normalize(newHeading.trueHeading + offset)
    }
    let magnitude = (newHeading.x * newHeading.x + newHeading.y * newHeading.y
      + newHeading.z * newHeading.z).squareRoot()
    if magnitude > 0 {
      payload["magneticFieldMagnitude"] = magnitude
    }
    if let attitude = motionManager.deviceMotion?.attitude {
      payload["pitch"] = attitude.pitch * 180.0 / Double.pi
      payload["roll"] = attitude.roll * 180.0 / Double.pi
    }
    sink(payload)
  }

  /// Driven by `CompassConfig.suppressIosCalibrationHud`: returning `true` lets
  /// iOS present its polished figure-8 calibration HUD.
  public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
    return !suppressCalibrationHud
  }

  // MARK: - Helpers

  private func headingFilter(for rate: String) -> CLLocationDegrees {
    switch rate {
    case "fastest": return kCLHeadingFilterNone
    case "ui": return 1
    case "normal": return 2
    case "batterySaving": return 5
    default: return 1
    }
  }

  private func interfaceOrientationOffset() -> Double {
    var orientation: UIInterfaceOrientation = .portrait
    if #available(iOS 13.0, *) {
      orientation =
        UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.interfaceOrientation ?? .portrait
    } else {
      orientation = UIApplication.shared.statusBarOrientation
    }
    switch orientation {
    case .portraitUpsideDown: return 180
    case .landscapeLeft: return -90
    case .landscapeRight: return 90
    default: return 0
    }
  }

  private func normalize(_ degrees: Double) -> Double {
    let remainder = degrees.truncatingRemainder(dividingBy: 360)
    return remainder < 0 ? remainder + 360 : remainder
  }

  private func unavailablePayload() -> [String: Any] {
    return [
      "source": -1,
      "accuracyDegrees": -1.0,
      "timestamp": Int(Date().timeIntervalSince1970 * 1000),
    ]
  }
}
