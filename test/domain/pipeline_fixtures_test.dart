import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/precise_compass.dart';
import 'package:precise_compass/src/domain/compass_pipeline.dart';
import 'package:precise_compass/src/models/raw_compass_data.dart';

import '../fixtures/sensor_sequences.dart';

/// Runs a whole sequence through a fresh pipeline and returns every reading.
List<CompassReading> _run(
  List<RawCompassData> sequence, {
  CompassConfig config = const CompassConfig(),
}) {
  final pipeline = CompassPipeline(config: config);
  return sequence.map(pipeline.process).toList();
}

void main() {
  group('pipeline regression on recorded sequences', () {
    test('clean rotation-vector stream reads as high quality', () {
      final readings = _run(cleanRotationVectorSequence());
      final last = readings.last;
      expect(last.accuracy, CompassAccuracy.high);
      expect(last.confidence, greaterThan(0.8));
      expect(last.shouldCalibrate, isFalse);
      expect(last.calibrationStatus, CalibrationStatus.calibrated);
      expect(readings.any((r) => r.shouldCalibrate), isFalse);
    });

    test('magnetic interference is caught despite an optimistic values[4]', () {
      final clean = _run(cleanRotationVectorSequence()).last;
      final readings = _run(magneticInterferenceSequence());
      final last = readings.last;

      // The field magnitude betrays the interference the OS status missed.
      expect(last.shouldCalibrate, isTrue);
      expect(last.calibrationStatus, CalibrationStatus.calibrating);
      // Confidence collapses even though accuracyDegrees stayed "good".
      expect(last.accuracyDegrees, 8);
      expect(last.confidence, lessThan(clean.confidence));
      expect(last.confidence, lessThan(0.6));
    });

    test('cold-start unreliability does not cause a false calibration alarm',
        () {
      final readings = _run(uncalibratedStartupSequence());
      expect(readings.any((r) => r.shouldCalibrate), isFalse);
      expect(readings.last.calibrationStatus, CalibrationStatus.calibrated);
    });

    test('no-gyro device still produces a usable geomagnetic heading', () {
      final readings = _run(noGyroDeviceSequence());
      final last = readings.last;
      expect(last.source, HeadingSource.geomagnetic);
      expect(last.hasHeading, isTrue);
      // values[4] absent -> OS status fallback (15° => medium bucket).
      expect(last.accuracy, CompassAccuracy.medium);
      expect(last.shouldCalibrate, isFalse);
    });
  });
}
