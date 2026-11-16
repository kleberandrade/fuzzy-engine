import 'dart:math' as math;

/// Linguistic modifier applied to an antecedent degree.
/// Custom modifiers must map valid degrees to finite degrees between zero and one.
abstract interface class FuzzyHedge {
  /// Transforms a valid degree; should be deterministic.
  double transform(double degree);
}

/// Linguistic concentration: very A = membership(A)^2.
final class Very implements FuzzyHedge {
  /// Creates a quadratic concentration modifier.
  const Very();
  @override
  double transform(double degree) => degree * degree;
}

/// Linguistic dilation: somewhat A = sqrt(membership(A)).
final class Somewhat implements FuzzyHedge {
  /// Creates a square-root dilation modifier.
  const Somewhat();
  @override
  double transform(double degree) => math.sqrt(degree);
}
