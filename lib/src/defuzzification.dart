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
