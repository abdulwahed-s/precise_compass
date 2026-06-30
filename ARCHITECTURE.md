# Architecture

`precise_compass` keeps **all logic in pure Dart** and uses **thin native edges**
that only acquire raw sensor data. This makes the hard parts (fusion, filtering,
accuracy mapping, calibration heuristics) testable without a device.

## Layering

```
lib/
  precise_compass.dart            # public exports only
  src/
    api/                          # PreciseCompass facade + immutable public models
      precise_compass.dart        #   the static facade
      compass_reading.dart        #   CompassReading
      compass_config.dart         #   CompassConfig, ClampRange
      compass_capabilities.dart   #   CompassCapabilities
      enums.dart                  #   CompassAccuracy, HeadingSource, …
    domain/                       # PURE DART — no Flutter, no channels
      accuracy/                   #   values[4]→deg, field plausibility, confidence
      filtering/                  #   angular-wraparound-safe low-pass
      calibration/                #   hysteresis state machine
      fusion/                     #   complementary filter, source selection
      geo/                        #   angle math, declination
      compass_pipeline.dart       #   orchestrates raw DTO → CompassReading
    models/                       # raw DTOs decoded from the platform payload
    platform/                     # EventChannel / MethodChannel adapter
```

Dependencies point inward: `models` and `api` models are the shared kernel,
`domain` depends on them, the `platform` adapter decodes into `models`, and the
`api` facade wires `platform → domain → public stream`. The `domain` layer
imports neither Flutter nor `dart:ui`.

## Data flow

```
native sensors
  → platform channel (versioned map payload)
  → RawCompassData (models)
  → CompassPipeline (domain):
        resolve accuracy  → smoothing (angular LPF, magnetic + true)
        field evaluator   → confidence  → calibration FSM
  → CompassReading (immutable, public)
  → Stream<CompassReading>
```

One `CompassPipeline` instance backs one stream subscription; it owns all
per-stream state (two angular filters, the magnetic-field window, the heading
stability window, the calibration machine) and is deterministic given its
inputs.

## The versioned native payload

Both platforms emit the same map (`RawCompassData.fromMap`), `payloadVersion 1`:

| key | type | meaning |
|---|---|---|
| `source` | int | `0` rotationVector · `1` geomagnetic · `2` fusion · `3` platformHeading · `-1` unavailable |
| `magneticHeading` | double? | degrees, already remapped for display/interface orientation |
| `trueHeading` | double? | degrees, present when declination/location is available |
| `accuracyDegrees` | double | continuous ± estimate; `-1` = unknown |
| `osAccuracyStatus` | int? | Android `SensorManager` status `3..0/-1`; null on iOS |
| `magneticFieldMagnitude` | double? | µT |
| `pitch`, `roll` | double? | degrees |
| `timestamp` | int | epoch milliseconds |

## Accuracy mapping

- **Android:** `accuracyDegrees = toDegrees(values[4])` when `values[4] ≥ 0`,
  else `-1`. `values[4]` is the OS-estimated heading accuracy in radians.
- **iOS:** `accuracyDegrees = headingAccuracy` (already degrees); `< 0` ⇒ `-1`.
- **Fallback:** when the continuous estimate is unavailable, the Android status
  maps coarsely (`HIGH→15°`, `MEDIUM→30°`, `LOW→45°`, `UNRELIABLE→120°`). This
  is intentionally a *last resort* — the status is optimistic and sticky.
- **Buckets:** `≤10° high`, `≤20° medium`, `≤45° low`, else `unreliable`;
  `unknown` when there is no estimate.

## Magnetic-field health

Over a rolling window the evaluator computes mean magnitude and standard
deviation, then:

```
plausibilityScore = mean ∈ band ? 1
                                : clamp(1 − distanceOutsideBand / 40µT, 0, 1)
stabilityScore    = clamp(1 − stdDev / 20µT, 0, 1)
fieldScore        = plausibilityScore × stabilityScore
```

## Confidence formula

```
accuracyScore  = accuracyDegrees < 0 ? 0.4 : clamp(1 − accuracyDegrees/60, 0, 1)
stabilityScore = stability == null  ? 0.7 : clamp(1 − stabilityDeg/30, 0, 1)
base           = 0.75·accuracyScore + 0.25·stabilityScore
fieldGate      = fieldScore == null ? 1 : 0.4 + 0.6·fieldScore
confidence     = clamp(base · sourceQuality · fieldGate, 0, 1)
```

`sourceQuality` is `rotationVector 1.0`, `platformHeading 0.95`,
`geomagnetic 0.85`, `fusion 0.8`, `unavailable 0`. The model is **monotonic**:
improving any input never lowers the score. Field health and source quality are
*gates* (not averaged) so detected interference collapses confidence even when
the OS-reported accuracy is optimistic — the core multi-signal advantage.

## Calibration FSM

A per-sample boolean "is the heading good?" verdict (derived from accuracy +
field plausibility) drives a hysteresis machine:

- starts `unknown`;
- becomes `calibrating` only after the verdict is *bad* for a sustained
  `assertAfter` (default **1.5 s**);
- returns to `calibrated` only after the verdict is *good* for a sustained
  `clearAfter` (default **1.0 s**);
- a flip resets the streak but does **not** change the state until the new
  streak matures — so transients don't flicker and the brief cold-start
  "unreliable" blip never triggers a false alarm.

Time is supplied via each sample's timestamp, keeping the machine pure and
deterministic in tests.

## Angular-safe smoothing

Headings are never low-passed as raw degrees (that breaks at the 0/360 seam).
The filter smooths the heading's unit vector `(cosθ, sinθ)` and recovers the
angle with `atan2`. Magnetic and true headings get independent filters so they
stay mutually consistent (they differ only by a near-constant declination).

## Complementary fusion (advanced)

When the OS rotation vector is unavailable/poor, `ComplementaryHeadingFilter`
predicts with integrated gyro rotation about the vertical axis, then nudges a
small fraction (`magnetometerGain`, default `0.05`) toward the tilt-compensated
magnetometer heading — and skips that correction while interference is detected,
so magnetic noise can't corrupt the estimate.

## Platform specifics

- **Android.** `TYPE_ROTATION_VECTOR` →
  `getRotationMatrixFromVector` → `remapCoordinateSystem` (per `Display.rotation`)
  → `getOrientation`. Also registers `TYPE_MAGNETIC_FIELD` for magnitude +
  `onAccuracyChanged` status. `TYPE_GEOMAGNETIC_ROTATION_VECTOR` powers the
  low-power mode; an accel+mag path is the final fallback. True heading uses
  `GeomagneticField` from the last known location (best-effort, no permission
  request of its own).
- **iOS.** `CLLocationManager` heading provides `magneticHeading`, `trueHeading`,
  `headingAccuracy`, and raw `x/y/z` (→ field magnitude).
  `locationManagerShouldDisplayHeadingCalibration` is wired to
  `CompassConfig.suppressIosCalibrationHud`. CoreMotion device-motion supplies
  pitch/roll.

## Federation decision

Shipped as a **single plugin package** with the clean internal split above —
not a fully federated multi-package plugin. Rationale: solo maintainability, a
smaller release surface, faster iteration; the pure-Dart domain core already
provides the important modularity and testability. The `CompassPlatform`
abstraction (`lib/src/platform/`) is the seam that makes a later split into
`precise_compass` + `precise_compass_platform_interface` +
`precise_compass_{android,ios,web}` mechanical if third parties ever want
alternative backends.
