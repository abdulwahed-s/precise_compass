import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/src/domain/geo/angle_math.dart';

void main() {
  group('normalizeDegrees', () {
    test('wraps into [0, 360)', () {
      expect(normalizeDegrees(0), 0);
      expect(normalizeDegrees(360), 0);
      expect(normalizeDegrees(450), 90);
      expect(normalizeDegrees(-90), 270);
      expect(normalizeDegrees(-360), 0);
      expect(normalizeDegrees(720), 0);
      expect(normalizeDegrees(-450), 270);
    });

    test('returns NaN for non-finite input', () {
      expect(normalizeDegrees(double.nan).isNaN, isTrue);
      expect(normalizeDegrees(double.infinity).isNaN, isTrue);
    });
  });

  group('normalizeDegreesSigned', () {
    test('wraps into [-180, 180)', () {
      expect(normalizeDegreesSigned(0), 0);
      expect(normalizeDegreesSigned(90), 90);
      expect(normalizeDegreesSigned(180), -180);
      expect(normalizeDegreesSigned(270), -90);
      expect(normalizeDegreesSigned(-270), 90);
    });
  });

  group('shortestAngularDifference', () {
    test('takes the short way around the circle', () {
      expect(shortestAngularDifference(350, 10), 20);
      expect(shortestAngularDifference(10, 350), -20);
      expect(shortestAngularDifference(0, 90), 90);
      expect(shortestAngularDifference(90, 0), -90);
    });

    test('angularDistance is the absolute shortest distance', () {
      expect(angularDistance(350, 10), 20);
      expect(angularDistance(0, 180), 180);
      expect(angularDistance(10, 10), 0);
    });
  });

  group('meanAngleDegrees', () {
    test('averages correctly across the 0/360 boundary', () {
      // The mean of 350 and 10 is north; compare with wraparound tolerance.
      expect(angularDistance(meanAngleDegrees([350, 10]), 0), lessThan(1e-6));
      expect(meanAngleDegrees([10, 20, 30]), closeTo(20, 1e-9));
      expect(meanAngleDegrees([90]), closeTo(90, 1e-9));
    });

    test('returns NaN for empty or cancelling inputs', () {
      expect(meanAngleDegrees(const []).isNaN, isTrue);
      expect(meanAngleDegrees([0, 180]).isNaN, isTrue);
    });
  });

  group('lerpAngleDegrees', () {
    test('interpolates along the short arc', () {
      expect(lerpAngleDegrees(350, 10, 0.5), closeTo(0, 1e-9));
      expect(lerpAngleDegrees(0, 90, 0.5), closeTo(45, 1e-9));
    });

    test('clamps t to [0, 1]', () {
      expect(lerpAngleDegrees(0, 90, -1), closeTo(0, 1e-9));
      expect(lerpAngleDegrees(0, 90, 2), closeTo(90, 1e-9));
    });
  });

  group('circularStdDevDegrees', () {
    test('is zero for identical angles', () {
      expect(circularStdDevDegrees([42, 42, 42]), closeTo(0, 1e-9));
    });

    test('grows with spread and is NaN for < 2 samples', () {
      final tight = circularStdDevDegrees([10, 12, 11, 9]);
      final loose = circularStdDevDegrees([10, 40, 80, 350]);
      expect(tight, lessThan(loose));
      expect(circularStdDevDegrees([10]).isNaN, isTrue);
    });

    test('is infinite when vectors fully cancel', () {
      expect(circularStdDevDegrees([0, 90, 180, 270]), double.infinity);
    });
  });

  group('degree/radian conversion round-trips', () {
    test('are inverses', () {
      expect(radiansToDegrees(degreesToRadians(123.4)), closeTo(123.4, 1e-9));
    });
  });
}
