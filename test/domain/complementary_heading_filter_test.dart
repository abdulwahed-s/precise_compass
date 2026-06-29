import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/src/domain/fusion/complementary_heading_filter.dart';
import 'package:precise_compass/src/domain/geo/angle_math.dart';

void main() {
  group('ComplementaryHeadingFilter', () {
    test('seeds from the magnetometer on the first sample', () {
      final f = ComplementaryHeadingFilter();
      expect(f.hasValue, isFalse);
      final h = f.update(
        magnetometerHeadingDegrees: 42,
        gyroDeltaDegrees: 999, // ignored on first (seed) sample
      );
      expect(h, closeTo(42, 1e-9));
      expect(f.hasValue, isTrue);
    });

    test('integrates pure gyro motion when the magnetometer is unreliable', () {
      final f = ComplementaryHeadingFilter()
        ..update(magnetometerHeadingDegrees: 0, gyroDeltaDegrees: 0);
      var h = 0.0;
      for (var i = 0; i < 3; i++) {
        h = f.update(
          magnetometerHeadingDegrees: 0,
          gyroDeltaDegrees: 10,
          magnetometerReliable: false,
        );
      }
      expect(h, closeTo(30, 1e-9));
    });

    test('converges toward the magnetometer when stationary', () {
      final f = ComplementaryHeadingFilter()
        ..update(magnetometerHeadingDegrees: 0, gyroDeltaDegrees: 0);
      var h = 0.0;
      for (var i = 0; i < 200; i++) {
        h = f.update(magnetometerHeadingDegrees: 90, gyroDeltaDegrees: 0);
      }
      expect(h, closeTo(90, 0.5));
    });

    test('is wraparound-safe', () {
      final f = ComplementaryHeadingFilter()
        ..update(magnetometerHeadingDegrees: 350, gyroDeltaDegrees: 0);
      final h = f.update(
        magnetometerHeadingDegrees: 350,
        gyroDeltaDegrees: 20,
        magnetometerReliable: false,
      );
      // 350 + 20 = 370 -> 10, never near 180.
      expect(angularDistance(h, 10), lessThan(1e-9));
    });

    test('reset re-seeds on the next sample', () {
      final f = ComplementaryHeadingFilter()
        ..update(magnetometerHeadingDegrees: 10, gyroDeltaDegrees: 0)
        ..reset();
      expect(f.hasValue, isFalse);
      final h = f.update(magnetometerHeadingDegrees: 200, gyroDeltaDegrees: 0);
      expect(h, closeTo(200, 1e-9));
    });

    test('rejects an invalid gain', () {
      expect(
        () => ComplementaryHeadingFilter(magnetometerGain: 0),
        throwsAssertionError,
      );
      expect(
        () => ComplementaryHeadingFilter(magnetometerGain: 1.5),
        throwsAssertionError,
      );
    });
  });
}
