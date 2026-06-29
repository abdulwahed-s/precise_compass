import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/precise_compass.dart';

void main() {
  group('CompassAccuracy.fromDegrees', () {
    test('maps continuous degrees to buckets at documented thresholds', () {
      expect(CompassAccuracy.fromDegrees(0), CompassAccuracy.high);
      expect(CompassAccuracy.fromDegrees(10), CompassAccuracy.high);
      expect(CompassAccuracy.fromDegrees(10.001), CompassAccuracy.medium);
      expect(CompassAccuracy.fromDegrees(20), CompassAccuracy.medium);
      expect(CompassAccuracy.fromDegrees(20.001), CompassAccuracy.low);
      expect(CompassAccuracy.fromDegrees(45), CompassAccuracy.low);
      expect(CompassAccuracy.fromDegrees(45.001), CompassAccuracy.unreliable);
      expect(CompassAccuracy.fromDegrees(180), CompassAccuracy.unreliable);
    });

    test('treats null / negative / NaN as unknown', () {
      expect(CompassAccuracy.fromDegrees(null), CompassAccuracy.unknown);
      expect(CompassAccuracy.fromDegrees(-1), CompassAccuracy.unknown);
      expect(CompassAccuracy.fromDegrees(double.nan), CompassAccuracy.unknown);
    });
  });

  group('CompassReading.unavailable', () {
    test('is an honest, non-throwing placeholder', () {
      final r = CompassReading.unavailable();
      expect(r.source, HeadingSource.unavailable);
      expect(r.accuracy, CompassAccuracy.unknown);
      expect(r.confidence, 0);
      expect(r.shouldCalibrate, isFalse);
      expect(r.hasHeading, isFalse);
      expect(r.heading.isNaN, isTrue);
    });

    test('two unavailable readings with same timestamp are value-equal', () {
      final ts = DateTime(2026);
      expect(
        CompassReading.unavailable(timestamp: ts),
        CompassReading.unavailable(timestamp: ts),
      );
    });
  });

  group('CompassReading.copyWith', () {
    test('replaces only the given fields', () {
      final base = CompassReading.unavailable(timestamp: DateTime(2026));
      final updated = base.copyWith(confidence: 0.5, heading: 90);
      expect(updated.confidence, 0.5);
      expect(updated.heading, 90);
      expect(updated.timestamp, base.timestamp);
    });
  });

  group('CompassConfig', () {
    test('defaults match the documented recommendations', () {
      const config = CompassConfig();
      expect(config.reference, HeadingReference.auto);
      expect(config.fusionMode, FusionMode.auto);
      expect(config.rate, SensorRate.ui);
      expect(config.detectCalibration, isTrue);
      expect(config.suppressIosCalibrationHud, isFalse);
      expect(config.magneticFieldBand, const ClampRange(25, 65));
    });

    test('rejects an out-of-range smoothing factor', () {
      expect(() => CompassConfig(smoothingFactor: 1.5), throwsAssertionError);
    });
  });

  group('SensorRate.samplingPeriod', () {
    test('is monotonically slower from fastest to batterySaving', () {
      expect(
        SensorRate.fastest.samplingPeriod.inMicroseconds,
        lessThan(SensorRate.ui.samplingPeriod.inMicroseconds),
      );
      expect(
        SensorRate.ui.samplingPeriod.inMicroseconds,
        lessThan(SensorRate.normal.samplingPeriod.inMicroseconds),
      );
      expect(
        SensorRate.normal.samplingPeriod.inMicroseconds,
        lessThan(SensorRate.batterySaving.samplingPeriod.inMicroseconds),
      );
    });
  });
}
