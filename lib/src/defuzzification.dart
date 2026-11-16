import 'dart:math' as math;

/// Uniformly sampled fuzzy output, including both universe endpoints.
/// The degrees are copied and immutable; zero area is represented by all zeros.
final class SampledFuzzySet {
  /// Requires a finite nonempty universe and at least three valid degrees.
  SampledFuzzySet(
      {required this.min, required this.max, required List<double> degrees})
      : degrees = List.unmodifiable(degrees) {
    if (!min.isFinite ||
        !max.isFinite ||
        min >= max ||
        !(max - min).isFinite ||
        degrees.length < 3 ||
        degrees.any((d) => !d.isFinite || d < 0 || d > 1)) {
      throw ArgumentError('Invalid uniformly sampled fuzzy set.');
    }
  }

  /// Universe lower bound.
  final double min;

  /// Universe upper bound.
  final double max;

  /// Uniform membership samples, including both endpoints.
  final List<double> degrees;

  /// Number of integration segments.
  int get intervals => degrees.length - 1;

  /// Whether the sampled set has positive trapezoidal area.
  bool get hasArea => degrees.any((d) => d > 0);

  /// Crisp coordinate at sample [index].
  double xAt(int index) {
    RangeError.checkValidIndex(index, degrees);
    return min + (max - min) * (index / intervals);
  }
}

/// Converts a sampled fuzzy set to a crisp value.
/// Return null only for zero sampled area; otherwise return a finite value
/// inside the sampled universe. Implementations should be deterministic.
abstract interface class Defuzzifier {
  /// Defuzzifies an immutable, uniformly sampled output.
  double? defuzzify(SampledFuzzySet output);
}

/// Centroid using composite trapezoidal quadrature on normalized coordinates.
/// Resolution is selected with FuzzyEngine.intervals, not this strategy.
final class Centroid implements Defuzzifier {
  /// Creates the default centroid strategy.
  const Centroid();
  @override
  double? defuzzify(SampledFuzzySet output) {
    double area = 0, moment = 0;
    for (var i = 0; i <= output.intervals; i++) {
      final t = i / output.intervals;
      final weight = (i == 0 || i == output.intervals) ? 0.5 : 1.0;
      final y = output.degrees[i];
      area += weight * y;
      moment += weight * y * t;
    }
    return area == 0
        ? null
        : output.min + (output.max - output.min) * (moment / area);
  }
}

/// Splits the area under the piecewise linear sampled curve into equal halves.
/// If the half-area is reached before a zero plateau, selects its left edge.
final class Bisector implements Defuzzifier {
  /// Creates the equal-area strategy.
  const Bisector();
  @override
  double? defuzzify(SampledFuzzySet output) {
    final peak = output.degrees.reduce(math.max);
    if (peak == 0) return null;
    // Rescale degrees to avoid losing extremely small positive areas.
    double area = 0;
    for (var i = 0; i < output.intervals; i++) {
      area += (output.degrees[i] / peak + output.degrees[i + 1] / peak) / 2;
    }
    final target = area / 2;
    double accumulated = 0;
    for (var i = 0; i < output.intervals; i++) {
      final left = output.degrees[i] / peak;
      final right = output.degrees[i + 1] / peak;
      final segment = (left + right) / 2;
      if (segment > 0 && accumulated + segment >= target) {
        final remaining = (target - accumulated).clamp(0.0, segment);
        final delta = right - left;
        final denominator =
            left + math.sqrt(math.max(0, left * left + 2 * delta * remaining));
        final fraction = remaining == 0
            ? 0.0
            : (2 * remaining / denominator).clamp(0.0, 1.0);
        final t = (i + fraction) / output.intervals;
        return output.min + (output.max - output.min) * t;
      }
      accumulated += segment;
    }
    // Only reachable through accumulated floating-point rounding at the end.
    return output.max;
  }
}

final class _Maxima {
  const _Maxima(this.first, this.last, this.normalizedMean);
  final int first, last;
  final double normalizedMean;
}

abstract base class _MaximumDefuzzifier implements Defuzzifier {
  _MaximumDefuzzifier(this.tolerance) {
    if (!tolerance.isFinite || tolerance < 0 || tolerance > 1) {
      throw ArgumentError('Maximum tolerance must be between zero and one.');
    }
  }

  /// Absolute membership-degree tolerance; zero selects exact sampled maxima.
  final double tolerance;
  _Maxima? _find(SampledFuzzySet output) {
    final peak = output.degrees.reduce(math.max);
    if (peak == 0) return null;
    var first = -1, last = -1, count = 0;
    double sum = 0;
    for (var i = 0; i <= output.intervals; i++) {
      if (peak - output.degrees[i] <= tolerance) {
        if (first < 0) first = i;
        last = i;
        sum += i / output.intervals;
        count++;
      }
    }
    return _Maxima(first, last, sum / count);
  }
}

/// First grid coordinate whose degree is within tolerance of the global maximum.
final class SmallestOfMaximum extends _MaximumDefuzzifier {
  /// Defaults to exact equality of sampled degrees (tolerance zero).
  SmallestOfMaximum({double tolerance = 0}) : super(tolerance);
  @override
  double? defuzzify(SampledFuzzySet output) {
    final maxima = _find(output);
    return maxima == null ? null : output.xAt(maxima.first);
  }
}

/// Last grid coordinate whose degree is within tolerance of the global maximum.
final class LargestOfMaximum extends _MaximumDefuzzifier {
  /// Defaults to exact equality of sampled degrees (tolerance zero).
  LargestOfMaximum({double tolerance = 0}) : super(tolerance);
  @override
  double? defuzzify(SampledFuzzySet output) {
    final maxima = _find(output);
    return maxima == null ? null : output.xAt(maxima.last);
  }
}

/// Arithmetic mean of all grid coordinates within tolerance of the maximum.
/// For disconnected maxima this need not equal the midpoint of first and last.
final class MeanOfMaximum extends _MaximumDefuzzifier {
  /// Defaults to exact equality of sampled degrees (tolerance zero).
  MeanOfMaximum({double tolerance = 0}) : super(tolerance);
  @override
  double? defuzzify(SampledFuzzySet output) {
    final maxima = _find(output);
    return maxima == null
        ? null
        : output.min + (output.max - output.min) * maxima.normalizedMean;
  }
}
