# precise_compass

[![pub package](https://img.shields.io/pub/v/precise_compass.svg)](https://pub.dev/packages/precise_compass)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

**An honest, high-accuracy Flutter compass.** Every reading carries a
*continuous* heading-uncertainty estimate in degrees, a `0..1` confidence score,
debounced calibration detection, sensor fusion, and graceful degradation — so
your app never has to lie to its users about how good the heading is.

> **The one-sentence difference:** other compass packages report a coarse,
> sticky 3-level "accuracy" derived from Android's `onAccuracyChanged` status.
> `precise_compass` reports the OS-provided **continuous heading accuracy**
> (`TYPE_ROTATION_VECTOR.values[4]` on Android, `CLHeading.headingAccuracy` on
> iOS), cross-checks it against the **magnetic-field magnitude** to catch
> interference the status misses, and folds everything into one trustworthy
> `confidence` value and a non-flickering `shouldCalibrate` flag.

## Why it exists

Compass headings are only useful if you know when *not* to trust them — qibla
finders, AR overlays, navigation and surveying all break silently when the
magnetometer is uncalibrated or sitting next to a speaker magnet. The popular
packages can't tell you this reliably:

| | `precise_compass` | `flutter_compass` / `_v2` | `compassx` | `flutter_device_compass` |
|---|:---:|:---:|:---:|:---:|
| Continuous accuracy (degrees) | ✅ `values[4]` / `headingAccuracy` | ❌ status→`15/30/45` buckets | ⚠️ undocumented | ❌ none |
| Confidence score (`0..1`) | ✅ | ❌ | ❌ | ❌ |
| Magnetic-interference detection | ✅ field magnitude | ❌ | ❌ | ❌ |
| Debounced `shouldCalibrate` | ✅ hysteresis FSM | ❌ | ⚠️ undocumented | ❌ |
| Sensor-fusion modes | ✅ RV / geomagnetic / manual | ⚠️ RV + fallback | RV | RV |
| Capability introspection | ✅ | ❌ | ❌ | ❌ |
| Full-orientation heading | ✅ | ✅ (v2) | ❌ portrait-only | ⚠️ |
| Pure-Dart, unit-tested core | ✅ ≥90% | ❌ | ❌ | ❌ |

## Quick start

```dart
import 'package:precise_compass/precise_compass.dart';

final subscription = PreciseCompass.heading.listen((reading) {
  if (!reading.hasHeading) return; // no compass on this device

  print('${reading.heading.toStringAsFixed(0)}° '
      '± ${reading.accuracyDegrees.toStringAsFixed(0)}° '
      '· ${(reading.confidence * 100).toStringAsFixed(0)}% confident');

  if (reading.shouldCalibrate) {
    // Prompt a figure-8 motion, or let iOS show its native HUD.
  }
});

// Sensors register lazily on first listen and release on cancel:
await subscription.cancel();
```

## What a reading tells you

```dart
class CompassReading {
  final double? headingMagnetic;        // degrees [0,360) or null
  final double? headingTrue;            // degrees [0,360) or null (needs location)
  final double  heading;                // true if available, else magnetic
  final double  accuracyDegrees;        // continuous ± estimate; -1 = unknown
  final CompassAccuracy accuracy;       // high / medium / low / unreliable / unknown
  final double  confidence;             // 0.0 … 1.0
  final bool    shouldCalibrate;        // debounced recommendation
  final CalibrationStatus calibrationStatus;
  final HeadingSource source;           // rotationVector / geomagnetic / fusion / …
  final double? magneticFieldMagnitude; // µT (Earth ≈ 25–65 µT)
  final double? pitch, roll;            // degrees, for AR
  final DateTime timestamp;
}
```

It **never throws** for a missing sensor: you get `source: unavailable`,
`accuracy: unknown`, `confidence: 0` instead.

## Configuration

```dart
PreciseCompass.headingStream(
  config: const CompassConfig(
    reference: HeadingReference.auto,     // trueNorth / magnetic / auto
    fusionMode: FusionMode.auto,          // rotationVector / geomagnetic / fusion / auto
    rate: SensorRate.ui,                  // fastest / ui / normal / batterySaving
    smoothingFactor: null,                // null = light default; 0 = off; →1 = smoother
    detectCalibration: true,
    suppressIosCalibrationHud: false,     // true = hide native HUD, show your own
    magneticFieldBand: ClampRange(25, 65),
  ),
).listen(...);
```

Probe the hardware before offering features:

```dart
final caps = await PreciseCompass.capabilities();
if (caps.supportsTrueHeading) enableTrueNorthToggle();
print('Recommended mode: ${caps.recommendedMode}');
```

## Platform setup

### Android
No permission is needed for **magnetic** heading. For **true** heading the plugin
reads the device's last known location to compute declination, so the host app
must declare and request a location permission:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

Minimum SDK: **21**.

### iOS
Add a usage string so the system can provide **true** heading (location):

```xml
<!-- ios/Runner/Info.plist -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to show your true (geographic) heading.</string>
```

Minimum iOS: **12**. The compass is unavailable on the iOS Simulator.

## How accuracy & calibration work

- **Continuous accuracy.** Android exposes the OS estimate as
  `TYPE_ROTATION_VECTOR.values[4]` (radians); iOS as `CLHeading.headingAccuracy`
  (degrees). We convert to a single `accuracyDegrees` (`-1` when the OS provides
  no estimate) and bucket it into `CompassAccuracy` (`≤10° high`, `≤20° medium`,
  `≤45° low`, else `unreliable`).
- **Interference detection.** Earth's field is ≈25–65 µT. A magnitude well
  outside the configured band — even when the OS still claims "high" — drives the
  field score and `shouldCalibrate` down. This catches the most common
  real-world failure that status-based compasses miss.
- **Confidence.** A documented, monotonic blend of accuracy and short-term
  heading stability, *gated* by source quality and field health, in `[0,1]`. The
  exact formula is in [`ARCHITECTURE.md`](ARCHITECTURE.md).
- **Debounced calibration.** A hysteresis state machine asserts `shouldCalibrate`
  only after ~1.5 s of sustained poor quality and clears it only after ~1 s of
  sustained good quality — no flicker, and no cold-start false positive.

See **[ARCHITECTURE.md](ARCHITECTURE.md)** for the data-flow diagram, the
confidence formula, the fusion math and the calibration FSM.

## Migrating

Coming from `flutter_compass`, `flutter_compass_v2` or `compassx`? See
**[MIGRATION.md](MIGRATION.md)** for API mapping tables.

## Example

The [`example/`](example) app is a live test harness: a rotating dial, numeric
heading, accuracy/confidence meters, a figure-8 calibration banner, a capability
readout, and toggles for reference/rate/fusion mode.

## Attribution & license

`precise_compass` is **MIT**-licensed. It originated as a fork of
[`flutter_compass_v2`](https://pub.dev/packages/flutter_compass_v2) (itself a
fork of [`flutter_compass`](https://pub.dev/packages/flutter_compass) by
Hemanth Raj V), both MIT. The native Android orientation/​math code was
rewritten from scratch to keep the entire package MIT-clean. See
[`LICENSE`](LICENSE).
