import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/src/domain/geo/declination.dart';

void main() {
  group('declination conversions', () {
    test('magnetic -> true adds east-positive declination', () {
      expect(magneticToTrueHeading(10, 5), closeTo(15, 1e-9));
      expect(magneticToTrueHeading(358, 5), closeTo(3, 1e-9));
      expect(magneticToTrueHeading(10, -5), closeTo(5, 1e-9));
    });

    test('true -> magnetic subtracts declination', () {
      expect(trueToMagneticHeading(15, 5), closeTo(10, 1e-9));
      expect(trueToMagneticHeading(3, 5), closeTo(358, 1e-9));
    });

    test('round-trips', () {
      expect(
        trueToMagneticHeading(magneticToTrueHeading(123, 7), 7),
        closeTo(123, 1e-9),
      );
    });

    test('inferred declination from paired headings', () {
      expect(
        declinationFromHeadings(
          magneticHeadingDegrees: 10,
          trueHeadingDegrees: 15,
        ),
        closeTo(5, 1e-9),
      );
      expect(
        declinationFromHeadings(
          magneticHeadingDegrees: 350,
          trueHeadingDegrees: 10,
        ),
        closeTo(20, 1e-9),
      );
    });
  });
}
