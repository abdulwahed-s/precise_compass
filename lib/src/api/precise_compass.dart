import 'dart:async';

import 'package:precise_compass/src/api/compass_capabilities.dart';
import 'package:precise_compass/src/api/compass_config.dart';
import 'package:precise_compass/src/api/compass_reading.dart';
import 'package:precise_compass/src/domain/compass_pipeline.dart';
import 'package:precise_compass/src/platform/compass_platform.dart';

/// The stateless entry point to `precise_compass`.
///
/// All members are static. Sensors register lazily when a heading stream gains
/// its first listener and release when the last listener cancels.
///
/// ```dart
/// final sub = PreciseCompass.heading.listen((r) {
///   if (r.shouldCalibrate) showFigureEightPrompt();
///   print('${r.heading.toStringAsFixed(0)}° ± ${r.accuracyDegrees}°');
/// });
/// // ...later
/// await sub.cancel();
/// ```
abstract final class PreciseCompass {
  static Stream<CompassReading>? _defaultStream;

  /// The default heading stream, using [CompassConfig]'s defaults.
  ///
  /// Cached and multi-subscription, so it can be listened to from several
  /// places; each listener gets its own processing pipeline.
  static Stream<CompassReading> get heading =>
      _defaultStream ??= headingStream();

  /// A configurable heading stream.
  ///
  /// Each call returns an independent, multi-subscription stream whose native
  /// sensors register on first listen and release on last cancel. Per listener
  /// the smoothing/calibration state is isolated.
  static Stream<CompassReading> headingStream({
    CompassConfig config = const CompassConfig(),
  }) {
    final rawStream = CompassPlatform.instance.rawHeadingStream(config);
    return Stream<CompassReading>.multi((controller) {
      final pipeline = CompassPipeline(config: config);
      final subscription = rawStream.listen(
        (raw) => controller.add(pipeline.process(raw)),
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () async {
        await subscription.cancel();
        pipeline.reset();
      };
    });
  }

  /// Probes this device's heading-related capabilities (sensors present, true
  /// heading support, recommended fusion mode).
  static Future<CompassCapabilities> capabilities() =>
      CompassPlatform.instance.capabilities();

  /// Resets cached state. Intended for tests that swap
  /// `CompassPlatform.instance`.
  static void debugReset() => _defaultStream = null;
}
