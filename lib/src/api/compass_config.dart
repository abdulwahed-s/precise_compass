import 'package:meta/meta.dart';
import 'package:precise_compass/src/api/enums.dart';

/// An inclusive numeric range `[min, max]`.
///
/// Used for the plausible magnetic-field band in [CompassConfig].
@immutable
class ClampRange {
  /// Creates a range. [min] must be `<=` [max].
  const ClampRange(this.min, this.max)
      : assert(min <= max, 'min must be <= max');

  /// Lower bound (inclusive).
  final double min;

  /// Upper bound (inclusive).
  final double max;

  /// Whether [value] lies within `[min, max]` (inclusive).
  bool contains(double value) => value >= min && value <= max;

  @override
  bool operator ==(Object other) =>
      other is ClampRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'ClampRange($min, $max)';
}

/// Immutable configuration for a heading stream.
///
/// Every field has a sensible default; the zero-argument constructor yields the
/// recommended setup. Pass a customized instance to
/// `PreciseCompass.headingStream`.
@immutable
class CompassConfig {
  /// Creates a configuration. All parameters are optional and documented on
  /// their respective fields.
  const CompassConfig({
    this.reference = HeadingReference.auto,
    this.fusionMode = FusionMode.auto,
    this.rate = SensorRate.ui,
    this.smoothingFactor,
    this.detectCalibration = true,
    this.suppressIosCalibrationHud = false,
    this.magneticFieldBand = defaultMagneticFieldBand,
  }) : assert(
          smoothingFactor == null ||
              (smoothingFactor >= 0 && smoothingFactor <= 1),
          'smoothingFactor must be in [0, 1]',
        );

  /// The default plausible magnetic-field band, ≈ Earth's field at the surface
  /// (25–65 µT). Readings outside this band suggest interference.
  static const ClampRange defaultMagneticFieldBand = ClampRange(25, 65);

  /// Which north to report. Defaults to [HeadingReference.auto].
  final HeadingReference reference;

  /// The fusion strategy. Defaults to [FusionMode.auto].
  final FusionMode fusionMode;

  /// The requested sampling rate. Defaults to [SensorRate.ui].
  final SensorRate rate;

  /// The angular low-pass smoothing factor in `[0, 1]`.
  ///
  /// `null` (default) applies the library's adaptive default. `0` disables
  /// smoothing (raw, jittery). Values closer to `1` are smoother but laggier.
  /// Smoothing is always angular-wraparound-safe (applied on unit vectors).
  final double? smoothingFactor;

  /// Whether to run calibration detection and populate
  /// `CompassReading.shouldCalibrate`. Defaults to `true`.
  final bool detectCalibration;

  /// iOS only: when `true`, suppresses the native figure-8 calibration HUD so
  /// the app can present its own UI. Defaults to `false` (show the polished
  /// native HUD). No effect on Android.
  final bool suppressIosCalibrationHud;

  /// The plausible magnetic-field band (µT) used for interference detection.
  /// Defaults to [defaultMagneticFieldBand].
  final ClampRange magneticFieldBand;

  /// Returns a copy with the given fields replaced.
  CompassConfig copyWith({
    HeadingReference? reference,
    FusionMode? fusionMode,
    SensorRate? rate,
    double? smoothingFactor,
    bool? detectCalibration,
    bool? suppressIosCalibrationHud,
    ClampRange? magneticFieldBand,
  }) {
    return CompassConfig(
      reference: reference ?? this.reference,
      fusionMode: fusionMode ?? this.fusionMode,
      rate: rate ?? this.rate,
      smoothingFactor: smoothingFactor ?? this.smoothingFactor,
      detectCalibration: detectCalibration ?? this.detectCalibration,
      suppressIosCalibrationHud:
          suppressIosCalibrationHud ?? this.suppressIosCalibrationHud,
      magneticFieldBand: magneticFieldBand ?? this.magneticFieldBand,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CompassConfig &&
      other.reference == reference &&
      other.fusionMode == fusionMode &&
      other.rate == rate &&
      other.smoothingFactor == smoothingFactor &&
      other.detectCalibration == detectCalibration &&
      other.suppressIosCalibrationHud == suppressIosCalibrationHud &&
      other.magneticFieldBand == magneticFieldBand;

  @override
  int get hashCode => Object.hash(
        reference,
        fusionMode,
        rate,
        smoothingFactor,
        detectCalibration,
        suppressIosCalibrationHud,
        magneticFieldBand,
      );
}
