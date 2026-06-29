import 'package:precise_compass/src/api/enums.dart';

/// A hysteresis state machine that turns a noisy per-sample "is the heading
/// good?" signal into a stable [CalibrationStatus] / `shouldCalibrate` flag.
///
/// Two properties matter in the real world and are guaranteed here:
///
/// 1. **No flicker.** A transient bad (or good) sample never flips the output;
///    the condition must *persist* for [assertAfter] (to recommend calibration)
///    or [clearAfter] (to clear it).
/// 2. **No startup false-positive.** The status begins as
///    [CalibrationStatus.unknown] and only becomes
///    [CalibrationStatus.calibrating] after sustained poor quality — so the
///    brief "unreliable" blip many devices report on cold start is ignored.
///
/// Time is supplied via each sample's timestamp ([update]) rather than a wall
/// clock, which keeps the machine pure and trivially testable.
class CalibrationStateMachine {
  /// Creates a state machine.
  ///
  /// [assertAfter] is how long quality must stay *poor* before
  /// [shouldCalibrate] becomes `true`; [clearAfter] is how long it must stay
  /// *good* before it clears. The defaults (1.5 s / 1.0 s) match the brief.
  CalibrationStateMachine({
    this.assertAfter = const Duration(milliseconds: 1500),
    this.clearAfter = const Duration(milliseconds: 1000),
  });

  /// Sustained-poor duration required to recommend calibration.
  final Duration assertAfter;

  /// Sustained-good duration required to clear the recommendation.
  final Duration clearAfter;

  CalibrationStatus _status = CalibrationStatus.unknown;
  bool? _streakIsGood;
  DateTime? _streakStart;

  /// The current calibration status.
  CalibrationStatus get status => _status;

  /// Whether a calibration (figure-8) motion is currently recommended.
  bool get shouldCalibrate => _status == CalibrationStatus.calibrating;

  /// Feeds one sample and returns the (possibly updated) [status].
  ///
  /// [isGood] is the instantaneous quality verdict for this sample (typically
  /// derived from accuracy + magnetic-field plausibility). [timestamp] should
  /// be monotonically non-decreasing across calls.
  CalibrationStatus update({
    required bool isGood,
    required DateTime timestamp,
  }) {
    if (_streakIsGood != isGood || _streakStart == null) {
      // Condition flipped (or first sample): start a new streak. The current
      // status is intentionally retained until the new streak matures.
      _streakIsGood = isGood;
      _streakStart = timestamp;
      return _status;
    }

    final elapsed = timestamp.difference(_streakStart!);
    if (isGood) {
      if (elapsed >= clearAfter && _status != CalibrationStatus.calibrated) {
        _status = CalibrationStatus.calibrated;
      }
    } else {
      if (elapsed >= assertAfter && _status != CalibrationStatus.calibrating) {
        _status = CalibrationStatus.calibrating;
      }
    }
    return _status;
  }

  /// Resets to [CalibrationStatus.unknown] and forgets any streak.
  void reset() {
    _status = CalibrationStatus.unknown;
    _streakIsGood = null;
    _streakStart = null;
  }
}
