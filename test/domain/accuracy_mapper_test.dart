import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/src/domain/accuracy/accuracy_mapper.dart';

void main() {
  group('androidAccuracyDegreesFromRadians', () {
    test('converts radians to degrees', () {
      expect(androidAccuracyDegreesFromRadians(0), 0);
      expect(
        androidAccuracyDegreesFromRadians(math.pi / 12),
        closeTo(15, 1e-9),
      );
      expect(
        androidAccuracyDegreesFromRadians(math.pi / 6),
        closeTo(30, 1e-9),
      );
    });

    test('treats negative / NaN as unknown (-1)', () {
      expect(androidAccuracyDegreesFromRadians(-1), kUnknownAccuracyDegrees);
      expect(androidAccuracyDegreesFromRadians(-0.5), kUnknownAccuracyDegrees);
      expect(androidAccuracyDegreesFromRadians(double.nan), -1);
    });

    test('clamps absurdly large values to 180', () {
      expect(androidAccuracyDegreesFromRadians(math.pi * 4), 180);
    });
  });

  group('iosAccuracyDegrees', () {
    test('passes through valid degrees', () {
      expect(iosAccuracyDegrees(0), 0);
      expect(iosAccuracyDegrees(20), 20);
    });

    test('treats negative (invalid) as unknown and clamps high', () {
      expect(iosAccuracyDegrees(-1), kUnknownAccuracyDegrees);
      expect(iosAccuracyDegrees(-42), -1);
      expect(iosAccuracyDegrees(250), 180);
    });
  });

  group('fallbackDegreesFromOsStatus', () {
    test('maps SensorManager status to coarse degrees', () {
      expect(fallbackDegreesFromOsStatus(3), 15);
      expect(fallbackDegreesFromOsStatus(2), 30);
      expect(fallbackDegreesFromOsStatus(1), 45);
      expect(fallbackDegreesFromOsStatus(0), 120);
      expect(fallbackDegreesFromOsStatus(-1), kUnknownAccuracyDegrees);
      expect(fallbackDegreesFromOsStatus(99), kUnknownAccuracyDegrees);
    });
  });

  group('resolveAccuracyDegrees', () {
    test('prefers the continuous estimate', () {
      expect(
        resolveAccuracyDegrees(continuousDegrees: 12, osStatus: 3),
        12,
      );
    });

    test('falls back to status only when continuous is unavailable', () {
      expect(
        resolveAccuracyDegrees(continuousDegrees: -1, osStatus: 2),
        30,
      );
    });

    test('is unknown when nothing is available', () {
      expect(
        resolveAccuracyDegrees(continuousDegrees: -1),
        kUnknownAccuracyDegrees,
      );
    });
  });
}
