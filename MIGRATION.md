# Migration guide

`precise_compass` keeps the happy path a one-liner, so most migrations are
small. The biggest conceptual change: the stream **never emits null and never
throws for a missing sensor** — you get an explicit `unavailable` reading
instead, and accuracy is a *continuous* value rather than a coarse bucket.

## From `flutter_compass` / `flutter_compass_v2`

```dart
// Before
FlutterCompass.events?.listen((CompassEvent? e) {
  final heading = e?.heading;          // double?
  final accuracy = e?.accuracy;        // coarse: ~15/30/45 or null
});

// After
PreciseCompass.heading.listen((CompassReading r) {
  if (!r.hasHeading) return;           // device has no compass
  final heading = r.heading;           // double (NaN only when unavailable)
  final accuracy = r.accuracyDegrees;  // continuous ± degrees, -1 = unknown
});
```

| `flutter_compass` | `precise_compass` |
|---|---|
| `FlutterCompass.events` (`Stream<CompassEvent>?`) | `PreciseCompass.heading` (`Stream<CompassReading>`) |
| `event.heading` (`double?`) | `reading.heading` + `reading.hasHeading` |
| `event.accuracy` (coarse degrees / null) | `reading.accuracyDegrees` (continuous) and `reading.accuracy` (bucket) |
| `event.headingForCameraMode` | not ported — use `reading.pitch` / `reading.roll` |
| _no calibration signal_ | `reading.shouldCalibrate`, `reading.calibrationStatus` |
| _no confidence_ | `reading.confidence` (`0..1`) |

The Android plugin namespace changed to `com.precisecompass.precise_compass`;
no app code change is required for that.

## From `compassx`

```dart
// Before
CompassX.events.listen((event) {
  event.heading;
  event.accuracy;        // computation undocumented
  event.shouldCalibrate; // undocumented
});

// After
PreciseCompass.heading.listen((r) {
  r.heading;
  r.accuracyDegrees;     // documented: values[4] / headingAccuracy
  r.shouldCalibrate;     // debounced, multi-signal
});
```

| `compassx` | `precise_compass` |
|---|---|
| `CompassX.events` | `PreciseCompass.heading` |
| `event.heading` | `reading.heading` |
| `event.accuracy` | `reading.accuracyDegrees` (+ `reading.accuracy` bucket) |
| `event.shouldCalibrate` | `reading.shouldCalibrate` (debounced) |
| portrait only | all device orientations |
| location required for heading (Android) | magnetic heading works without location; location only adds **true** heading |

## Behavioral differences to expect

- **No nulls / no throws** for missing sensors — branch on `reading.hasHeading`.
- **`shouldCalibrate` is debounced** (≈1.5 s assert / ≈1 s clear), so it won't
  flicker and won't fire a false alarm at cold start.
- **Continuous accuracy** means `accuracyDegrees` changes smoothly; use the
  `CompassAccuracy` bucket if you only want a 3-level indicator.
