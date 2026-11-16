import 'dart:math' as math;
import 'membership.dart';

/// Finite universe of discourse.
final class FuzzyVariable {
  /// Copies [terms] to prevent configuration changes after construction.
  FuzzyVariable(
      {required this.name,
      required this.min,
      required this.max,
      required Map<String, MembershipFunction> terms})
      : terms = Map.unmodifiable(terms) {
    if (name.trim().isEmpty ||
        !min.isFinite ||
        !max.isFinite ||
        min >= max ||
        !(max - min).isFinite ||
        terms.isEmpty ||
        terms.keys.any((k) => k.trim().isEmpty)) {
      throw ArgumentError('Invalid variable: $name');
    }
  }

  /// Unique name within its input or output namespace.
  final String name;

  /// Inclusive lower bound.
  final double min;

  /// Inclusive upper bound.
  final double max;

  /// Linguistic terms and their membership functions.
  final Map<String, MembershipFunction> terms;
}

/// A composable antecedent using min AND, max OR and complement NOT.
sealed class Condition {
  /// Base constructor.
  const Condition();

  /// Degree for already fuzzified input values.
  double evaluate(Map<String, Map<String, double>> values);

  /// All term references, used for eager configuration validation.
  Iterable<Term> get references;

  /// Conjunction.
  Condition and(Condition other) => _Binary(this, other, true);

  /// Disjunction.
  Condition or(Condition other) => _Binary(this, other, false);

  /// Complement.
  Condition not() => _Not(this);
}

/// References a linguistic term on an input variable.
final class Term extends Condition {
  /// Creates an input reference.
  const Term(this.variable, this.term);

  /// Input name.
  final String variable;

  /// Term name.
  final String term;
  @override
  double evaluate(Map<String, Map<String, double>> values) =>
      values[variable]![term]!;
  @override
  Iterable<Term> get references => [this];
}

final class _Binary extends Condition {
  const _Binary(this.left, this.right, this.isAnd);
  final Condition left, right;
  final bool isAnd;
  @override
  double evaluate(Map<String, Map<String, double>> values) => isAnd
      ? math.min(left.evaluate(values), right.evaluate(values))
      : math.max(left.evaluate(values), right.evaluate(values));
  @override
  Iterable<Term> get references => [...left.references, ...right.references];
}

final class _Not extends Condition {
  const _Not(this.child);
  final Condition child;
  @override
  double evaluate(Map<String, Map<String, double>> values) =>
      1 - child.evaluate(values);
  @override
  Iterable<Term> get references => child.references;
}

/// A Mamdani rule with one consequent and optional weight.
final class FuzzyRule {
  /// Weight multiplies antecedent activation and must be between 0 and 1.
  FuzzyRule(
      {required this.name,
      required this.when,
      required this.output,
      required this.term,
      this.weight = 1}) {
    if (name.trim().isEmpty || !weight.isFinite || weight < 0 || weight > 1) {
      throw ArgumentError('Invalid rule name or weight.');
    }
  }

  /// Unique diagnostic name.
  final String name;

  /// Antecedent.
  final Condition when;

  /// Output variable name.
  final String output;

  /// Output term name.
  final String term;

  /// Activation multiplier.
  final double weight;
}
