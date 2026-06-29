import 'package:meta/meta.dart';
import 'package:precise_compass/src/api/enums.dart';

/// A single, immutable compass heading sample.
///
/// Every field carries explicit units, ranges and null-semantics so callers
/// never have to guess how trustworthy a reading is. The defining feature of
/// `precise_compass` is that [accuracyDegrees] and [confidence] are *honest,
/// continuous* signals rather than a coarse, sticky OS status.
///
/// All angular fields are normalized to the half-open range `[0, 360)` degrees,
/// measured clockwise from north.
@immutable
class CompassReading {
  /// Creates a reading. Prefer the platform pipeline over constructing these
  /// directly; the constructor is public to support testing and custom sources.
  const CompassReading({
    required this.headingMagnetic,
    required this.headingTrue,
    required this.heading,
    required this.accuracyDegrees,
    required this.accuracy,
    required this.confidence,
    required this.shouldCalibrate,
    required this.calibrationStatus,
    required this.source,
    required this.magneticFieldMagnitude,
    required this.pitch,
    required this.roll,
    required this.timestamp,
  });

  /// A placeholder reading for devices/states with no usable heading.
  ///
  /// Carries [HeadingSource.unavailable], [CompassAccuracy.unknown] and a
  /// [confidence] of `0`. Emitted instead of throwing, so a `null`-free,
  /// always-on stream can degrade gracefully.
  factory CompassReading.unavailable({DateTime? timestamp}) => CompassReading(
        headingMagnetic: null,
        headingTrue: null,
        heading: double.nan,
        accuracyDegrees: -1,
        accuracy: CompassAccuracy.unknown,
        confidence: 0,
        shouldCalibrate: false,
        calibrationStatus: CalibrationStatus.unknown,
        source: HeadingSource.unavailable,
        magneticFieldMagnitude: null,
        pitch: null,
        roll: null,
        timestamp: timestamp ?? DateTime.now(),
      );

  /// Magnetic heading in degrees `[0, 360)`, or `null` if no magnetometer
  /// reading is available.
  final double? headingMagnetic;

  /// True (geographic) heading in degrees `[0, 360)`, or `null` if location /
  /// declination is unavailable on this device.
  final double? headingTrue;

  /// Convenience heading: [headingTrue] when available, else [headingMagnetic].
  ///
  /// Is [double.nan] only when [source] is [HeadingSource.unavailable].
  final double heading;

  /// Estimated heading error in degrees (`±`); **lower is better**.
  ///
  /// On Android this is derived from `TYPE_ROTATION_VECTOR.values[4]`
  /// (radians → degrees); on iOS from `CLHeading.headingAccuracy`. A value of
  /// `-1` means no estimate is available.
  final double accuracyDegrees;

  /// The coarse bucket derived from [accuracyDegrees] via
  /// [CompassAccuracy.fromDegrees].
  final CompassAccuracy accuracy;

  /// A single, developer-friendly trust score in `[0.0, 1.0]`.
  ///
  /// `1.0` is excellent; `0.0` is untrustworthy. Fuses accuracy, magnetic-field
  /// plausibility, short-term stability and source quality. See `ARCHITECTURE`.
  final double confidence;

  /// Whether a calibration (figure-8) motion is recommended *right now*.
  ///
  /// Debounced with hysteresis to avoid flicker — see [calibrationStatus] for
  /// the underlying state.
  final bool shouldCalibrate;

  /// Structured calibration state for custom calibration UIs.
  final CalibrationStatus calibrationStatus;

  /// Which signal path produced this reading.
  final HeadingSource source;

  /// Ambient magnetic field magnitude in microtesla (µT), or `null` if not
  /// measured. Earth's field is ≈ 25–65 µT; values far outside that band
  /// indicate interference.
  final double? magneticFieldMagnitude;

  /// Device pitch in degrees `[-180, 180]`, or `null` if not provided.
  /// Useful for AR overlays. Sign and axis follow the platform convention.
  final double? pitch;

  /// Device roll in degrees `[-180, 180]`, or `null` if not provided.
  final double? roll;

  /// When this reading was produced (device-local time).
  final DateTime timestamp;

  /// Whether this reading carries a usable heading.
  bool get hasHeading => source != HeadingSource.unavailable && !heading.isNaN;

  /// Returns a copy with the given fields replaced.
  CompassReading copyWith({
    double? headingMagnetic,
    double? headingTrue,
    double? heading,
    double? accuracyDegrees,
    CompassAccuracy? accuracy,
    double? confidence,
    bool? shouldCalibrate,
    CalibrationStatus? calibrationStatus,
    HeadingSource? source,
    double? magneticFieldMagnitude,
    double? pitch,
    double? roll,
    DateTime? timestamp,
  }) {
    return CompassReading(
      headingMagnetic: headingMagnetic ?? this.headingMagnetic,
      headingTrue: headingTrue ?? this.headingTrue,
      heading: heading ?? this.heading,
      accuracyDegrees: accuracyDegrees ?? this.accuracyDegrees,
      accuracy: accuracy ?? this.accuracy,
      confidence: confidence ?? this.confidence,
      shouldCalibrate: shouldCalibrate ?? this.shouldCalibrate,
      calibrationStatus: calibrationStatus ?? this.calibrationStatus,
      source: source ?? this.source,
      magneticFieldMagnitude:
          magneticFieldMagnitude ?? this.magneticFieldMagnitude,
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompassReading &&
        other.headingMagnetic == headingMagnetic &&
        other.headingTrue == headingTrue &&
        _sameDouble(other.heading, heading) &&
        other.accuracyDegrees == accuracyDegrees &&
        other.accuracy == accuracy &&
        other.confidence == confidence &&
        other.shouldCalibrate == shouldCalibrate &&
        other.calibrationStatus == calibrationStatus &&
        other.source == source &&
        other.magneticFieldMagnitude == magneticFieldMagnitude &&
        other.pitch == pitch &&
        other.roll == roll &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(
        headingMagnetic,
        headingTrue,
        heading.isNaN ? double.nan.hashCode : heading,
        accuracyDegrees,
        accuracy,
        confidence,
        shouldCalibrate,
        calibrationStatus,
        source,
        magneticFieldMagnitude,
        pitch,
        roll,
        timestamp,
      );

  // Treats NaN == NaN so `unavailable` readings compare equal by value.
  static bool _sameDouble(double a, double b) => a == b || (a.isNaN && b.isNaN);

  @override
  String toString() => 'CompassReading(heading: ${heading.toStringAsFixed(1)}, '
      'accuracy: ${accuracyDegrees.toStringAsFixed(1)}°/$accuracy, '
      'confidence: ${confidence.toStringAsFixed(2)}, source: $source, '
      'shouldCalibrate: $shouldCalibrate)';
}
