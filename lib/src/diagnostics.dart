import 'dart:convert';
import 'dart:math' as math;
import 'engine.dart';
import 'model.dart';
import 'model_codec.dart';
import 'operators.dart';
import 'sugeno.dart';
import 'tsukamoto.dart';

/// Diagnostic severity; a finding is not an automatic model modification.
enum DiagnosticSeverity { info, warning, error }

/// Stable machine-readable diagnostic categories.
enum DiagnosticCode {
  inputCoverageGap,
  inputMembershipFailure,
  zeroWeightRule,
  ruleNotObserved,
  outputWithoutDecision,
  duplicateRules,
  competingConsequents,
  structuralAnalysisSkipped,
  evaluationFailure,
}

/// Immutable explanatory finding; messages contain no raw callback exceptions.
final class DiagnosticIssue {
  DiagnosticIssue._(this.code, this.severity, this.message,
      {this.subject, List<String> rules = const []})
      : rules = List.unmodifiable(rules);

  /// Stable category, usable for localization/filtering.
  final DiagnosticCode code;

  /// Informational, warning or error severity.
  final DiagnosticSeverity severity;

  /// Human-readable explanation.
  final String message;

  /// Input/output variable name, when applicable.
  final String? subject;

  /// Related rule names.
  final List<String> rules;

  /// Fresh JSON-compatible representation.
  Map<String, Object?> toJson() => {
        'code': code.name,
        'severity': severity.name,
        'message': message,
        'subject': subject,
        'rules': rules.toList()
      };
}

/// Immutable observations on a finite Cartesian grid, not a coverage proof.
final class FuzzyDiagnosticReport {
  FuzzyDiagnosticReport._(
      {required this.evaluations,
      required this.failedEvaluations,
      required this.uncoveredEvaluations,
      required this.activationThreshold,
      required Map<String, List<double>> inputSamples,
      required Map<String, List<double>> inputCoverageGaps,
      required Map<String, int> inputMembershipFailures,
      required Map<String, int> ruleActivationCounts,
      required Map<String, double> maxRuleStrengths,
      required Map<String, int> nullOutputCounts,
      required List<Map<String, double>> failureExamples,
      required List<DiagnosticIssue> issues})
      : inputSamples = Map.unmodifiable(inputSamples
            .map((k, v) => MapEntry(k, List<double>.unmodifiable(v)))),
        inputCoverageGaps = Map.unmodifiable(inputCoverageGaps
            .map((k, v) => MapEntry(k, List<double>.unmodifiable(v)))),
        inputMembershipFailures = Map.unmodifiable(inputMembershipFailures),
        ruleActivationCounts = Map.unmodifiable(ruleActivationCounts),
        maxRuleStrengths = Map.unmodifiable(maxRuleStrengths),
        nullOutputCounts = Map.unmodifiable(nullOutputCounts),
        failureExamples = List.unmodifiable(
            failureExamples.map((v) => Map<String, double>.unmodifiable(v))),
        issues = List.unmodifiable(issues);

  /// Total attempted grid evaluations, including failures.
  final int evaluations;

  /// Failed evaluations; output/rule counters exclude these.
  final int failedEvaluations;

  /// Successful evaluations with no rule above activationThreshold.
  final int uncoveredEvaluations;

  /// Strict activation cutoff; degrees equal to the cutoff count as inactive.
  final double activationThreshold;

  /// Reproducible grid coordinates for each input, including endpoints.
  final Map<String, List<double>> inputSamples;

  /// Sampled input coordinates where no term exceeds the threshold.
  final Map<String, List<double>> inputCoverageGaps;

  /// Per-input membership scan failures.
  final Map<String, int> inputMembershipFailures;

  /// Per-rule observed activations above the threshold, on successful evaluations.
  final Map<String, int> ruleActivationCounts;

  /// Maximum observed weighted strengths, on successful evaluations.
  final Map<String, double> maxRuleStrengths;

