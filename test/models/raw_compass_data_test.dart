import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/precise_compass.dart';
import 'package:precise_compass/src/models/raw_compass_data.dart';

void main() {
  group('RawCompassData.fromMap', () {
    test('decodes a full Android-style payload', () {
      final raw = RawCompassData.fromMap(const <Object?, Object?>{
        'source': 0,
        'magneticHeading': 123.4,
        'accuracyDegrees': 12.5,
        'osAccuracyStatus': 3,
        'magneticFieldMagnitude': 48.2,
        'pitch': -5.0,
        'roll': 2.0,
        'timestamp': 1700000000000,
      });
      expect(raw.source, HeadingSource.rotationVector);
      expect(raw.magneticHeading, 123.4);
      expect(raw.trueHeading, isNull);
      expect(raw.accuracyDegrees, 12.5);
      expect(raw.osAccuracyStatus, 3);
      expect(raw.magneticFieldMagnitude, 48.2);
      expect(raw.pitch, -5.0);
      expect(raw.timestamp.millisecondsSinceEpoch, 1700000000000);
    });

    test('decodes an iOS-style payload (true + magnetic, no status)', () {
      final raw = RawCompassData.fromMap(const <Object?, Object?>{
        'source': 3,
        'magneticHeading': 90.0,
        'trueHeading': 92.5,
        'accuracyDegrees': 8.0,
        'timestamp': 1700000000000,
      });
      expect(raw.source, HeadingSource.platformHeading);
      expect(raw.trueHeading, 92.5);
      expect(raw.osAccuracyStatus, isNull);
    });

    test('tolerates int where double is expected', () {
      final raw = RawCompassData.fromMap(const <Object?, Object?>{
        'source': 1,
        'magneticHeading': 100, // int, not double
        'accuracyDegrees': 10, // int
        'timestamp': 1700000000000,
      });
      expect(raw.source, HeadingSource.geomagnetic);
      expect(raw.magneticHeading, 100.0);
      expect(raw.accuracyDegrees, 10.0);
    });

    test('defaults missing fields gracefully', () {
      final raw = RawCompassData.fromMap(const <Object?, Object?>{});
      expect(raw.source, HeadingSource.unavailable);
      expect(raw.accuracyDegrees, -1);
      expect(raw.magneticHeading, isNull);
    });
  });

  group('headingSourceFromCode', () {
    test('maps codes and treats unknown as unavailable', () {
      expect(headingSourceFromCode(0), HeadingSource.rotationVector);
      expect(headingSourceFromCode(1), HeadingSource.geomagnetic);
      expect(headingSourceFromCode(2), HeadingSource.fusion);
      expect(headingSourceFromCode(3), HeadingSource.platformHeading);
      expect(headingSourceFromCode(null), HeadingSource.unavailable);
      expect(headingSourceFromCode(99), HeadingSource.unavailable);
    });
  });
}
