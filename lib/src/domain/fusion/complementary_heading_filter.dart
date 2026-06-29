import 'package:precise_compass/src/domain/geo/angle_math.dart';

/// A complementary filter that fuses gyroscope dead-reckoning (fast, smooth,
/// but drifts) with tilt-compensated magnetometer headings (absolute, but
/// noisy and interference-prone) into one stable heading.
///
/// Used for `FusionMode.fusion` when the OS rotation vector is unavailable or
/// poor. Each step *predicts* with the integrated gyro rotation about the
/// vertical axis, then nudges a small fraction ([magnetometerGain]) of the way
/// toward the magnetometer heading — but only while the magnetometer is
/// considered reliable, so interference doesn't corrupt the estimate.
class ComplementaryHeadingFilter {
  /// Creates a filter with the given [magnetometerGain] in `(0, 1]`.
  ///
  /// Small gains (the default `0.05`) trust the gyro more and reject magnetic
  /// noise; larger gains track the magnetometer faster but are jumpier.
  ComplementaryHeadingFilter({this.magnetometerGain = 0.05})
      : assert(
          magnetometerGain > 0 && magnetometerGain <= 1,
          'magnetometerGain must be in (0, 1]',
        );

  /// The fraction of the magnetometer correction applied each step.
  final double magnetometerGain;

  double? _heading;

  /// Whether the filter has been seeded with a first heading.
  bool get hasValue => _heading != null;

  /// The current fused heading in degrees `[0, 360)`, or `null` if unseeded.
  double? get heading => _heading;

  /// Advances the filter by one sample and returns the fused heading.
  ///
  /// - [magnetometerHeadingDegrees]: the absolute tilt-compensated heading.
  /// - [gyroDeltaDegrees]: integrated rotation about the vertical axis since
  ///   the previous sample (clockwise positive).
  /// - [magnetometerReliable]: when `false` (e.g. detected interference), the
  ///   magnetometer correction is skipped and the step is pure gyro.
  ///
  /// The first call seeds the estimate directly from the magnetometer.
  double update({
    required double magnetometerHeadingDegrees,
    required double gyroDeltaDegrees,
    bool magnetometerReliable = true,
  }) {
    if (_heading == null) {
      return _heading = normalizeDegrees(magnetometerHeadingDegrees);
    }

    var next = normalizeDegrees(_heading! + gyroDeltaDegrees);
    if (magnetometerReliable && magnetometerHeadingDegrees.isFinite) {
      final error = shortestAngularDifference(
        next,
        normalizeDegrees(magnetometerHeadingDegrees),
      );
      next = normalizeDegrees(next + magnetometerGain * error);
    }
    return _heading = next;
  }

  /// Clears the estimate; the next [update] re-seeds from the magnetometer.
  void reset() => _heading = null;
}
