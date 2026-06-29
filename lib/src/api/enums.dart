/// Public enumerations used across the `precise_compass` API.
///
/// All values are documented with their precise meaning so callers can rely on
/// them without reading the implementation.
library;

/// A normalized, coarse classification of heading quality derived from the
/// continuous `CompassReading.accuracyDegrees` estimate.
///
/// Prefer reasoning about the continuous value where possible; this bucket
/// exists for simple UI affordances (e.g. a colored indicator).
///
/// The default thresholds are documented on
/// [CompassAccuracy.fromDegrees].
enum CompassAccuracy {
  /// Heading is trustworthy. Default threshold: estimate `<= 10°`.
  high,

  /// Heading is usable but noticeably uncertain. Default threshold: `<= 20°`.
  medium,

  /// Heading is rough; treat with caution. Default threshold: `<= 45°`.
  low,

  /// Heading is not trustworthy (e.g. strong interference, no calibration).
  /// Default: estimate `> 45°`, or a platform-reported invalid estimate.
  unreliable,

  /// No accuracy estimate is available (e.g. before the first reading, or a
  /// device that does not report one).
  unknown;

  /// Maps a continuous accuracy [degrees] value to a coarse bucket.
  ///
  /// [degrees] is the estimated heading error (`±`, lower is better). A `null`
  /// or negative value yields [CompassAccuracy.unknown] (no estimate). The
  /// thresholds are inclusive on the upper bound:
  ///
  /// | estimate (°) | bucket |
  /// |---|---|
  /// | `<= 10` | [high] |
  /// | `<= 20` | [medium] |
  /// | `<= 45` | [low] |
  /// | `> 45` | [unreliable] |
  static CompassAccuracy fromDegrees(double? degrees) {
    if (degrees == null || degrees.isNaN || degrees < 0) {
      return CompassAccuracy.unknown;
    }
    if (degrees <= 10) return CompassAccuracy.high;
    if (degrees <= 20) return CompassAccuracy.medium;
    if (degrees <= 45) return CompassAccuracy.low;
    return CompassAccuracy.unreliable;
  }
}

/// Which north a heading is measured against.
enum HeadingReference {
  /// Geographic ("true") north. Requires location to compute declination, and
  /// is only produced when the platform/device can supply it.
  trueNorth,

  /// Magnetic north (the raw sensor reference). Always available where a
  /// magnetometer exists.
  magnetic,

  /// Use true north when available, otherwise fall back to magnetic. This is
  /// the default and is reflected by `CompassReading.heading`.
  auto,
}

/// The concrete signal path that produced a `CompassReading`.
///
/// Exposed so apps can show *how* a heading was derived and adapt their UI.
enum HeadingSource {
  /// Android `TYPE_ROTATION_VECTOR` (OS sensor fusion of gyro + accel + mag).
  /// Highest fidelity; also the source of the keystone `values[4]` accuracy.
  rotationVector,

  /// Android `TYPE_GEOMAGNETIC_ROTATION_VECTOR` (accel + mag, no gyro).
  /// Lower power, slightly noisier; no gyro drift correction.
  geomagnetic,

  /// The package's own complementary filter fusing gyroscope dead-reckoning
  /// with tilt-compensated magnetometer fixes.
  fusion,

  /// A platform-native heading API (iOS `CLHeading`).
  platformHeading,

  /// No usable heading source is available on this device. The reading carries
  /// [CompassAccuracy.unknown] and a confidence of `0`.
  unavailable,
}

/// Requested sensor sampling rate.
///
/// This is a *hint*; the OS may deliver faster or slower. Higher rates cost
/// more battery.
enum SensorRate {
  /// As fast as the sensor allows. Highest battery cost.
  fastest,

  /// Suitable for a smoothly animating UI (~60 Hz target).
  ui,

  /// A balanced default (~30 Hz target).
  normal,

  /// Reduced rate for background or battery-sensitive use (~10 Hz target).
  batterySaving;

  /// The nominal target sampling period for this rate.
  Duration get samplingPeriod => switch (this) {
        SensorRate.fastest => const Duration(milliseconds: 5),
        SensorRate.ui => const Duration(milliseconds: 16),
        SensorRate.normal => const Duration(milliseconds: 33),
        SensorRate.batterySaving => const Duration(milliseconds: 100),
      };
}

/// The fusion strategy used to produce headings.
enum FusionMode {
  /// Use the OS rotation-vector fusion ([HeadingSource.rotationVector]).
  rotationVector,

  /// Use the low-power geomagnetic rotation vector
  /// ([HeadingSource.geomagnetic]).
  geomagnetic,

  /// Use the package's manual complementary filter ([HeadingSource.fusion]).
  fusion,

  /// Let the package pick the best available source per device and conditions.
  /// This is the default.
  auto,
}

/// Structured calibration progress, for apps that render their own figure-8
/// prompt instead of (or alongside) the OS HUD.
enum CalibrationStatus {
  /// Not yet determined (e.g. before enough samples have arrived).
  unknown,

  /// The compass is currently poorly calibrated; a figure-8 motion is advised.
  calibrating,

  /// The compass is well calibrated.
  calibrated,
}
