import 'package:meta/meta.dart';
import 'package:precise_compass/src/api/enums.dart';

/// The raw, decoded payload for a single sample as delivered by the native
/// platform over the event channel.
///
/// This is an internal DTO (not exported). It is the *versioned contract*
/// between the native code and the pure-Dart `domain` pipeline; keep
/// [payloadVersion] in lock-step with the native encoders.
@immutable
class RawCompassData {
  /// Creates a raw sample. All angular values are in degrees.
  const RawCompassData({
    required this.source,
    required this.accuracyDegrees,
    required this.timestamp,
    this.magneticHeading,
    this.trueHeading,
    this.osAccuracyStatus,
    this.magneticFieldMagnitude,
    this.pitch,
    this.roll,
  });

  /// Decodes a platform channel map into a [RawCompassData].
  ///
  /// Tolerates `int`/`double` numeric mixing and missing optional keys. The
  /// `source` key is an integer code; see [headingSourceFromCode].
  factory RawCompassData.fromMap(Map<Object?, Object?> map) {
    double? readDouble(String key) {
      final value = map[key];
      return value is num ? value.toDouble() : null;
    }

    int? readInt(String key) {
      final value = map[key];
      return value is num ? value.toInt() : null;
    }

    final timestampMs = readInt('timestamp');
    return RawCompassData(
      source: headingSourceFromCode(readInt('source')),
      accuracyDegrees: readDouble('accuracyDegrees') ?? -1,
      magneticHeading: readDouble('magneticHeading'),
      trueHeading: readDouble('trueHeading'),
      osAccuracyStatus: readInt('osAccuracyStatus'),
      magneticFieldMagnitude: readDouble('magneticFieldMagnitude'),
      pitch: readDouble('pitch'),
      roll: readDouble('roll'),
      timestamp: timestampMs != null
          ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
          : DateTime.now(),
    );
  }

  /// The schema version of the native payload this DTO understands.
  static const int payloadVersion = 1;

  /// Which native signal path produced this sample.
  final HeadingSource source;

  /// Continuous estimated heading error in degrees, or `-1` if unavailable.
  final double accuracyDegrees;

  /// Magnetic heading in degrees, already remapped for the display/interface
  /// orientation, or `null` if not provided.
  final double? magneticHeading;

  /// True (geographic) heading in degrees, or `null` if unavailable.
  final double? trueHeading;

  /// The Android `SensorManager` accuracy status (`3..0`/`-1`), or `null`
  /// (e.g. on iOS).
  final int? osAccuracyStatus;

  /// Ambient magnetic field magnitude in microtesla, or `null` if not measured.
  final double? magneticFieldMagnitude;

  /// Device pitch in degrees, or `null`.
  final double? pitch;

  /// Device roll in degrees, or `null`.
  final double? roll;

  /// When the native layer produced this sample.
  final DateTime timestamp;

  @override
  String toString() => 'RawCompassData(source: $source, '
      'mag: $magneticHeading, true: $trueHeading, '
      'acc: $accuracyDegrees, status: $osAccuracyStatus, '
      'field: $magneticFieldMagnitude)';
}

/// Maps a native integer source [code] to a [HeadingSource].
///
/// `0 = rotationVector`, `1 = geomagnetic`, `2 = fusion`,
/// `3 = platformHeading`; anything else (including `null`) is
/// [HeadingSource.unavailable].
HeadingSource headingSourceFromCode(int? code) {
  switch (code) {
    case 0:
      return HeadingSource.rotationVector;
    case 1:
      return HeadingSource.geomagnetic;
    case 2:
      return HeadingSource.fusion;
    case 3:
      return HeadingSource.platformHeading;
    default:
      return HeadingSource.unavailable;
  }
}
