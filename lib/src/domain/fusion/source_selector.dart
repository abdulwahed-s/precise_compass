import 'package:precise_compass/src/api/compass_capabilities.dart';
import 'package:precise_compass/src/api/enums.dart';

/// Recommends the best concrete [FusionMode] for a device, given its
/// [CompassCapabilities].
///
/// Priority (highest fidelity first):
/// 1. [FusionMode.rotationVector] — OS gyro+accel+mag fusion.
/// 2. [FusionMode.geomagnetic] — low-power accel+mag fusion.
/// 3. [FusionMode.fusion] — the package's own gyro+mag complementary filter.
///
/// Returns [FusionMode.auto] only when the device has no usable combination,
/// which callers should treat as "heading unavailable".
FusionMode recommendFusionMode(CompassCapabilities caps) {
  if (caps.hasRotationVector) return FusionMode.rotationVector;
  if (caps.hasGeomagneticRotationVector) return FusionMode.geomagnetic;
  if (caps.hasMagnetometer && caps.hasAccelerometer) {
    return caps.hasGyroscope ? FusionMode.fusion : FusionMode.geomagnetic;
  }
  return FusionMode.auto;
}

/// Resolves a *requested* [FusionMode] to the best mode the device actually
/// supports.
///
/// [FusionMode.auto] delegates to [recommendFusionMode]. A specific request is
/// honored when supported; otherwise it degrades gracefully to the
/// recommendation rather than failing.
FusionMode resolveFusionMode(
  FusionMode requested,
  CompassCapabilities caps,
) {
  switch (requested) {
    case FusionMode.auto:
      return recommendFusionMode(caps);
    case FusionMode.rotationVector:
      return caps.hasRotationVector
          ? FusionMode.rotationVector
          : recommendFusionMode(caps);
    case FusionMode.geomagnetic:
      final canGeomagnetic = caps.hasGeomagneticRotationVector ||
          (caps.hasMagnetometer && caps.hasAccelerometer);
      return canGeomagnetic
          ? FusionMode.geomagnetic
          : recommendFusionMode(caps);
    case FusionMode.fusion:
      final canFuse =
          caps.hasGyroscope && caps.hasMagnetometer && caps.hasAccelerometer;
      return canFuse ? FusionMode.fusion : recommendFusionMode(caps);
  }
}
