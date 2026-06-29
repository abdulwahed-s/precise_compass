import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/src/domain/filtering/angular_low_pass_filter.dart';

void main() {
  group('AngularLowPassFilter', () {
    test('starts empty and initializes on first sample', () {
      final f = AngularLowPassFilter(0.5);
      expect(f.hasValue, isFalse);
      expect(f.value, isNull);
      expect(f.filter(42), closeTo(42, 1e-9));
      expect(f.hasValue, isTrue);
    });

    test('passes through when smoothingFactor == 0', () {
      final f = AngularLowPassFilter(0);
      expect(f.filter(10), closeTo(10, 1e-9));
      expect(f.filter(200), closeTo(200, 1e-9));
      expect(f.filter(359), closeTo(359, 1e-9));
    });

    test('is wraparound-safe: smoothing 359 then 1 yields ~0, not ~180', () {
      final f = AngularLowPassFilter(0.5)..filter(359);
      final result = f.filter(1);
      // Shortest-arc smoothing must keep us near north.
      final distanceToNorth = (result > 180 ? 360 - result : result).abs();
      expect(distanceToNorth, lessThan(1));
    });

    test('converges toward a steady input', () {
      final f = AngularLowPassFilter(0.8)..filter(0);
      late double result;
      for (var i = 0; i < 100; i++) {
        result = f.filter(90);
      }
      expect(result, closeTo(90, 0.5));
    });

    test('freezes on first sample when smoothingFactor == 1', () {
      final f = AngularLowPassFilter(1)..filter(30);
      expect(f.filter(120), closeTo(30, 1e-9));
      expect(f.filter(300), closeTo(30, 1e-9));
    });

    test('ignores non-finite input', () {
      final f = AngularLowPassFilter(0.5)..filter(45);
      expect(f.filter(double.nan), closeTo(45, 1e-9));
      expect(f.filter(double.infinity), closeTo(45, 1e-9));
    });

    test('reset clears state', () {
      final f = AngularLowPassFilter(0.5)
        ..filter(45)
        ..reset();
      expect(f.hasValue, isFalse);
      expect(f.filter(123), closeTo(123, 1e-9));
    });

    test('rejects an out-of-range smoothing factor', () {
      expect(() => AngularLowPassFilter(1.5), throwsAssertionError);
      expect(() => AngularLowPassFilter(-0.1), throwsAssertionError);
    });
  });
}
