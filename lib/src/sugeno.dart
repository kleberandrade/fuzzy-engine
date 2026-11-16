import 'inference_support.dart';
import 'model.dart';
import 'operators.dart';
import 'weighted_reduction.dart';

/// Distinct Sugeno reduction methods; neither samples a fuzzy output set.
enum SugenoAggregation {
  /// Sum(w * z) / sum(w); preserves the convex hull of active consequents.
  weightedAverage,

  /// Sum(w * z), without normalization. May exceed any individual consequent.
  weightedSum,
}

/// Crisp consequent evaluated against the original crisp input values.
/// Custom implementations must declare all input references, be deterministic,
/// and return a finite result. Inputs supplied by the engine are immutable.
abstract interface class SugenoConsequent {
  /// Input names used by this consequent, for eager reference validation.
  Iterable<String> get references;

  /// Computes a crisp value, not a membership degree.
  double evaluate(Map<String, double> inputs);
}

/// Zero-order Sugeno consequent: a constant crisp value.
final class ConstantConsequent implements SugenoConsequent {
  /// Requires a finite constant; negative values are allowed.
  ConstantConsequent(this.value) {
    if (!value.isFinite) throw ArgumentError('Constant must be finite.');
  }

  /// Crisp constant.
  final double value;
  @override
  Iterable<String> get references => const [];
  @override
  double evaluate(Map<String, double> inputs) => value;
}

/// First-order consequent: `intercept + sum(coefficient[name] * input[name])`.
final class LinearConsequent implements SugenoConsequent {
  /// Copies named finite coefficients. An empty map reduces to the intercept.
  LinearConsequent(
      {this.intercept = 0, required Map<String, double> coefficients})
      : coefficients = Map.unmodifiable(coefficients) {
    if (!intercept.isFinite ||
        coefficients.entries.any(
            (entry) => entry.key.trim().isEmpty || !entry.value.isFinite)) {
      throw ArgumentError(
          'Linear consequent requires finite parameters and nonempty names.');
    }
  }

  /// Constant offset.
  final double intercept;

  /// Immutable coefficients indexed by input variable name.
  final Map<String, double> coefficients;
  @override
  Iterable<String> get references => coefficients.keys;
  @override
  double evaluate(Map<String, double> inputs) {
    final terms = <double>[intercept];
    for (final entry in coefficients.entries) {
      final input = inputs[entry.key];
      if (input == null || !input.isFinite) {
        throw ArgumentError(
            'Missing or nonfinite consequent input: ${entry.key}');
      }
      final term = entry.value * input;
      if (!term.isFinite)
        throw StateError('Linear consequent product overflowed.');
      terms.add(term);
    }
    return sumFinite(terms);
  }
}

/// Named crisp output. Sugeno outputs do not have membership functions or bounds.
final class SugenoOutput {
  /// Requires a nonempty name. Output units are chosen by the application.
  SugenoOutput(this.name) {
    if (name.trim().isEmpty)
      throw ArgumentError('Output name must not be empty.');
  }

  /// Name used by rules and result lookups.
  final String name;
}

/// One weighted antecedent and one crisp Sugeno consequent.
final class SugenoRule {
  /// Weight multiplies the complete antecedent and must be between zero and one.
  SugenoRule(
      {required this.name,
      required this.when,
      required this.output,
      required this.consequent,
      this.weight = 1}) {
    if (name.trim().isEmpty || !weight.isFinite || weight < 0 || weight > 1) {
      throw ArgumentError('Invalid Sugeno rule name or weight.');
    }
  }

  /// Unique diagnostic name.
  final String name;

  /// Fuzzy input condition, including nested operators and hedges.
  final Condition when;

  /// Named crisp output.
  final String output;

  /// Constant, linear or custom crisp consequent.
  final SugenoConsequent consequent;

  /// Activation multiplier.
  final double weight;
}

/// Explanation for one Sugeno rule, including inactive rules.
final class SugenoActivation {
  SugenoActivation._(
      this.rule, this.antecedent, this.strength, this.consequentValue);

  /// Evaluated rule.
  final SugenoRule rule;

  /// Unweighted antecedent degree.
  final double antecedent;

  /// Antecedent multiplied by rule weight.
  final double strength;

  /// Crisp consequent value; null when inactive (the consequent was not evaluated).
  final double? consequentValue;

  /// Raw strength * consequent value, before any average normalization.
  /// May underflow to zero; inactive rules return null.
  double? get weightedContribution =>
      consequentValue == null ? null : strength * consequentValue!;
}

