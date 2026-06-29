import 'package:flutter_test/flutter_test.dart';
import 'package:precise_compass/precise_compass.dart';
import 'package:precise_compass/src/domain/calibration/calibration_state_machine.dart';

void main() {
  final t0 = DateTime(2026);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  group('CalibrationStateMachine', () {
    test('starts unknown and does not recommend calibration', () {
      final m = CalibrationStateMachine();
      expect(m.status, CalibrationStatus.unknown);
      expect(m.shouldCalibrate, isFalse);
    });

    test('recommends calibration only after sustained poor quality', () {
      final m = CalibrationStateMachine()
        ..update(isGood: false, timestamp: at(0))
        ..update(isGood: false, timestamp: at(1000));
      // Before the 1.5s window elapses: still unknown (no false start).
      expect(m.status, CalibrationStatus.unknown);
      expect(m.shouldCalibrate, isFalse);
      // After 1.5s of sustained poor quality: calibrating.
      m.update(isGood: false, timestamp: at(1600));
      expect(m.status, CalibrationStatus.calibrating);
      expect(m.shouldCalibrate, isTrue);
    });

    test('does not flicker on a transient good blip', () {
      final m = CalibrationStateMachine()
        ..update(isGood: false, timestamp: at(0))
        ..update(isGood: false, timestamp: at(1600)); // -> calibrating
      expect(m.shouldCalibrate, isTrue);

      // A single good sample resets the streak but must NOT clear immediately.
      m.update(isGood: true, timestamp: at(1650));
      expect(m.shouldCalibrate, isTrue);
      // Falling back to bad keeps it calibrating.
      m.update(isGood: false, timestamp: at(1700));
      expect(m.shouldCalibrate, isTrue);
    });

    test('clears only after sustained good quality', () {
      final m = CalibrationStateMachine()
        ..update(isGood: false, timestamp: at(0))
        ..update(isGood: false, timestamp: at(1600)); // calibrating
      expect(m.shouldCalibrate, isTrue);

      m.update(isGood: true, timestamp: at(2000)); // streak starts
      expect(m.shouldCalibrate, isTrue); // < 1s good -> still calibrating
      m.update(isGood: true, timestamp: at(3100)); // > 1s good
      expect(m.status, CalibrationStatus.calibrated);
      expect(m.shouldCalibrate, isFalse);
    });

    test('reset returns to unknown', () {
      final m = CalibrationStateMachine()
        ..update(isGood: false, timestamp: at(0))
        ..update(isGood: false, timestamp: at(2000))
        ..reset();
      expect(m.status, CalibrationStatus.unknown);
      expect(m.shouldCalibrate, isFalse);
    });

    test('honors custom durations', () {
      final m = CalibrationStateMachine(
        assertAfter: const Duration(milliseconds: 500),
      )
        ..update(isGood: false, timestamp: at(0))
        ..update(isGood: false, timestamp: at(600));
      expect(m.status, CalibrationStatus.calibrating);
    });
  });
}
