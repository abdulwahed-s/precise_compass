import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/precise_compass.dart';
import 'package:precise_compass/src/domain/accuracy/magnetic_field_evaluator.dart';

void main() {
  MagneticFieldEvaluator newEvaluator({int windowSize = 16}) =>
      MagneticFieldEvaluator(
        band: const ClampRange(25, 65),
        windowSize: windowSize,
      );

  group('MagneticFieldEvaluator', () {
    test('reports no quality before any data', () {
      final e = newEvaluator();
      expect(e.hasData, isFalse);
      expect(e.quality, isNull);
    });

    test('scores a steady, in-band field as healthy', () {
      final e = newEvaluator();
      <double>[45, 46, 44, 45.5, 44.5].forEach(e.add);
      final q = e.quality!;
      expect(q.isPlausible, isTrue);
      expect(q.mean, closeTo(45, 1));
      expect(q.plausibilityScore, 1);
      expect(q.stabilityScore, greaterThan(0.9));
      expect(q.score, greaterThan(0.9));
    });

    test('flags a strong out-of-band field as interference', () {
      final e = newEvaluator();
      List<double>.filled(8, 200).forEach(e.add);
      final q = e.quality!;
      expect(q.isPlausible, isFalse);
      // 200µT is >40µT beyond the band, so plausibility collapses to 0.
      expect(q.plausibilityScore, 0);
      expect(q.score, 0);
    });

    test('penalizes a fluctuating field via the stability score', () {
      final steady = newEvaluator();
      <double>[45, 45, 45, 45].forEach(steady.add);
      final jumpy = newEvaluator();
      <double>[30, 60, 28, 62].forEach(jumpy.add);
      expect(
        jumpy.quality!.stabilityScore,
        lessThan(steady.quality!.stabilityScore),
      );
    });

    test('caps the rolling window and ignores non-finite input', () {
      final e = newEvaluator(windowSize: 3);
      <double>[10, 10, 10, 50, 50, 50].forEach(e.add);
      // Only the last 3 (all 50) remain.
      expect(e.quality!.mean, closeTo(50, 1e-9));
      e
        ..add(double.nan)
        ..add(double.infinity);
      expect(e.quality!.mean, closeTo(50, 1e-9));
    });

    test('reset clears the window', () {
      final e = newEvaluator()..add(45);
      expect(e.hasData, isTrue);
      e.reset();
      expect(e.hasData, isFalse);
      expect(e.quality, isNull);
    });
  });
}
