import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:precise_compass/src/api/compass_capabilities.dart';
import 'package:precise_compass/src/api/compass_config.dart';
import 'package:precise_compass/src/api/enums.dart';
import 'package:precise_compass/src/domain/fusion/source_selector.dart';
import 'package:precise_compass/src/models/raw_compass_data.dart';

/// The boundary between the package and a platform implementation.
///
/// This is the seam that keeps the door open for a future federated split
/// (`precise_compass_android`, `_ios`, `_web`) without changing the public API.
/// Swap [instance] in tests to inject a fake.
abstract class CompassPlatform {
  /// The active platform implementation. Defaults to the method/event channel
  /// implementation; replace it in tests.
  static CompassPlatform instance = MethodChannelCompassPlatform();

  /// A stream of raw, undecorated samples from the native sensors.
  ///
  /// Implementations must register sensors lazily on first listen and release
  /// them on cancel. [config] controls rate, fusion mode and HUD behavior.
  Stream<RawCompassData> rawHeadingStream(CompassConfig config);

  /// Probes the device's heading-related hardware capabilities.
  Future<CompassCapabilities> capabilities();
}

/// The default [CompassPlatform] backed by Flutter platform channels.
class MethodChannelCompassPlatform extends CompassPlatform {
  /// Event channel carrying the raw heading sample stream.
  @visibleForTesting
  static const EventChannel eventChannel =
      EventChannel('precise_compass/events');

  /// Method channel for one-shot calls (capability probe).
  @visibleForTesting
  static const MethodChannel methodChannel =
      MethodChannel('precise_compass/methods');

  @override
  Stream<RawCompassData> rawHeadingStream(CompassConfig config) {
    return eventChannel
        .receiveBroadcastStream(encodeConfig(config))
        .map((dynamic event) {
      final map = (event as Map).cast<Object?, Object?>();
      return RawCompassData.fromMap(map);
    });
  }

  @override
  Future<CompassCapabilities> capabilities() async {
    final result = await methodChannel
        .invokeMapMethod<Object?, Object?>('getCapabilities');
    return decodeCapabilities(result);
  }

  /// Encodes [config] into the primitive map sent to native code as the event
  /// channel's listen arguments. Enum values travel as their `name` for
  /// forward-compatibility.
  @visibleForTesting
  static Map<String, Object?> encodeConfig(CompassConfig config) => {
        'reference': config.reference.name,
        'fusionMode': config.fusionMode.name,
        'rate': config.rate.name,
        'detectCalibration': config.detectCalibration,
        'suppressIosCalibrationHud': config.suppressIosCalibrationHud,
        'magneticFieldMin': config.magneticFieldBand.min,
        'magneticFieldMax': config.magneticFieldBand.max,
      };

  /// Decodes the native capabilities map, computing [recommendFusionMode] for
  /// the recommended mode. A `null`/empty map yields
  /// [CompassCapabilities.none].
  @visibleForTesting
  static CompassCapabilities decodeCapabilities(Map<Object?, Object?>? map) {
    if (map == null || map.isEmpty) return CompassCapabilities.none();
    bool flag(String key) => map[key] == true;

    final partial = CompassCapabilities(
      hasRotationVector: flag('hasRotationVector'),
      hasGeomagneticRotationVector: flag('hasGeomagneticRotationVector'),
      hasMagnetometer: flag('hasMagnetometer'),
      hasGyroscope: flag('hasGyroscope'),
      hasAccelerometer: flag('hasAccelerometer'),
      supportsTrueHeading: flag('supportsTrueHeading'),
      recommendedMode: FusionMode.auto,
    );
    return CompassCapabilities(
      hasRotationVector: partial.hasRotationVector,
      hasGeomagneticRotationVector: partial.hasGeomagneticRotationVector,
      hasMagnetometer: partial.hasMagnetometer,
      hasGyroscope: partial.hasGyroscope,
      hasAccelerometer: partial.hasAccelerometer,
      supportsTrueHeading: partial.supportsTrueHeading,
      recommendedMode: recommendFusionMode(partial),
    );
  }
}