  /// Null output decisions on successful evaluations only.
  final Map<String, int> nullOutputCounts;

  /// A bounded collection of failed input combinations; no stack traces/secrets.
  final List<Map<String, double>> failureExamples;

  /// Findings; no rule is removed and no model parameter is changed.
  final List<DiagnosticIssue> issues;

  /// Number of successful evaluations.
  int get successfulEvaluations => evaluations - failedEvaluations;

  /// Whether membership or inference failures were observed.
  bool get hasErrors =>
      issues.any((issue) => issue.severity == DiagnosticSeverity.error);

  /// Fresh JSON-compatible report. Input values may contain application data.
  Map<String, Object?> toJson() => {
        'evaluations': evaluations,
        'failedEvaluations': failedEvaluations,
        'uncoveredEvaluations': uncoveredEvaluations,
        'activationThreshold': activationThreshold,
        'inputSamples': inputSamples.map((k, v) => MapEntry(k, v.toList())),
        'inputCoverageGaps':
            inputCoverageGaps.map((k, v) => MapEntry(k, v.toList())),
        'inputMembershipFailures': Map<String, int>.of(inputMembershipFailures),
        'ruleActivationCounts': Map<String, int>.of(ruleActivationCounts),
        'maxRuleStrengths': Map<String, double>.of(maxRuleStrengths),
        'nullOutputCounts': Map<String, int>.of(nullOutputCounts),
        'failureExamples':
            failureExamples.map((v) => Map<String, double>.of(v)).toList(),
        'issues': issues.map((v) => v.toJson()).toList()
      };
}

/// Bounded grid inspection and conservative structural checks for supported engines.
final class FuzzyDiagnostics {
  /// Creates a stateless diagnostic runner. Calling analyze executes the model.
  const FuzzyDiagnostics();

