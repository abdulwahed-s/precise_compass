/// Maps raw, platform-specific accuracy signals to a single continuous
/// "estimated heading error in degrees" value (lower is better; `-1` means no
/// estimate is available).
///
/// This is the keystone of `precise_compass`: rather than surfacing a coarse,
/// sticky OS status, it converts the OS-provided *continuous* estimates
/// (`TYPE_ROTATION_VECTOR.values[4]` on Android, `CLHeading.headingAccuracy` on
/// iOS) into honest degrees, with a documented fallback when they are absent.
library;

import 'package:precise_compass/src/domain/geo/angle_math.dart';

/// Sentinel returned when no usable accuracy estimate exists.
const double kUnknownAccuracyDegrees = -1;

/// Converts Android `TYPE_ROTATION_VECTOR.values[4]` (estimated heading
/// accuracy in **radians**) to degrees.
///
/// Android reports `-1` (in fact, any negative value) when no estimate is
/// available; in that case this returns [kUnknownAccuracyDegrees]. The
/// result is clamped to a sane `[0, 180]` upper bound.
double androidAccuracyDegreesFromRadians(double values4Radians) {
  if (values4Radians.isNaN || values4Radians < 0) {
    return kUnknownAccuracyDegrees;
  }
  return radiansToDegrees(values4Radians).clamp(0.0, 180.0);
}

/// Normalizes iOS `CLHeading.headingAccuracy` (already in **degrees**).
///
/// A negative value means the reading is invalid/unavailable, mapped to
/// [kUnknownAccuracyDegrees]. The result is clamped to `[0, 180]`.
double iosAccuracyDegrees(double headingAccuracy) {
  if (headingAccuracy.isNaN || headingAccuracy < 0) {
    return kUnknownAccuracyDegrees;
  }
  return headingAccuracy.clamp(0.0, 180.0);
}

/// A coarse fallback estimate (degrees) derived from the Android
/// `SensorManager` accuracy *status*, used only when the continuous
/// `values[4]` estimate is unavailable.
///
/// The status values follow `SensorManager`:
/// `3 = HIGH`, `2 = MEDIUM`, `1 = LOW`, `0 = UNRELIABLE`, `-1 = NO_CONTACT`.
/// This signal is optimistic and sticky, so it is intentionally treated as a
/// last resort (see the project README/ARCHITECTURE).
double fallbackDegreesFromOsStatus(int osStatus) {
  switch (osStatus) {
    case 3:
      return 15;
    case 2:
      return 30;
    case 1:
      return 45;
    case 0:
      return 120; // unreliable: large error so it buckets as `unreliable`
    default:
      return kUnknownAccuracyDegrees;
  }
}

/// Resolves the best available continuous accuracy (degrees) given a primary
/// continuous estimate and a coarse OS status fallback.
///
/// [continuousDegrees] should already be in degrees (e.g. the output of
/// [androidAccuracyDegreesFromRadians] or [iosAccuracyDegrees]). When it is
/// unavailable ([kUnknownAccuracyDegrees]) and [osStatus] is provided, the
/// status fallback is used.
double resolveAccuracyDegrees({
  required double continuousDegrees,
  int? osStatus,
}) {
  if (continuousDegrees >= 0) return continuousDegrees;
  if (osStatus != null) return fallbackDegreesFromOsStatus(osStatus);
  return kUnknownAccuracyDegrees;
}
