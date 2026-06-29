import 'package:precise_compass/src/api/enums.dart';

/// Confidence-model constants. Documented here and in `ARCHITECTURE.md` so the
/// score is fully transparent and reproducible.
abstract final class ConfidenceWeights {
  /// Weight of the continuous-accuracy sub-score in the additive base.
  static const double accuracy = 0.75;

  /// Weight of the short-term heading-stability sub-score in the additive base.
  static const double stability = 0.25;

  /// Accuracy (degrees) at which the accuracy sub-score reaches `0`.
  static const double accuracyZeroAtDegrees = 60;

  /// Heading circular std-dev (degrees) at which stability reaches `0`.
  static const double stabilityZeroAtDegrees = 30;

  /// Sub-score used when the accuracy estimate is unavailable.
  static const double unknownAccuracyScore = 0.4;

  /// Stability sub-score used when stability is unknown.
  static const double unknownNeutralScore = 0.7;

  /// The lowest the magnetic-field gate can pull confidence (when the field is
  /// maximally implausible). Field health gates the whole score because strong
  /// interference invalidates the heading no matter how rosy `values[4]` looks.
  static const double fieldGateFloor = 0.4;
}

/// Returns the quality multiplier for a [HeadingSource] in `[0, 1]`.
///
/// Higher-fidelity sources contribute more; [HeadingSource.unavailable] gates
/// the whole confidence to `0`.
double sourceQualityScore(HeadingSource source) {
  switch (source) {
    case HeadingSource.rotationVector:
      return 1;
    case HeadingSource.platformHeading:
      return 0.95;
    case HeadingSource.geomagnetic:
      return 0.85;
    case HeadingSource.fusion:
      return 0.8;
    case HeadingSource.unavailable:
      return 0;
  }
}

/// Computes a single, developer-friendly confidence score in `[0, 1]`.
///
/// The model blends two additive sub-scores — continuous accuracy and
/// short-term heading stability — then gates the result by source quality and
/// magnetic-field health:
///
/// ```text
/// base       = wAcc·accuracyScore + wStab·stabilityScore
/// fieldGate  = field known ? floor + (1-floor)·fieldScore : 1
/// confidence = clamp(base · sourceQuality · fieldGate, 0, 1)
/// ```
///
/// The result is monotonic: improving any input never lowers the score.
/// Gating (rather than averaging) the field means that detected interference
/// collapses confidence even when the OS-reported accuracy is optimistic — the
/// core advantage of multi-signal trust assessment.
///
/// - [accuracyDegrees]: continuous estimate; `< 0` means unavailable.
/// - [source]: which path produced the heading.
/// - [fieldScore]: `0..1` magnetic-field health; `null` if unknown (no gate).
/// - [headingStabilityDegrees]: recent heading circular std-dev, or `null`.
double computeConfidence({
  required double accuracyDegrees,
  required HeadingSource source,
  double? fieldScore,
  double? headingStabilityDegrees,
}) {
  final accuracyScore = accuracyDegrees < 0
      ? ConfidenceWeights.unknownAccuracyScore
      : (1 - accuracyDegrees / ConfidenceWeights.accuracyZeroAtDegrees)
          .clamp(0.0, 1.0);

  final stabilityScore = headingStabilityDegrees == null
      ? ConfidenceWeights.unknownNeutralScore
      : (1 - headingStabilityDegrees / ConfidenceWeights.stabilityZeroAtDegrees)
          .clamp(0.0, 1.0);

  final base = ConfidenceWeights.accuracy * accuracyScore +
      ConfidenceWeights.stability * stabilityScore;

  final fieldGate = fieldScore == null
      ? 1.0
      : ConfidenceWeights.fieldGateFloor +
          (1 - ConfidenceWeights.fieldGateFloor) * fieldScore.clamp(0.0, 1.0);

  return (base * sourceQualityScore(source) * fieldGate).clamp(0.0, 1.0);
}