/// Immutable Sugeno outputs, fuzzified inputs and rule explanations.
final class SugenoResult {
  SugenoResult._(
      Map<String, double?> outputs,
      Map<String, Map<String, double>> memberships,
      List<SugenoActivation> rules,
      Map<String, double> totalWeights)
      : outputs = Map.unmodifiable(outputs),
        memberships = Map.unmodifiable(memberships.map((key, value) =>
            MapEntry(key, Map<String, double>.unmodifiable(value)))),
        rules = List.unmodifiable(rules),
        totalWeights = Map.unmodifiable(totalWeights);

  /// Crisp values; null when no rule has positive strength for that output.
  final Map<String, double?> outputs;

  /// Input membership degrees.
  final Map<String, Map<String, double>> memberships;

  /// All rules in declaration order, including inactive ones.
  final List<SugenoActivation> rules;

  /// Sum of raw rule strengths for each declared output.
  final Map<String, double> totalWeights;

  /// Reads a declared output; throws for unknown names.
  double? value(String name) {
    if (!outputs.containsKey(name))
      throw ArgumentError('Unknown output: $name');
    return outputs[name];
  }
}

/// Takagi-Sugeno inference with crisp consequents and explainable reductions.
/// Shares input membership functions, conditions, operators and hedges with Mamdani.
final class SugenoEngine {
  /// No output grid, implication strategy or integral defuzzifier is used.
  SugenoEngine(
      {required List<FuzzyVariable> inputs,
      required List<SugenoOutput> outputs,
      required List<SugenoRule> rules,
      this.operators = const FuzzyOperators(),
      this.aggregation = SugenoAggregation.weightedAverage})
      : inputs = List.unmodifiable(inputs),
        outputs = List.unmodifiable(outputs),
        rules = List.unmodifiable(rules) {
    if (inputs.isEmpty || outputs.isEmpty || rules.isEmpty) {
      throw ArgumentError('Inputs, outputs and rules are required.');
    }
    final indexed = indexFuzzyVariables(inputs);
    final outputNames = <String>{};
    for (final output in outputs) {
      if (!outputNames.add(output.name))
        throw ArgumentError('Duplicate output: ${output.name}');
    }
    final ruleNames = <String>{};
    for (final rule in rules) {
      if (!ruleNames.add(rule.name))
        throw ArgumentError('Duplicate rule: ${rule.name}');
      if (!outputNames.contains(rule.output))
        throw ArgumentError('Unknown output: ${rule.output}');
      for (final reference in rule.when.references) {
        if (!(indexed[reference.variable]?.terms.containsKey(reference.term) ??
            false)) {
          throw ArgumentError(
              'Unknown input term: ${reference.variable}.${reference.term}');
        }
      }
      for (final name in rule.consequent.references) {
        if (!indexed.containsKey(name))
          throw ArgumentError('Unknown consequent input: $name');
      }
    }
  }

  /// Fuzzy inputs, with finite universes and membership functions.
  final List<FuzzyVariable> inputs;

  /// Named crisp outputs, separate from Mamdani output variables.
  final List<SugenoOutput> outputs;

  /// Weighted rules in declaration order.
  final List<SugenoRule> rules;

  /// Antecedent AND/OR/NOT strategies.
  final FuzzyOperators operators;

  /// Weighted average by default; weighted sum is an explicit different method.
  final SugenoAggregation aggregation;

  /// Evaluates an exact set of finite, in-range crisp inputs.
  /// Nonfinite active consequent/reduction results throw StateError.
  SugenoResult evaluate(Map<String, double> values) {
    final crispInputs = Map<String, double>.unmodifiable(values);
    final memberships = fuzzifyInputs(inputs, crispInputs);
    final activations = <SugenoActivation>[];
    final grouped = <String, List<SugenoActivation>>{
      for (final output in outputs) output.name: [],
    };
    for (final rule in rules) {
      final antecedent = rule.when.evaluate(memberships, operators: operators);
      final strength = antecedent * rule.weight;
      final value = strength > 0 ? rule.consequent.evaluate(crispInputs) : null;
      if (value != null && !value.isFinite) {
        throw StateError('Sugeno consequent must return a finite crisp value.');
      }
      final activation = SugenoActivation._(rule, antecedent, strength, value);
      activations.add(activation);
      if (strength > 0) grouped[rule.output]!.add(activation);
    }
    final results = <String, double?>{}, totalWeights = <String, double>{};
    for (final output in outputs) {
      final active = grouped[output.name]!;
      totalWeights[output.name] =
          sumFinite(active.map((a) => a.strength).toList());
      if (active.isEmpty) {
        results[output.name] = null;
      } else if (aggregation == SugenoAggregation.weightedSum) {
        results[output.name] =
            sumFinite(active.map((a) => a.weightedContribution!).toList());
      } else {
        results[output.name] = weightedAverage(
            active.map((a) => a.strength).toList(),
            active.map((a) => a.consequentValue!).toList());
      }
    }
    return SugenoResult._(results, memberships, activations, totalWeights);
  }
}
