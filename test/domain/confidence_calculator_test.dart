import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/precise_compass.dart';
import 'package:precise_compass/src/domain/accuracy/confidence_calculator.dart';

void main() {
  group('sourceQualityScore', () {
    test('ranks sources and gates unavailable to zero', () {
      expect(sourceQualityScore(HeadingSource.rotationVector), 1);
      expect(
        sourceQualityScore(HeadingSource.geomagnetic),
        lessThan(sourceQualityScore(HeadingSource.rotationVector)),
      );
      expect(sourceQualityScore(HeadingSource.unavailable), 0);
    });
  });

  group('computeConfidence', () {
    test('is near 1 for an excellent rotation-vector reading', () {
      final c = computeConfidence(
        accuracyDegrees: 0,
        source: HeadingSource.rotationVector,
        fieldScore: 1,
        headingStabilityDegrees: 0,
      );
      expect(c, closeTo(1, 1e-9));
    });

    test('is exactly 0 when the source is unavailable', () {
      final c = computeConfidence(
        accuracyDegrees: 0,
        source: HeadingSource.unavailable,
        fieldScore: 1,
        headingStabilityDegrees: 0,
      );
      expect(c, 0);
    });

    test('decreases monotonically as accuracy degrees grow', () {
      double conf(double deg) => computeConfidence(
            accuracyDegrees: deg,
            source: HeadingSource.rotationVector,
            fieldScore: 1,
            headingStabilityDegrees: 0,
          );
      expect(conf(0), greaterThan(conf(10)));
      expect(conf(10), greaterThan(conf(20)));
      expect(conf(20), greaterThan(conf(45)));
    });

    test('decreases as field health worsens', () {
      double conf(double field) => computeConfidence(
            accuracyDegrees: 5,
            source: HeadingSource.rotationVector,
            fieldScore: field,
            headingStabilityDegrees: 0,
          );
      expect(conf(1), greaterThan(conf(0.5)));
      expect(conf(0.5), greaterThan(conf(0)));
    });

    test('uses neutral sub-scores for unknown inputs and stays in [0,1]', () {
      final c = computeConfidence(
        accuracyDegrees: -1,
        source: HeadingSource.geomagnetic,
      );
      expect(c, inInclusiveRange(0, 1));
      expect(c, greaterThan(0));
    });
  });
}
