import 'dart:math' as math;

import 'package:precise_compass/precise_compass.dart';
import 'package:precise_compass/src/models/raw_compass_data.dart';

// Synthetic but representative sensor sequences used for regression testing the
// pure-Dart pipeline. Each scenario mirrors a real-world situation the package
// is designed to handle correctly.

DateTime _t(int ms) => DateTime(2026).add(Duration(milliseconds: ms));

/// A healthy rotation-vector stream: steady ~48µT field, small heading sway,
/// good continuous accuracy. Should read as high quality, no calibration.
List<RawCompassData> cleanRotationVectorSequence() => <RawCompassData>[
      for (var ms = 0; ms <= 3000; ms += 50)
        RawCompassData(
          source: HeadingSource.rotationVector,
          accuracyDegrees: 5,
          magneticHeading: 90 + 2 * math.sin(ms / 400),
          osAccuracyStatus: 3,
          magneticFieldMagnitude: 48,
          timestamp: _t(ms),
        ),
    ];

/// The keystone scenario: the OS reports an optimistic `values[4]` (8°), but
/// the field magnitude (~150µT) reveals hard-iron interference. A naive
/// compass would trust the status and lie; `precise_compass` must catch it.
List<RawCompassData> magneticInterferenceSequence() => <RawCompassData>[
      for (var ms = 0; ms <= 3000; ms += 50)
        RawCompassData(
          source: HeadingSource.rotationVector,
          accuracyDegrees: 8, // optimistic / "sticky high"
          magneticHeading: 90 + 8 * math.sin(ms / 120),
          osAccuracyStatus: 3, // OS says HIGH
          magneticFieldMagnitude: 150, // but the field is implausible
          timestamp: _t(ms),
        ),
    ];

/// A cold start that is briefly unreliable (~1s) before settling. Must NOT emit
/// a startup false-positive calibration recommendation.
List<RawCompassData> uncalibratedStartupSequence() => <RawCompassData>[
      for (var ms = 0; ms < 1000; ms += 50)
        RawCompassData(
          source: HeadingSource.rotationVector,
          accuracyDegrees: -1, // no continuous estimate yet
          magneticHeading: 90,
          osAccuracyStatus: 0, // UNRELIABLE at boot
          magneticFieldMagnitude: 48,
          timestamp: _t(ms),
        ),
      for (var ms = 1000; ms <= 3000; ms += 50)
        RawCompassData(
          source: HeadingSource.rotationVector,
          accuracyDegrees: 6,
          magneticHeading: 90,
          osAccuracyStatus: 3,
          magneticFieldMagnitude: 48,
          timestamp: _t(ms),
        ),
    ];

/// A low-power / no-gyro device: geomagnetic source, no `values[4]`, so accuracy
/// comes from the OS status fallback. Should still produce a usable heading.
List<RawCompassData> noGyroDeviceSequence() => <RawCompassData>[
      for (var ms = 0; ms <= 3000; ms += 50)
        RawCompassData(
          source: HeadingSource.geomagnetic,
          accuracyDegrees: -1,
          magneticHeading: 90 + 3 * math.sin(ms / 300),
          osAccuracyStatus: 3, // -> 15° fallback
          magneticFieldMagnitude: 46,
          timestamp: _t(ms),
        ),
    ];
