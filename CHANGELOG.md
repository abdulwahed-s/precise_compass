# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

Initial release of `precise_compass`, a ground-up rework of the
`flutter_compass_v2` fork focused on *honest, continuous* heading accuracy.

### Added
- `PreciseCompass` facade: `heading`, `headingStream({config})`,
  `capabilities()`.
- `CompassReading` with **continuous** `accuracyDegrees`, a normalized
  `CompassAccuracy` bucket, a `0..1` `confidence` score, debounced
  `shouldCalibrate`, `calibrationStatus`, `source`, `magneticFieldMagnitude`,
  and optional `pitch`/`roll`.
- Keystone accuracy from Android `TYPE_ROTATION_VECTOR.values[4]` and iOS
  `CLHeading.headingAccuracy`, with a documented OS-status fallback.
- Magnetic-interference detection from field magnitude (configurable plausible
  band, default 25–65 µT).
- Confidence model gated by source quality and field health (see
  `ARCHITECTURE.md`).
- Calibration hysteresis state machine (no flicker, no cold-start false
  positive).
- Angular-wraparound-safe low-pass smoothing.
- Sensor-fusion modes: `rotationVector`, `geomagnetic`, manual complementary
  `fusion`, and `auto` selection from device capabilities.
- `CompassCapabilities` probe (sensors present, true-heading support,
  recommended mode).
- Configurable `SensorRate`, `HeadingReference`, smoothing, and iOS calibration
  HUD suppression.
- Full-orientation heading on Android (display-rotation remap) and iOS
  (interface-orientation adjustment).
- Native Android plugin rewritten clean-room (MIT); structured, versioned event
  payload.
- iOS plugin with `locationManagerShouldDisplayHeadingCalibration` HUD control
  and CoreMotion pitch/roll.
- Pure-Dart domain core with ≥90% line coverage; mocked platform-channel tests;
  fixture-based regression tests; example app.

### Changed
- Package renamed from `flutter_compass_v2` to `precise_compass`; Android plugin
  relocated to `com.precisecompass.precise_compass`.

### Removed
- GPL-licensed Android helper sources inherited by the fork were deleted and
  reimplemented from scratch to keep the package MIT-clean.
