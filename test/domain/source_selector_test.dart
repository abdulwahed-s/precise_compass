import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/precise_compass.dart';
import 'package:precise_compass/src/domain/fusion/source_selector.dart';

void main() {
  CompassCapabilities caps({
    bool rotationVector = false,
    bool geomagnetic = false,
    bool magnetometer = false,
    bool gyroscope = false,
    bool accelerometer = false,
  }) =>
      CompassCapabilities(
        hasRotationVector: rotationVector,
        hasGeomagneticRotationVector: geomagnetic,
        hasMagnetometer: magnetometer,
        hasGyroscope: gyroscope,
        hasAccelerometer: accelerometer,
        supportsTrueHeading: false,
        recommendedMode: FusionMode.auto,
      );

  group('recommendFusionMode', () {
    test('prefers the rotation vector', () {
      expect(
        recommendFusionMode(caps(rotationVector: true, magnetometer: true)),
        FusionMode.rotationVector,
      );
    });

    test('uses geomagnetic when no rotation vector', () {
      expect(
        recommendFusionMode(caps(geomagnetic: true)),
        FusionMode.geomagnetic,
      );
    });

    test('uses manual fusion when a gyroscope is present', () {
      expect(
        recommendFusionMode(
          caps(magnetometer: true, accelerometer: true, gyroscope: true),
        ),
        FusionMode.fusion,
      );
    });

    test('uses geomagnetic for an accel+mag device without a gyroscope', () {
      expect(
        recommendFusionMode(caps(magnetometer: true, accelerometer: true)),
        FusionMode.geomagnetic,
      );
    });

    test('returns auto when nothing is usable', () {
      expect(recommendFusionMode(caps()), FusionMode.auto);
    });
  });

  group('resolveFusionMode', () {
    test('auto delegates to the recommendation', () {
      expect(
        resolveFusionMode(FusionMode.auto, caps(rotationVector: true)),
        FusionMode.rotationVector,
      );
    });

    test('honors a supported explicit request', () {
      expect(
        resolveFusionMode(
          FusionMode.fusion,
          caps(magnetometer: true, accelerometer: true, gyroscope: true),
        ),
        FusionMode.fusion,
      );
    });

    test('degrades gracefully when a request is unsupported', () {
      // Asked for rotation vector, but only accel+mag exist.
      expect(
        resolveFusionMode(
          FusionMode.rotationVector,
          caps(magnetometer: true, accelerometer: true),
        ),
        FusionMode.geomagnetic,
      );
      // Asked for manual fusion, but there is no gyroscope.
      expect(
        resolveFusionMode(
          FusionMode.fusion,
          caps(magnetometer: true, accelerometer: true),
        ),
        FusionMode.geomagnetic,
      );
    });
  });
}
