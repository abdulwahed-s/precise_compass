/// True ⇄ magnetic heading conversion via magnetic declination.
///
/// Declination (a.k.a. magnetic variation) is the angle between magnetic north
/// and true (geographic) north at a location, **east-positive**. The actual
/// declination value comes from the platform's World Magnetic Model — Android's
/// `GeomagneticField` or iOS's already-true `CLHeading.trueHeading` — not from
/// this package; these helpers only apply a known declination.
library;

import 'package:precise_compass/src/domain/geo/angle_math.dart';

/// Converts a [magneticHeadingDegrees] to a true heading by adding the
/// east-positive [declinationDegrees]. Result is normalized to `[0, 360)`.
double magneticToTrueHeading(
  double magneticHeadingDegrees,
  double declinationDegrees,
) =>
    normalizeDegrees(magneticHeadingDegrees + declinationDegrees);

/// Converts a [trueHeadingDegrees] back to magnetic by subtracting the
/// east-positive [declinationDegrees]. Result is normalized to `[0, 360)`.
double trueToMagneticHeading(
  double trueHeadingDegrees,
  double declinationDegrees,
) =>
    normalizeDegrees(trueHeadingDegrees - declinationDegrees);

/// Infers the effective declination implied by a paired magnetic/true heading
/// (as iOS supplies), returned in `[-180, 180)`.
double declinationFromHeadings({
  required double magneticHeadingDegrees,
  required double trueHeadingDegrees,
}) =>
    shortestAngularDifference(magneticHeadingDegrees, trueHeadingDegrees);
