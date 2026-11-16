import 'dart:math' as math;

/// Checks runtime extension results without silently clamping invalid degrees.
double checkedDegree(double value) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw StateError('Fuzzy degrees must be finite and between zero and one.');
  }
  return value;
}

/// Conjunction/implication operator on degrees between zero and one.
/// Implementations must obey t-norm laws, including neutral element one.
abstract interface class TNorm {
  /// Combines two valid degrees into a valid degree.
  double combine(double a, double b);
}

/// Disjunction/aggregation operator on degrees between zero and one.
/// Implementations must obey s-norm laws, including neutral element zero.
abstract interface class SNorm {
  /// Combines two valid degrees into a valid degree.
  double combine(double a, double b);
}

/// Decreasing complement with endpoints complement(0)=1, complement(1)=0.
abstract interface class FuzzyNegation {
  /// Complements a valid degree.
  double complement(double value);
}

/// Minimum t-norm: min(a, b).
final class Minimum implements TNorm {
  /// Creates the default conjunction and implication.
  const Minimum();
  @override
  double combine(double a, double b) => math.min(a, b);
}

/// Algebraic product t-norm: a * b.
final class AlgebraicProduct implements TNorm {
  /// Creates a product operator.
  const AlgebraicProduct();
  @override
  double combine(double a, double b) => a * b;
}

/// Lukasiewicz t-norm: max(0, a + b - 1).
final class BoundedDifference implements TNorm {
  /// Creates a bounded-difference operator.
  const BoundedDifference();
  @override
  double combine(double a, double b) => math.max(0, a + b - 1);
}

/// Maximum s-norm: max(a, b).
final class Maximum implements SNorm {
  /// Creates the default disjunction and aggregation.
  const Maximum();
  @override
  double combine(double a, double b) => math.max(a, b);
}

/// Probabilistic sum s-norm: a + b - a * b.
/// The name describes its algebra; fuzzy degrees are not probabilities.
final class ProbabilisticSum implements SNorm {
  /// Creates a probabilistic-sum operator.
  const ProbabilisticSum();
  @override
  double combine(double a, double b) => a + (1 - a) * b;
}

/// Bounded sum s-norm: min(1, a + b).
final class BoundedSum implements SNorm {
  /// Creates a bounded-sum operator.
  const BoundedSum();
  @override
  double combine(double a, double b) => math.min(1, a + b);
}

/// Standard complement: 1 - value.
final class StandardNegation implements FuzzyNegation {
  /// Creates the default negation.
  const StandardNegation();
  @override
  double complement(double value) => 1 - value;
}

/// Operators shared by all antecedent expressions in one engine evaluation.
final class FuzzyOperators {
  /// Defaults preserve min AND, max OR and complement NOT.
  const FuzzyOperators(
      {this.conjunction = const Minimum(),
      this.disjunction = const Maximum(),
      this.negation = const StandardNegation()});

  /// AND strategy.
  final TNorm conjunction;

  /// OR strategy.
  final SNorm disjunction;

  /// NOT strategy.
  final FuzzyNegation negation;

  /// Applies AND and validates the extension's result.
  double and(double a, double b) => checkedDegree(conjunction.combine(a, b));

  /// Applies OR and validates the extension's result.
  double or(double a, double b) => checkedDegree(disjunction.combine(a, b));

  /// Applies NOT and validates the extension's result.
  double not(double value) => checkedDegree(negation.complement(value));
}
