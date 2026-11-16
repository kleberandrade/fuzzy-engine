import 'inference_support.dart';
import 'membership.dart';
import 'model.dart';
import 'operators.dart';
import 'weighted_reduction.dart';

/// Bounded output with monotonic, finitely invertible linguistic terms.
final class TsukamotoOutput {
  /// Each transition domain must lie inside the declared finite output universe.
  TsukamotoOutput(
      {required this.name,
      required this.min,
      required this.max,
      required Map<String, MonotonicMembershipFunction> terms})
      : terms = Map.unmodifiable(terms) {
    if (name.trim().isEmpty ||
        !min.isFinite ||
        !max.isFinite ||
        min >= max ||
        !(max - min).isFinite ||
        terms.isEmpty ||
        terms.keys.any((key) => key.trim().isEmpty)) {
      throw ArgumentError('Invalid Tsukamoto output.');
    }
    for (final function in terms.values) {
      if (!function.domainMin.isFinite ||
          !function.domainMax.isFinite ||
          function.domainMin >= function.domainMax ||
          !(function.domainMax - function.domainMin).isFinite ||
          function.domainMin < min ||
          function.domainMax > max) {
        throw ArgumentError(
            'Term transition domain must lie inside its output universe.');
      }
    }
  }

  /// Output name.
  final String name;

  /// Inclusive lower output bound.
  final double min;

  /// Inclusive upper output bound.
  final double max;

  /// Immutable named monotonic functions; custom functions must be immutable.
  final Map<String, MonotonicMembershipFunction> terms;
}

/// One fuzzy antecedent and one named invertible output term.
final class TsukamotoRule {
  /// Weight multiplies the complete antecedent before inversion and reduction.
  TsukamotoRule(
      {required this.name,
      required this.when,
      required this.output,
      required this.term,
      this.weight = 1}) {
    if (name.trim().isEmpty || !weight.isFinite || weight < 0 || weight > 1) {
      throw ArgumentError('Invalid Tsukamoto rule name or weight.');
    }
  }

  /// Unique rule name.
  final String name;

  /// Shared condition tree, including configurable operators and hedges.
  final Condition when;

  /// Declared output name.
  final String output;

  /// Named monotonic term to invert.
  final String term;

  /// Activation multiplier.
  final double weight;
}

/// Immutable rule explanation, retaining weighted activation and inverse value.
final class TsukamotoActivation {
  TsukamotoActivation._(
      this.rule, this.antecedent, this.strength, this.inverseValue);

  /// Evaluated rule.
  final TsukamotoRule rule;

  /// Antecedent before weight.
  final double antecedent;

  /// Antecedent multiplied by rule weight.
  final double strength;

  /// Inverted output coordinate; null for inactive rules.
  final double? inverseValue;

  /// Raw strength times inverse value; may underflow, null for inactive rules.
  double? get weightedContribution =>
      inverseValue == null ? null : strength * inverseValue!;
}

/// Immutable Tsukamoto decisions, input degrees and rule explanations.
final class TsukamotoResult {
  TsukamotoResult._(
      Map<String, double?> outputs,
      Map<String, Map<String, double>> memberships,
      List<TsukamotoActivation> rules,
      Map<String, double> totalWeights)
      : outputs = Map.unmodifiable(outputs),
        memberships = Map.unmodifiable(memberships.map((key, value) =>
            MapEntry(key, Map<String, double>.unmodifiable(value)))),
        rules = List.unmodifiable(rules),
        totalWeights = Map.unmodifiable(totalWeights);

  /// Crisp weighted averages; null for outputs with no positive-strength rule.
  final Map<String, double?> outputs;

  /// Fuzzified input degrees.
  final Map<String, Map<String, double>> memberships;

  /// All rule activations in declaration order.
  final List<TsukamotoActivation> rules;

  /// Sum of weighted strengths per output.
  final Map<String, double> totalWeights;

  /// Reads a declared output, rejecting unknown names.
  double? value(String name) {
    if (!outputs.containsKey(name)) {
      throw ArgumentError('Unknown output: $name');
    }
    return outputs[name];
  }
}

