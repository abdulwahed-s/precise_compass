import 'dart:collection';

import 'package:precise_compass/src/api/compass_config.dart';
import 'package:precise_compass/src/api/compass_reading.dart';
import 'package:precise_compass/src/api/enums.dart';
import 'package:precise_compass/src/domain/accuracy/accuracy_mapper.dart';
import 'package:precise_compass/src/domain/accuracy/confidence_calculator.dart';
import 'package:precise_compass/src/domain/accuracy/magnetic_field_evaluator.dart';
import 'package:precise_compass/src/domain/calibration/calibration_state_machine.dart';
import 'package:precise_compass/src/domain/filtering/angular_low_pass_filter.dart';
import 'package:precise_compass/src/domain/geo/angle_math.dart';
import 'package:precise_compass/src/models/raw_compass_data.dart';

/// The default smoothing factor applied when [CompassConfig.smoothingFactor] is
/// `null` — light smoothing that removes jitter without noticeable lag.
const double kDefaultSmoothingFactor = 0.2;

/// Heading error (degrees) at/below which a sample counts as "good" for
/// calibration purposes (when a continuous estimate is available).
const double kCalibrationGoodThresholdDegrees = 30;

/// Number of recent headings used to estimate short-term stability.
const int kStabilityWindow = 10;

/// The pure-Dart heart of the package: a stateful pipeline that turns a stream
/// of raw native samples ([RawCompassData]) into immutable [CompassReading]s.
///
/// One instance backs one subscription. It owns all per-stream state (filters,
/// rolling windows, the calibration machine) and is fully deterministic given
/// its input samples — every stage is unit-tested without a device.
class CompassPipeline {
  /// Creates a pipeline for the given [config].
  CompassPipeline({required this.config})
      : _magneticFilter = AngularLowPassFilter(
          config.smoothingFactor ?? kDefaultSmoothingFactor,
        ),
        _trueFilter = AngularLowPassFilter(
          config.smoothingFactor ?? kDefaultSmoothingFactor,
        ),
        _fieldEvaluator =
            MagneticFieldEvaluator(band: config.magneticFieldBand),
        _calibration = CalibrationStateMachine();

  /// The configuration governing this pipeline.
  final CompassConfig config;

  final AngularLowPassFilter _magneticFilter;
  final AngularLowPassFilter _trueFilter;
  final MagneticFieldEvaluator _fieldEvaluator;
  final CalibrationStateMachine _calibration;
  final Queue<double> _headingWindow = ListQueue<double>();

  /// Processes a single raw sample and returns the resulting reading.
  ///
  /// Never throws: missing or unusable input yields
  /// [CompassReading.unavailable] rather than an exception.
  CompassReading process(RawCompassData raw) {
    if (raw.source == HeadingSource.unavailable ||
        (raw.magneticHeading == null && raw.trueHeading == null)) {
      return CompassReading.unavailable(timestamp: raw.timestamp);
    }

    final accuracyDegrees = resolveAccuracyDegrees(
      continuousDegrees: raw.accuracyDegrees,
      osStatus: raw.osAccuracyStatus,
    );

    if (raw.magneticFieldMagnitude != null) {
      _fieldEvaluator.add(raw.magneticFieldMagnitude!);
    }
    final field = _fieldEvaluator.quality;

    final smoothedMagnetic = raw.magneticHeading != null
        ? _magneticFilter.filter(raw.magneticHeading!)
        : null;
    final smoothedTrue =
        raw.trueHeading != null ? _trueFilter.filter(raw.trueHeading!) : null;

    final primary = switch (config.reference) {
      HeadingReference.magnetic => smoothedMagnetic ?? smoothedTrue,
      HeadingReference.trueNorth => smoothedTrue ?? smoothedMagnetic,
      HeadingReference.auto => smoothedTrue ?? smoothedMagnetic,
    };
    if (primary == null) {
      return CompassReading.unavailable(timestamp: raw.timestamp);
    }

    _pushHeading(primary);
    final stability = _stabilityDegrees();

    final confidence = computeConfidence(
      accuracyDegrees: accuracyDegrees,
      source: raw.source,
      fieldScore: field?.score,
      headingStabilityDegrees: stability,
    );

    final shouldCalibrate = _updateCalibration(
      accuracyDegrees: accuracyDegrees,
      field: field,
      timestamp: raw.timestamp,
    );

    return CompassReading(
      headingMagnetic: smoothedMagnetic,
      headingTrue: smoothedTrue,
      heading: primary,
      accuracyDegrees: accuracyDegrees,
      accuracy: CompassAccuracy.fromDegrees(
        accuracyDegrees >= 0 ? accuracyDegrees : null,
      ),
      confidence: confidence,
      shouldCalibrate: shouldCalibrate,
      calibrationStatus: config.detectCalibration
          ? _calibration.status
          : CalibrationStatus.unknown,
      source: raw.source,
      magneticFieldMagnitude: field?.mean ?? raw.magneticFieldMagnitude,
      pitch: raw.pitch,
      roll: raw.roll,
      timestamp: raw.timestamp,
    );
  }

  /// Clears all per-stream state. Call when a subscription restarts.
  void reset() {
    _magneticFilter.reset();
    _trueFilter.reset();
    _fieldEvaluator.reset();
    _calibration.reset();
    _headingWindow.clear();
  }

  void _pushHeading(double heading) {
    _headingWindow.addLast(heading);
    while (_headingWindow.length > kStabilityWindow) {
      _headingWindow.removeFirst();
    }
  }

  double? _stabilityDegrees() {
    if (_headingWindow.length < 3) return null;
    final sd = circularStdDevDegrees(_headingWindow);
    return sd.isFinite ? sd : null;
  }

  bool _updateCalibration({
    required double accuracyDegrees,
    required MagneticFieldQuality? field,
    required DateTime timestamp,
  }) {
    if (!config.detectCalibration) return false;

    // Combine signals into a single quality verdict; `null` = no evidence, so
    // the calibration machine keeps its current state (avoids false alarms on
    // devices that report neither a continuous estimate nor field magnitude).
    bool? verdict;
    if (field != null && !field.isPlausible) {
      verdict = false; // interference dominates, even if values[4] is rosy
    } else if (accuracyDegrees >= 0) {
      verdict = accuracyDegrees <= kCalibrationGoodThresholdDegrees;
    } else if (field != null && field.isPlausible) {
      verdict = true;
    }

    if (verdict != null) {
      _calibration.update(isGood: verdict, timestamp: timestamp);
    }
    return _calibration.shouldCalibrate;
  }
}