  /// The full Cartesian grid must fit maxEvaluations; it is never truncated.
  /// Custom callbacks execute locally. Findings cannot prove continuous coverage,
  /// semantic contradiction, dimensional consistency or safety of a controller.
  FuzzyDiagnosticReport analyze(Object model,
      {int samplesPerInput = 11,
      int maxEvaluations = 10000,
      double activationThreshold = 0,
      int maxFailureExamples = 3}) {
    if (samplesPerInput < 2 ||
        maxEvaluations < 1 ||
        maxFailureExamples < 0 ||
        !activationThreshold.isFinite ||
        activationThreshold < 0 ||
        activationThreshold >= 1) {
      throw ArgumentError('Invalid diagnostic sampling options.');
    }
    final engine = model is FuzzyModelDocument ? model.engine : model;
    final List<FuzzyVariable> inputs;
    final List<String> outputNames;
    final List<_RuleShape> rules;
    final issues = <DiagnosticIssue>[];
    if (engine is FuzzyEngine) {
      inputs = engine.inputs;
      outputNames = engine.outputs.map((o) => o.name).toList();
      rules = [
        for (final r in engine.rules)
          _RuleShape(r.name, r.when, r.output, r.weight, {'term': r.term})
      ];
    } else if (engine is SugenoEngine) {
      inputs = engine.inputs;
      outputNames = engine.outputs.map((o) => o.name).toList();
      final codec = FuzzyModelCodec();
      rules = [
        for (final r in engine.rules)
          _RuleShape(r.name, r.when, r.output, r.weight,
              _tryConsequent(codec, r.consequent))
      ];
    } else if (engine is TsukamotoEngine) {
      inputs = engine.inputs;
      outputNames = engine.outputs.map((o) => o.name).toList();
      rules = [
        for (final r in engine.rules)
          _RuleShape(r.name, r.when, r.output, r.weight, {'term': r.term})
      ];
    } else {
      throw ArgumentError('Expected a supported fuzzy model.');
    }
    var evaluations = 1;
    for (var i = 0; i < inputs.length; i++) {
      if (evaluations > maxEvaluations ~/ samplesPerInput) {
        throw ArgumentError('Cartesian grid exceeds maxEvaluations.');
      }
      evaluations *= samplesPerInput;
    }
    final grid = <String, List<double>>{
      for (final input in inputs)
        input.name: [
          for (var i = 0; i < samplesPerInput; i++)
            i == 0
                ? input.min
                : i == samplesPerInput - 1
                    ? input.max
                    : (input.min +
                            (input.max - input.min) *
                                (i / (samplesPerInput - 1)))
                        .clamp(input.min, input.max)
                        .toDouble()
        ],
    };
    final gaps = <String, List<double>>{}, membershipFailures = <String, int>{};
    for (final input in inputs) {
      gaps[input.name] = [];
      membershipFailures[input.name] = 0;
      for (final x in grid[input.name]!) {
        try {
          var covered = false;
          for (final function in input.terms.values) {
            if (checkedDegree(function.degree(x)) > activationThreshold) {
              covered = true;
            }
          }
          if (!covered) gaps[input.name]!.add(x);
        } catch (_) {
          membershipFailures[input.name] = membershipFailures[input.name]! + 1;
        }
      }
      if (gaps[input.name]!.isNotEmpty) {
        issues.add(DiagnosticIssue._(
            DiagnosticCode.inputCoverageGap,
            DiagnosticSeverity.warning,
            'No input term exceeded the threshold at some sampled coordinates.',
            subject: input.name));
      }
      if (membershipFailures[input.name]! > 0) {
        issues.add(DiagnosticIssue._(
            DiagnosticCode.inputMembershipFailure,
            DiagnosticSeverity.error,
            'Input membership evaluation failed at sampled coordinates.',
            subject: input.name));
      }
    }
    final counts = {for (final r in rules) r.name: 0},
        maxima = {for (final r in rules) r.name: 0.0};
    final nullCounts = {for (final name in outputNames) name: 0};
    var failed = 0, uncovered = 0;
    final failures = <Map<String, double>>[];
    void evaluate(Map<String, double> point) {
      try {
        final List<(String, double)> activations;
        final Map<String, double?> outputs;
        if (engine is FuzzyEngine) {
          final result = engine.evaluate(point);
          outputs = result.outputs;
          activations = [
            for (final r in result.rules) (r.rule.name, r.strength)
          ];
        } else if (engine is SugenoEngine) {
          final result = engine.evaluate(point);
          outputs = result.outputs;
          activations = [
            for (final r in result.rules) (r.rule.name, r.strength)
          ];
        } else {
          final result = (engine as TsukamotoEngine).evaluate(point);
          outputs = result.outputs;
          activations = [
            for (final r in result.rules) (r.rule.name, r.strength)
          ];
        }
        var active = false;
        for (final (name, strength) in activations) {
          maxima[name] = math.max(maxima[name]!, strength);
          if (strength > activationThreshold) {
            counts[name] = counts[name]! + 1;
            active = true;
          }
        }
        if (!active) uncovered++;
        for (final entry in outputs.entries) {
          if (entry.value == null) {
            nullCounts[entry.key] = nullCounts[entry.key]! + 1;
          }
        }
      } catch (_) {
        failed++;
        if (failures.length < maxFailureExamples) failures.add(Map.of(point));
      }
    }

    void visit(int depth, Map<String, double> point) {
      if (depth == inputs.length) {
        evaluate(point);
        return;
      }
      final input = inputs[depth];
      for (final x in grid[input.name]!) {
        point[input.name] = x;
        visit(depth + 1, point);
      }
    }

    visit(0, {});
    for (final r in rules) {
      if (r.weight == 0) {
        issues.add(DiagnosticIssue._(
            DiagnosticCode.zeroWeightRule,
            DiagnosticSeverity.info,
            'Rule weight is zero; this rule cannot activate.',
            rules: [r.name]));
      } else if (evaluations > failed && counts[r.name] == 0) {
        issues.add(DiagnosticIssue._(
            DiagnosticCode.ruleNotObserved,
            DiagnosticSeverity.warning,
            'Rule did not exceed the threshold on successful grid evaluations; this is not a proof of inactivity.',
            rules: [r.name]));
      }
    }
    for (final entry in nullCounts.entries) {
      if (entry.value > 0) {
        issues.add(DiagnosticIssue._(
            DiagnosticCode.outputWithoutDecision,
            DiagnosticSeverity.warning,
            'Output was null on some successful sampled evaluations.',
            subject: entry.key));
      }
    }
    if (failed > 0) {
      issues.add(DiagnosticIssue._(
          DiagnosticCode.evaluationFailure,
          DiagnosticSeverity.error,
          'Model evaluation failed on sampled input combinations.'));
    }
    _structural(rules, issues);
    return FuzzyDiagnosticReport._(
        evaluations: evaluations,
        failedEvaluations: failed,
        uncoveredEvaluations: uncovered,
        activationThreshold: activationThreshold,
        inputSamples: grid,
        inputCoverageGaps: gaps,
        inputMembershipFailures: membershipFailures,
        ruleActivationCounts: counts,
        maxRuleStrengths: maxima,
        nullOutputCounts: nullCounts,
        failureExamples: failures,
        issues: issues);
  }
}