/// Tsukamoto inference: invert each active consequent at its weighted strength,
/// then combine inverse values with a normalized weighted average.
final class TsukamotoEngine {
  /// Construction probes monotonicity and inverse consistency on a finite grid.
  /// Built-in inverses are analytical; probes cannot prove arbitrary custom curves.
  TsukamotoEngine(
      {required List<FuzzyVariable> inputs,
      required List<TsukamotoOutput> outputs,
      required List<TsukamotoRule> rules,
      this.operators = const FuzzyOperators(),
      this.validationSamples = 33,
      this.inverseTolerance = 1e-9})
      : inputs = List.unmodifiable(inputs),
        outputs = List.unmodifiable(outputs),
        rules = List.unmodifiable(rules) {
    if (inputs.isEmpty ||
        outputs.isEmpty ||
        rules.isEmpty ||
        validationSamples < 2 ||
        validationSamples > 1001 ||
        !inverseTolerance.isFinite ||
        inverseTolerance < 0 ||
        inverseTolerance > 1e-3) {
      throw ArgumentError(
          'Invalid Tsukamoto configuration or inverse validation options.');
    }
    final indexedInputs = indexFuzzyVariables(inputs);
    final indexedOutputs = <String, TsukamotoOutput>{};
    for (final output in outputs) {
      if (indexedOutputs.containsKey(output.name)) {
        throw ArgumentError('Duplicate output: ${output.name}');
      }
      indexedOutputs[output.name] = output;
      for (final entry in output.terms.entries) {
        try {
          _validate(entry.value);
        } on StateError {
          throw ArgumentError(
              'Invalid monotonic function/inverse: ${output.name}.${entry.key}');
        }
      }
    }
    final names = <String>{};
    for (final rule in rules) {
      if (!names.add(rule.name)) {
        throw ArgumentError('Duplicate rule: ${rule.name}');
      }
      for (final reference in rule.when.references) {
        if (!(indexedInputs[reference.variable]
                ?.terms
                .containsKey(reference.term) ??
            false)) {
          throw ArgumentError(
              'Unknown input term: ${reference.variable}.${reference.term}');
        }
      }
      if (!(indexedOutputs[rule.output]?.terms.containsKey(rule.term) ??
          false)) {
        throw ArgumentError(
            'Unknown monotonic output term: ${rule.output}.${rule.term}');
      }
    }
    _outputIndex = Map.unmodifiable(indexedOutputs);
  }

  /// Fuzzy input variables.
  final List<FuzzyVariable> inputs;

  /// Bounded monotonic output variables.
  final List<TsukamotoOutput> outputs;

  /// Ordered weighted rules.
  final List<TsukamotoRule> rules;

  /// Antecedent AND/OR/NOT strategies.
  final FuzzyOperators operators;

  /// Number of constructor probes per transition/degree axis, from 2 to 1001.
  final int validationSamples;

  /// Absolute membership-degree inverse error tolerance, from zero to 0.001.
  final double inverseTolerance;
  late final Map<String, TsukamotoOutput> _outputIndex;

  void _validate(MonotonicMembershipFunction function) {
    double? previousDegree, previousInverse;
    for (var i = 0; i < validationSamples; i++) {
      final alpha = i / (validationSamples - 1);
      final x = i == 0
          ? function.domainMin
          : i == validationSamples - 1
              ? function.domainMax
              : function.domainMin +
                  (function.domainMax - function.domainMin) * alpha;
      final degree = checkedDegree(function.degree(x));
      if (previousDegree != null &&
          (function.isIncreasing
              ? degree + inverseTolerance < previousDegree
              : degree - inverseTolerance > previousDegree)) {
        throw StateError('Transition is not monotonic at validation probes.');
      }
      if (i == 0 || i == validationSamples - 1) {
        final expected = function.isIncreasing ? alpha : 1 - alpha;
        if ((degree - expected).abs() > inverseTolerance) {
          throw StateError(
              'Transition endpoints must cover degrees zero and one.');
        }
      }
      final inverse = _inverse(function, alpha);
      if (previousInverse != null &&
          (function.isIncreasing
              ? inverse < previousInverse
              : inverse > previousInverse)) {
        throw StateError('Inverse is not monotonic at validation probes.');
      }
      previousDegree = degree;
      previousInverse = inverse;
    }
  }

  double _inverse(MonotonicMembershipFunction function, double strength) {
    final value = function.inverse(strength);
    if (!value.isFinite ||
        value < function.domainMin ||
        value > function.domainMax ||
        (checkedDegree(function.degree(value)) - strength).abs() >
            inverseTolerance) {
      throw StateError(
          'Inverse must be finite, inside its transition and consistent with its membership degree.');
    }
    return value;
  }

  /// Validates crisp inputs, inverts active terms and returns normalized decisions.
  /// No output integration grid or integral defuzzifier is used.
  TsukamotoResult evaluate(Map<String, double> values) {
    final memberships = fuzzifyInputs(inputs, values);
    final activations = <TsukamotoActivation>[];
    final groups = {
      for (final output in outputs) output.name: <TsukamotoActivation>[]
    };
    for (final rule in rules) {
      final degree = rule.when.evaluate(memberships, operators: operators);
      final strength = degree * rule.weight;
      final inverse = strength > 0
          ? _inverse(_outputIndex[rule.output]!.terms[rule.term]!, strength)
          : null;
      final activation = TsukamotoActivation._(rule, degree, strength, inverse);
      activations.add(activation);
      if (strength > 0) groups[rule.output]!.add(activation);
    }
    final crisp = <String, double?>{}, weights = <String, double>{};
    for (final output in outputs) {
      final active = groups[output.name]!;
      final strengths = active.map((a) => a.strength).toList();
      weights[output.name] = sumFinite(strengths);
      final value = active.isEmpty
          ? null
          : weightedAverage(
              strengths, active.map((a) => a.inverseValue!).toList());
      if (value != null &&
          (!value.isFinite || value < output.min || value > output.max)) {
        throw StateError('Tsukamoto decision is outside the output universe.');
      }
      crisp[output.name] = value;
    }
    return TsukamotoResult._(crisp, memberships, activations, weights);
  }
}
