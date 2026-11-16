import 'dart:math' as math;

// Internal shared arithmetic; values are validated before entering these helpers.
double weightedAverage(List<double> weights, List<double> values) {
  final peak = weights.reduce(math.max);
  final scaled = weights.map((weight) => weight / peak).toList();
  final denominator = sumFinite(scaled);
  final terms = [
    for (var i = 0; i < values.length; i++) scaled[i] * values[i] / denominator
  ];
  return sumFinite(terms,
      convexMin: values.reduce(math.min), convexMax: values.reduce(math.max));
}

// Compensated summation, with a scaled fallback if intermediate sums overflow.
// Averages are restricted only to their mathematical active-consequent hull,
// guarding rounding at extreme magnitudes; no application output bounds exist.
double sumFinite(List<double> terms, {double? convexMin, double? convexMax}) {
  if (terms.isEmpty) return 0;
  double total = 0, correction = 0;
  for (final term in terms) {
    final next = total + term;
    if (!next.isFinite) {
      total = double.nan;
      break;
    }
    correction += total.abs() >= term.abs()
        ? (total - next) + term
        : (term - next) + total;
    total = next;
  }
  double result = total + correction;
  if (!result.isFinite) {
    final scale = terms.map((term) => term.abs()).reduce(math.max);
    if (scale == 0) return 0;
    total = 0;
    correction = 0;
    for (final term in terms) {
      final normalized = term / scale;
      final next = total + normalized;
      correction += total.abs() >= normalized.abs()
          ? (total - next) + normalized
          : (normalized - next) + total;
      total = next;
    }
    result = (total + correction) * scale;
  }
  if (convexMin != null && convexMax != null && !result.isNaN) {
    result = result.clamp(convexMin, convexMax).toDouble();
  }
  if (!result.isFinite)
    throw StateError('Sugeno arithmetic result is not finite.');
  return result;
}
