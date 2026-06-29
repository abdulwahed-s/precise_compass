/// `precise_compass` — an honest, high-accuracy Flutter compass.
///
/// Unlike compasses that surface only a coarse, sticky OS accuracy status, this
/// package reports a *continuous* heading-uncertainty estimate (in degrees), a
/// `0..1` confidence score, debounced calibration detection, sensor fusion, and
/// graceful degradation when the hardware can't deliver.
///
/// Quick start:
/// ```dart
/// import 'package:precise_compass/precise_compass.dart';
///
/// final sub = PreciseCompass.heading.listen((reading) {
///   print('${reading.heading.toStringAsFixed(0)}° '
///       '±${reading.accuracyDegrees.toStringAsFixed(0)}° '
///       '(${(reading.confidence * 100).toStringAsFixed(0)}%)');
/// });
/// // Sensors register on listen and unregister when you cancel:
/// await sub.cancel();
/// ```
library;

export 'src/api/compass_capabilities.dart';
export 'src/api/compass_config.dart';
export 'src/api/compass_reading.dart';
export 'src/api/enums.dart';
export 'src/api/precise_compass.dart' show PreciseCompass;
