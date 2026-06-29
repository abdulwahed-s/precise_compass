import 'dart:math' as math;

import 'package:precise_compass/src/domain/geo/angle_math.dart';

/// An exponential low-pass filter for angles (degrees) that is safe across the
/// `0/360` wraparound.
///
/// Naively low-passing raw degrees produces a gross error near the boundary
/// (e.g. smoothing `359` and `1` toward `180`). This filter instead smooths the
/// heading's unit vector `(cos θ, sin θ)`, which has no discontinuity, then
/// recovers the angle with `atan2`.
///
/// The filter is stateful: feed it successive samples with [filter].
class AngularLowPassFilter {
  /// Creates a filter with the given [smoothingFactor] in `[0, 1]`.
  ///
  /// `0` disables smoothing (output equals input). Values closer to `1` are
  /// smoother but lag more; `1` freezes on the first sample. The factor maps to
  /// a per-sample new-value weight of `1 - smoothingFactor`.
  AngularLowPassFilter(this.smoothingFactor)
      : assert(
          smoothingFactor >= 0 && smoothingFactor <= 1,
          'smoothingFactor must be in [0, 1]',
        );

  /// The smoothing factor in `[0, 1]`; see the constructor.
  final double smoothingFactor;

  double _sin = 0;
  double _cos = 0;
  bool _hasValue = false;

  /// Whether at least one sample has been accepted since construction/[reset].
  bool get hasValue => _hasValue;

  /// The current filtered heading in degrees `[0, 360)`, or `null` if no sample
  /// has been accepted yet.
  double? get value => _hasValue
      ? normalizeDegrees(radiansToDegrees(math.atan2(_sin, _cos)))
      : null;

  /// Feeds [degrees] into the filter and returns the new filtered heading in
  /// `[0, 360)`.
  ///
  /// Non-finite input is ignored: the previous [value] is returned (or
  /// [double.nan] if there is none yet).
  double filter(double degrees) {
    if (!degrees.isFinite) return value ?? double.nan;
    final radians = degreesToRadians(degrees);
    final sampleSin = math.sin(radians);
    final sampleCos = math.cos(radians);

    if (!_hasValue) {
      _sin = sampleSin;
      _cos = sampleCos;
      _hasValue = true;
    } else {
      final newWeight = 1.0 - smoothingFactor;
      _sin += newWeight * (sampleSin - _sin);
      _cos += newWeight * (sampleCos - _cos);
    }
    return value!;
  }

  /// Clears all state; the next [filter] call re-initializes from its input.
  void reset() {
    _sin = 0;
    _cos = 0;
    _hasValue = false;
  }
}