final class _RuleShape {
  const _RuleShape(
      this.name, this.when, this.output, this.weight, this.consequent);
  final String name, output;
  final Condition when;
  final double weight;
  final Map<String, Object?>? consequent;
}

Map<String, Object?>? _tryConsequent(
    FuzzyModelCodec codec, SugenoConsequent value) {
  try {
    return codec.consequentToJson(value);
  } on UnsupportedError {
    return null;
  }
}

Object? _canonical(Object? raw) {
  if (raw is Map) {
    final keys = raw.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(raw[key])};
  }
  if (raw is List) return raw.map(_canonical).toList();
  return raw;
}

void _structural(List<_RuleShape> rules, List<DiagnosticIssue> issues) {
  final codec = FuzzyModelCodec();
  final groups = <String, List<_RuleShape>>{};
  for (final r in rules) {
    try {
      if (r.consequent == null) throw UnsupportedError('Custom consequent.');
      final key =
          jsonEncode([_canonical(codec.conditionToJson(r.when)), r.output]);
      groups.putIfAbsent(key, () => []).add(r);
    } on UnsupportedError {
      issues.add(DiagnosticIssue._(
          DiagnosticCode.structuralAnalysisSkipped,
          DiagnosticSeverity.info,
          'Custom components prevent structural comparison; runtime sampling still applies.',
          rules: [r.name]));
    } on FormatException {
      issues.add(DiagnosticIssue._(
          DiagnosticCode.structuralAnalysisSkipped,
          DiagnosticSeverity.info,
          'Condition exceeds structural inspection limits; runtime sampling still applies.',
          rules: [r.name]));
    }
  }
  for (final group in groups.values) {
    final duplicates = <String, List<String>>{}, consequentTypes = <String>{};
    for (final r in group) {
      final target = jsonEncode(_canonical(r.consequent));
      duplicates
          .putIfAbsent(jsonEncode([target, r.weight]), () => [])
          .add(r.name);
      if (r.weight > 0) consequentTypes.add(target);
    }
    for (final names in duplicates.values.where((names) => names.length > 1)) {
      issues.add(DiagnosticIssue._(
          DiagnosticCode.duplicateRules,
          DiagnosticSeverity.info,
          'Rules have the same structural antecedent, output, consequent and weight; duplicates may be intentional.',
          rules: names));
    }
    if (consequentTypes.length > 1) {
      issues.add(DiagnosticIssue._(
          DiagnosticCode.competingConsequents,
          DiagnosticSeverity.warning,
          'The same structural antecedent targets different consequents for one output; this is not proof of contradiction.',
          rules: group.where((r) => r.weight > 0).map((r) => r.name).toList(),
          subject: group.first.output));
    }
  }
}
