import 'operators.dart';
import 'defuzzification.dart';
import 'model.dart';

/// Rule activation before and after applying its weight.
final class RuleActivation {
  /// Creates a diagnostic record.
  const RuleActivation(this.rule, this.antecedent, this.strength);

  /// Evaluated rule.
  final FuzzyRule rule;

  /// Unweighted degree.
  final double antecedent;

  /// Weighted degree passed to the implication strategy.
  final double strength;
}

/// Immutable inference result. Null output means zero aggregated area.
final class FuzzyResult {
  FuzzyResult._(
      Map<String, double?> outputs,
      Map<String, Map<String, double>> memberships,
      List<RuleActivation> rules,
      Map<String, SampledFuzzySet> outputSets)
      : outputs = Map.unmodifiable(outputs),
        memberships = Map.unmodifiable(memberships
            .map((k, v) => MapEntry(k, Map<String, double>.unmodifiable(v)))),
        rules = List.unmodifiable(rules),
        outputSets = Map.unmodifiable(outputSets);

  /// Crisp outputs; absent activation is represented by null, never NaN.
  final Map<String, double?> outputs;

  /// Input degrees for explaining the inference.
  final Map<String, Map<String, double>> memberships;

  /// Aggregated sampled output curves used for defuzzification.
  final Map<String, SampledFuzzySet> outputSets;

  /// Every rule, including inactive ones, in declaration order.
  final List<RuleActivation> rules;

  /// Reads a declared output; throws for unknown names.
  double? value(String name) {
    if (!outputs.containsKey(name))
      throw ArgumentError('Unknown output: $name');
    return outputs[name];
  }
}

/// Configurable type-1 fuzzy inference with Mamdani defaults.
final class FuzzyEngine {
  /// [intervals] controls trapezoidal integration resolution, not sample count.
  FuzzyEngine(
      {required List<FuzzyVariable> inputs,
      required List<FuzzyVariable> outputs,
      required List<FuzzyRule> rules,
      this.intervals = 1000,
      this.operators = const FuzzyOperators(),
      this.implication = const Minimum(),
      this.aggregation = const Maximum(),
      this.defuzzifier = const Centroid()})
      : inputs = List.unmodifiable(inputs),
        outputs = List.unmodifiable(outputs),
        rules = List.unmodifiable(rules) {
    if (inputs.isEmpty || outputs.isEmpty || rules.isEmpty || intervals < 2) {
      throw ArgumentError('Inputs, outputs, rules and >=2 intervals required.');
    }
    final ins = _index(inputs), outs = _index(outputs);
    final names = <String>{};
    for (final rule in rules) {
      if (!names.add(rule.name))
        throw ArgumentError('Duplicate rule: ${rule.name}');
      for (final ref in rule.when.references) {
        if (!(ins[ref.variable]?.terms.containsKey(ref.term) ?? false)) {
          throw ArgumentError(
              'Unknown input term: ${ref.variable}.${ref.term}');
        }
      }
      if (!(outs[rule.output]?.terms.containsKey(rule.term) ?? false)) {
        throw ArgumentError('Unknown output term: ${rule.output}.${rule.term}');
      }
    }
  }

  /// Input configuration.
  final List<FuzzyVariable> inputs;

  /// Output configuration.
  final List<FuzzyVariable> outputs;

  /// Rules in declaration order.
  final List<FuzzyRule> rules;

  /// Antecedent AND, OR and NOT strategies.
  final FuzzyOperators operators;

  /// Combines weighted rule activation with each consequent membership.
  final TNorm implication;

  /// Combines implied consequents at each output sample, starting from zero.
  final SNorm aggregation;

  /// Converts each aggregated sampled output to a crisp value.
  final Defuzzifier defuzzifier;

  /// Number of equally spaced integration intervals.
  final int intervals;

  static Map<String, FuzzyVariable> _index(List<FuzzyVariable> variables) {
    final map = <String, FuzzyVariable>{};
    for (final v in variables) {
      if (map.containsKey(v.name))
        throw ArgumentError('Duplicate variable: ${v.name}');
      map[v.name] = v;
    }
    return map;
  }

  /// Evaluates an exact set of finite inputs inside their declared ranges.
  /// Throws [ArgumentError] on missing, extra or out-of-range inputs.
  FuzzyResult evaluate(Map<String, double> values) {
    if (values.length != inputs.length ||
        values.keys.any((k) => !inputs.any((v) => v.name == k))) {
      throw ArgumentError('Supply exactly the declared inputs.');
    }
    final memberships = <String, Map<String, double>>{};
    for (final v in inputs) {
      final x = values[v.name];
      if (x == null || !x.isFinite || x < v.min || x > v.max) {
        throw ArgumentError('Input ${v.name} must be in [${v.min}, ${v.max}].');
      }
      memberships[v.name] =
          v.terms.map((k, f) => MapEntry(k, checkedDegree(f.degree(x))));
    }
    final activations = rules.map((r) {
      final degree = r.when.evaluate(memberships, operators: operators);
      return RuleActivation(r, degree, degree * r.weight);
    }).toList();
    final crisp = <String, double?>{};
    final outputSets = <String, SampledFuzzySet>{};
    for (final output in outputs) {
      final relevant = activations
          .where((a) => a.rule.output == output.name && a.strength > 0)
          .toList();
      final degrees = <double>[];
      for (var i = 0; i <= intervals; i++) {
        final x = output.min + (output.max - output.min) * (i / intervals);
        double y = 0;
        for (final activation in relevant) {
          final membership =
              checkedDegree(output.terms[activation.rule.term]!.degree(x));
          final implied = checkedDegree(
              implication.combine(activation.strength, membership));
          y = checkedDegree(aggregation.combine(y, implied));
        }
        degrees.add(y);
      }
      final sampled =
          SampledFuzzySet(min: output.min, max: output.max, degrees: degrees);
      outputSets[output.name] = sampled;
      // Zero sampled area always means no decision, independent of strategy.
      final value = sampled.hasArea ? defuzzifier.defuzzify(sampled) : null;
      if (sampled.hasArea &&
          (value == null ||
              !value.isFinite ||
              value < output.min ||
              value > output.max)) {
        throw StateError(
            'Defuzzifier must return a finite value inside the output universe for positive area.');
      }
      crisp[output.name] = value;
    }
    return FuzzyResult._(crisp, memberships, activations, outputSets);
  }
}
