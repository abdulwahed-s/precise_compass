/// Wraparound-safe angular math, in degrees, for compass headings.
///
/// All functions are pure and side-effect free. Headings are measured clockwise
/// from north; "normalized" means the half-open range `[0, 360)`.
library;

import 'dart:math' as math;

/// Converts [degrees] to radians.
double degreesToRadians(double degrees) => degrees * math.pi / 180.0;

/// Converts [radians] to degrees.
double radiansToDegrees(double radians) => radians * 180.0 / math.pi;

/// Normalizes [degrees] into the half-open range `[0, 360)`.
///
/// Handles arbitrarily large or negative inputs (e.g. `-90 -> 270`,
/// `450 -> 90`). Returns [double.nan] if [degrees] is not finite.
double normalizeDegrees(double degrees) {
  if (!degrees.isFinite) return double.nan;
  final result = degrees % 360.0;
  return result < 0 ? result + 360.0 : result;
}

/// Normalizes [degrees] into the half-open range `[-180, 180)`.
double normalizeDegreesSigned(double degrees) {
  final n = normalizeDegrees(degrees);
  return n >= 180.0 ? n - 360.0 : n;
}

/// The signed shortest angular difference `to - from`, in `[-180, 180)`.
///
/// Positive is clockwise. For example `shortestAngularDifference(350, 10)`
/// returns `20` (not `-340`).
double shortestAngularDifference(double from, double to) =>
    normalizeDegreesSigned(to - from);

/// The absolute shortest angular distance between [a] and [b], in `[0, 180]`.
double angularDistance(double a, double b) =>
    shortestAngularDifference(a, b).abs();

/// The circular mean of [anglesDegrees] (degrees), computed via unit-vector
/// summation so the `0/360` wraparound is handled correctly.
///
/// Returns [double.nan] for an empty input or when the vectors cancel out (an
/// undefined mean, e.g. exact opposites).
double meanAngleDegrees(Iterable<double> anglesDegrees) {
  var sumSin = 0.0;
  var sumCos = 0.0;
  var count = 0;
  for (final a in anglesDegrees) {
    final r = degreesToRadians(a);
    sumSin += math.sin(r);
    sumCos += math.cos(r);
    count++;
  }
  if (count == 0) return double.nan;
  // Near-zero resultant => the directions cancel and the mean is undefined.
  final magnitude = math.sqrt(sumSin * sumSin + sumCos * sumCos);
  if (magnitude < 1e-9) return double.nan;
  return normalizeDegrees(radiansToDegrees(math.atan2(sumSin, sumCos)));
}

/// Interpolates along the shortest arc from [a] to [b] by fraction [t].
///
/// [t] is clamped to `[0, 1]`; `t == 0` returns [a] normalized, `t == 1`
/// returns [b] normalized. The result never crosses the long way around the
/// circle.
double lerpAngleDegrees(double a, double b, double t) {
  final clampedT = t.clamp(0.0, 1.0);
  final delta = shortestAngularDifference(a, b);
  return normalizeDegrees(a + delta * clampedT);
}

/// The circular standard deviation (degrees) of [anglesDegrees].
///
/// Uses the resultant-vector-length definition: `sqrt(-2 * ln(R))` in radians,
/// converted to degrees. `0` means perfectly concentrated; larger means more
/// spread. Returns [double.nan] for fewer than two samples.
double circularStdDevDegrees(Iterable<double> anglesDegrees) {
  var sumSin = 0.0;
  var sumCos = 0.0;
  var count = 0;
  for (final a in anglesDegrees) {
    final r = degreesToRadians(a);
    sumSin += math.sin(r);
    sumCos += math.cos(r);
    count++;
  }
  if (count < 2) return double.nan;
  final resultantLength = math.sqrt(sumSin * sumSin + sumCos * sumCos) / count;
  if (resultantLength <= 1e-12) return double.infinity;
  if (resultantLength >= 1) return 0;
  return radiansToDegrees(math.sqrt(-2.0 * math.log(resultantLength)));
}
