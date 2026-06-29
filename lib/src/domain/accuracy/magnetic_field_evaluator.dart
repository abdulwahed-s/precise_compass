import 'dart:collection';
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:precise_compass/src/api/compass_config.dart';

/// A snapshot of magnetic-field quality over a rolling window.
@immutable
class MagneticFieldQuality {
  /// Creates a quality snapshot. All magnitudes are in microtesla (µT).
  const MagneticFieldQuality({
    required this.mean,
    required this.standardDeviation,
    required this.isPlausible,
    required this.plausibilityScore,
    required this.stabilityScore,
  });

  /// Mean field magnitude over the window (µT).
  final double mean;

  /// Population standard deviation of magnitude over the window (µT).
  final double standardDeviation;

  /// Whether [mean] lies within the configured plausible band.
  final bool isPlausible;

  /// `1.0` when the field magnitude is squarely within the plausible band,
  /// decaying toward `0.0` the further the mean strays outside it.
  final double plausibilityScore;

  /// `1.0` when the field is steady, decaying toward `0.0` as variance grows
  /// (rapid swings indicate moving interference sources).
  final double stabilityScore;

  /// The combined field-health score in `[0, 1]` (plausibility × stability).
  double get score => plausibilityScore * stabilityScore;

  @override
  String toString() => 'MagneticFieldQuality('
      'mean: ${mean.toStringAsFixed(1)}µT, '
      'sd: ${standardDeviation.toStringAsFixed(1)}, '
      'plausible: $isPlausible, score: ${score.toStringAsFixed(2)})';
}

/// Detects hard/soft-iron interference and instability by tracking the ambient
/// magnetic-field magnitude over a short rolling window.
///
/// Earth's field is ≈ 25–65 µT; readings well outside the configured
/// [CompassConfig.magneticFieldBand], or rapidly fluctuating ones, indicate
/// interference or poor calibration.
class MagneticFieldEvaluator {
  /// Creates an evaluator for the given plausible [band] and rolling
  /// [windowSize] (number of samples).
  MagneticFieldEvaluator({
    required this.band,
    this.windowSize = 16,
  }) : assert(windowSize > 0, 'windowSize must be positive');

  /// Field magnitudes more than this far (µT) outside [band] score `0`.
  static const double plausibilityToleranceUT = 40;

  /// Standard deviation (µT) at which the stability score reaches `0`.
  static const double stabilityScaleUT = 20;

  /// The plausible magnetic-field band (µT).
  final ClampRange band;

  /// Maximum number of samples retained in the rolling window.
  final int windowSize;

  final Queue<double> _window = ListQueue<double>();

  /// Whether any sample has been recorded.
  bool get hasData => _window.isNotEmpty;

  /// Adds a magnitude sample (µT). Non-finite values are ignored.
  void add(double magnitudeMicroTesla) {
    if (!magnitudeMicroTesla.isFinite) return;
    _window.addLast(magnitudeMicroTesla);
    while (_window.length > windowSize) {
      _window.removeFirst();
    }
  }

  /// Clears the rolling window.
  void reset() => _window.clear();

  /// The current quality snapshot, or `null` if no data has been recorded.
  MagneticFieldQuality? get quality {
    if (_window.isEmpty) return null;
    final mean = _window.reduce((a, b) => a + b) / _window.length;
    final variance = _window.length < 2
        ? 0.0
        : _window.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            _window.length;
    final sd = math.sqrt(variance);

    final isPlausible = band.contains(mean);
    final double plausibilityScore;
    if (isPlausible) {
      plausibilityScore = 1;
    } else {
      final excess = mean < band.min ? band.min - mean : mean - band.max;
      plausibilityScore =
          (1 - excess / plausibilityToleranceUT).clamp(0.0, 1.0);
    }
    final stabilityScore = (1 - sd / stabilityScaleUT).clamp(0.0, 1.0);

    return MagneticFieldQuality(
      mean: mean,
      standardDeviation: sd,
      isPlausible: isPlausible,
      plausibilityScore: plausibilityScore,
      stabilityScore: stabilityScore,
    );
  }
}
