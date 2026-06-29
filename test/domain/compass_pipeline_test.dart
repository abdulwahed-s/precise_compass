import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/precise_compass.dart';
import 'package:precise_compass/src/domain/compass_pipeline.dart';
import 'package:precise_compass/src/models/raw_compass_data.dart';

void main() {
  final t0 = DateTime(2026);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  // magnetic defaults to 90, accuracy to 5 (a clean rotation-vector sample).
  RawCompassData raw({
    HeadingSource source = HeadingSource.rotationVector,
    double? magnetic = 90,
    double? trueHeading,
    double accuracy = 5,
    int? status,
    double? field,
    int ms = 0,
  }) =>
      RawCompassData(
        source: source,
        accuracyDegrees: accuracy,
        magneticHeading: magnetic,
        trueHeading: trueHeading,
        osAccuracyStatus: status,
        magneticFieldMagnitude: field,
        timestamp: at(ms),
      );

  CompassPipeline noSmoothing() =>
      CompassPipeline(config: const CompassConfig(smoothingFactor: 0));

  group('CompassPipeline', () {
    test('emits unavailable for an unavailable source', () {
      final p = CompassPipeline(config: const CompassConfig());
      final r = p.process(
        raw(source: HeadingSource.unavailable, magnetic: null),
      );
      expect(r.source, HeadingSource.unavailable);
      expect(r.hasHeading, isFalse);
    });

    test('produces a basic magnetic reading with continuous accuracy', () {
      final r = noSmoothing().process(raw());
      expect(r.heading, closeTo(90, 1e-9));
      expect(r.headingMagnetic, closeTo(90, 1e-9));
      expect(r.accuracyDegrees, 5);
      expect(r.accuracy, CompassAccuracy.high);
      expect(r.source, HeadingSource.rotationVector);
      expect(r.confidence, greaterThan(0.5));
    });

    test('prefers true heading under auto reference', () {
      final r = noSmoothing().process(raw(trueHeading: 92.5));
      expect(r.headingTrue, closeTo(92.5, 1e-9));
      expect(r.headingMagnetic, closeTo(90, 1e-9));
      expect(r.heading, closeTo(92.5, 1e-9));
    });

    test('uses magnetic north under the magnetic reference', () {
      final p = CompassPipeline(
        config: const CompassConfig(
          reference: HeadingReference.magnetic,
          smoothingFactor: 0,
        ),
      );
      final r = p.process(raw(trueHeading: 92.5));
      expect(r.heading, closeTo(90, 1e-9));
    });

    test('falls back to OS status when continuous accuracy is unavailable', () {
      final r = noSmoothing().process(raw(accuracy: -1, status: 3));
      expect(r.accuracyDegrees, 15);
      expect(r.accuracy, CompassAccuracy.medium);
    });

    test('flags calibration after sustained interference', () {
      final p = noSmoothing();
      CompassReading? last;
      for (var ms = 0; ms <= 2000; ms += 100) {
        last = p.process(raw(accuracy: 60, field: 200, ms: ms));
      }
      expect(last!.shouldCalibrate, isTrue);
      expect(last.calibrationStatus, CalibrationStatus.calibrating);
      expect(last.confidence, lessThan(0.5));
    });

    test('does not flag calibration for a clean, steady signal', () {
      final p = noSmoothing();
      CompassReading? last;
      for (var ms = 0; ms <= 2000; ms += 100) {
        last = p.process(raw(field: 45, ms: ms));
      }
      expect(last!.shouldCalibrate, isFalse);
      expect(last.calibrationStatus, CalibrationStatus.calibrated);
      expect(last.confidence, greaterThan(0.8));
    });

    test('default smoothing attenuates a sudden jump', () {
      final p = CompassPipeline(config: const CompassConfig())..process(raw());
      final r = p.process(raw(magnetic: 120, ms: 33));
      expect(r.heading, greaterThan(90));
      expect(r.heading, lessThan(120));
    });

    test('detectCalibration:false keeps status unknown', () {
      final p = CompassPipeline(
        config: const CompassConfig(
          detectCalibration: false,
          smoothingFactor: 0,
        ),
      );
      CompassReading? last;
      for (var ms = 0; ms <= 2000; ms += 100) {
        last = p.process(raw(accuracy: 90, field: 200, ms: ms));
      }
      expect(last!.shouldCalibrate, isFalse);
      expect(last.calibrationStatus, CalibrationStatus.unknown);
    });

    test('reset clears smoothing and calibration state', () {
      final p = CompassPipeline(config: const CompassConfig())
        ..process(raw())
        ..reset();
      final r = p.process(raw(magnetic: 200));
      // After reset the filter re-initializes to the new sample exactly.
      expect(r.heading, closeTo(200, 1e-9));
    });
  });
}
