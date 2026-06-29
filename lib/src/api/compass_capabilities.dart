import 'package:meta/meta.dart';
import 'package:precise_compass/src/api/enums.dart';

/// A one-shot description of what a device can do for heading estimation.
///
/// Obtain it via `PreciseCompass.capabilities()`. Use it to decide whether to
/// offer true-heading features, a low-power mode, or a custom calibration UI.
@immutable
class CompassCapabilities {
  /// Creates a capabilities snapshot.
  const CompassCapabilities({
    required this.hasRotationVector,
    required this.hasGeomagneticRotationVector,
    required this.hasMagnetometer,
    required this.hasGyroscope,
    required this.hasAccelerometer,
    required this.supportsTrueHeading,
    required this.recommendedMode,
  });

  /// Capabilities for a device with no usable heading hardware.
  factory CompassCapabilities.none() => const CompassCapabilities(
        hasRotationVector: false,
        hasGeomagneticRotationVector: false,
        hasMagnetometer: false,
        hasGyroscope: false,
        hasAccelerometer: false,
        supportsTrueHeading: false,
        recommendedMode: FusionMode.auto,
      );

  /// Whether the OS rotation-vector sensor is present (Android
  /// `TYPE_ROTATION_VECTOR`; assumed present on iOS via `CLHeading`).
  final bool hasRotationVector;

  /// Whether the low-power geomagnetic rotation vector is present (Android
  /// `TYPE_GEOMAGNETIC_ROTATION_VECTOR`).
  final bool hasGeomagneticRotationVector;

  /// Whether a magnetometer is present.
  final bool hasMagnetometer;

  /// Whether a gyroscope is present (required for the manual complementary
  /// [FusionMode.fusion]).
  final bool hasGyroscope;

  /// Whether an accelerometer is present.
  final bool hasAccelerometer;

  /// Whether true (geographic) heading can be produced on this device. On both
  /// platforms this generally requires location services.
  final bool supportsTrueHeading;

  /// The fusion mode the package recommends for this device, used when
  /// [FusionMode.auto] is requested.
  final FusionMode recommendedMode;

  /// Whether any heading source at all is available.
  bool get hasAnyHeadingSource =>
      hasRotationVector ||
      hasGeomagneticRotationVector ||
      (hasMagnetometer && hasAccelerometer);

  @override
  bool operator ==(Object other) =>
      other is CompassCapabilities &&
      other.hasRotationVector == hasRotationVector &&
      other.hasGeomagneticRotationVector == hasGeomagneticRotationVector &&
      other.hasMagnetometer == hasMagnetometer &&
      other.hasGyroscope == hasGyroscope &&
      other.hasAccelerometer == hasAccelerometer &&
      other.supportsTrueHeading == supportsTrueHeading &&
      other.recommendedMode == recommendedMode;

  @override
  int get hashCode => Object.hash(
        hasRotationVector,
        hasGeomagneticRotationVector,
        hasMagnetometer,
        hasGyroscope,
        hasAccelerometer,
        supportsTrueHeading,
        recommendedMode,
      );

  @override
  String toString() =>
      'CompassCapabilities(rotationVector: $hasRotationVector, '
      'geomagnetic: $hasGeomagneticRotationVector, '
      'magnetometer: $hasMagnetometer, gyroscope: $hasGyroscope, '
      'accelerometer: $hasAccelerometer, trueHeading: $supportsTrueHeading, '
      'recommended: $recommendedMode)';
}
