import 'dart:convert';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// View data only: all inference remains in the pure Dart package.
class LabRule {
  const LabRule(this.name, this.strength, this.detail);
  final String name, detail;
  final double strength;
}

class LabResult {
  const LabResult(this.outputs, this.rules, this.sets, {this.error});
  final String? error;
  final Map<String, double?> outputs;
  final List<LabRule> rules;
  final Map<String, SampledFuzzySet> sets;
}

class LabModel {
  LabModel(this.document);
  final FuzzyModelDocument document;
  static final codec = FuzzyModelCodec(
    maxSourceLength: 100000,
    maxNodes: 2000,
    maxOutputSamples: 10000,
  );
  static const methods = [
    'Centroid',
    'Bisector',
    'Mean of maximum',
    'Smallest of maximum',
    'Largest of maximum',
  ];
  String get family => switch (document.engine) {
        FuzzyEngine() => 'Mamdani',
        SugenoEngine() => 'Sugeno',
        TsukamotoEngine() => 'Tsukamoto',
        _ => throw StateError('Unsupported engine'),
      };
  List<FuzzyVariable> get inputs => switch (document.engine) {
        FuzzyEngine e => e.inputs,
        SugenoEngine e => e.inputs,
        TsukamotoEngine e => e.inputs,
        _ => throw StateError('Unsupported engine'),
      };
  Map<String, double> get initialValues => {
        for (final v in inputs) v.name: v.min + (v.max - v.min) / 2,
      };
  String export() =>
      const JsonEncoder.withIndent('  ').convert(codec.toJson(document));
  static LabModel import(String source) {
    final document = codec.decode(source);
    final json = codec.toJson(document);
    _checkBudget(json);
    return LabModel(document);
  }

  static LabModel importJson(Map<String, Object?> json) =>
      import(jsonEncode(json));
  static void _checkBudget(Map<String, Object?> json) {
    final inputs = json['inputs'] as List;
    final outputs = json['outputs'] as List;
    final rules = json['rules'] as List;
    final settings = json['settings'] as Map;
    final intervals = settings['intervals'] as int? ?? 1;
    if (inputs.length > 8 ||
        outputs.length > 8 ||
        rules.length > 64 ||
        rules.length * (intervals + 1) * outputs.length > 250000) {
      throw const FormatException(
        'Lab limit: 8 inputs, 8 outputs, 64 rules, 250000 evaluation samples.',
      );
    }
  }

  LabModel withDefuzzifier(String name) {
    final e = document.engine;
    if (e is! FuzzyEngine) return this;
    final defuzzifier = switch (name) {
      'Centroid' => const Centroid(),
      'Bisector' => const Bisector(),
      'Mean of maximum' => MeanOfMaximum(),
      'Smallest of maximum' => SmallestOfMaximum(),
      'Largest of maximum' => LargestOfMaximum(),
      _ => throw ArgumentError.value(name),
    };
    return LabModel(
      FuzzyModelDocument(
        name: document.name,
        description: document.description,
        inputUnits: document.inputUnits,
        outputUnits: document.outputUnits,
        engine: FuzzyEngine(
          inputs: e.inputs,
          outputs: e.outputs,
          rules: e.rules,
          intervals: e.intervals,
          operators: e.operators,
          implication: e.implication,
          aggregation: e.aggregation,
          defuzzifier: defuzzifier,
        ),
      ),
    );
  }

  String get reduction => switch (document.engine) {
        FuzzyEngine e => switch (e.defuzzifier) {
            Centroid() => 'Centroid',
            Bisector() => 'Bisector',
            MeanOfMaximum() => 'Mean of maximum',
            SmallestOfMaximum() => 'Smallest of maximum',
            LargestOfMaximum() => 'Largest of maximum',
            _ => 'Custom',
          },
        SugenoEngine e => e.aggregation.name,
        _ => 'Weighted inverse average',
      };
  LabResult evaluate(Map<String, double> values) {
    final e = document.engine;
    if (e is FuzzyEngine) {
      final r = e.evaluate(values);
      return LabResult(
          r.outputs,
          [
            for (final a in r.rules)
              LabRule(
                  a.rule.name, a.strength, '${a.rule.output} → ${a.rule.term}'),
          ],
          r.outputSets);
    }
    if (e is SugenoEngine) {
      final r = e.evaluate(values);
      return LabResult(r.outputs, [
        for (final a in r.rules)
          LabRule(
            a.rule.name,
            a.strength,
            '${a.rule.output}: z=${a.consequentValue?.toStringAsFixed(2) ?? "—"}, w×z=${a.weightedContribution?.toStringAsFixed(2) ?? "—"}',
          ),
      ], const {});
    }
    if (e is TsukamotoEngine) {
      final r = e.evaluate(values);
      return LabResult(r.outputs, [
        for (final a in r.rules)
          LabRule(
            a.rule.name,
            a.strength,
            '${a.rule.output} → ${a.rule.term}: inverse=${a.inverseValue?.toStringAsFixed(2) ?? "—"}',
          ),
      ], const {});
    }
    throw StateError('Unsupported engine');
  }
}

/// Same antecedents, distinct output definitions; these are not equivalent models.
List<LabModel> comparisonModels() {
  final inputs = [
    FuzzyVariable(
      name: 'demand',
      min: 0,
      max: 100,
      terms: {'low': Ramp(100, 0), 'high': Ramp(0, 100)},
    ),
  ];
  final mamdani = FuzzyEngine(
    inputs: inputs,
    intervals: 200,
    outputs: [
      FuzzyVariable(
        name: 'power',
        min: 0,
        max: 100,
        terms: {'low': Triangle(0, 0, 50), 'high': Triangle(50, 100, 100)},
      ),
    ],
    rules: [
      for (final term in ['low', 'high'])
        FuzzyRule(
          name: '$term demand → $term power',
          when: Term('demand', term),
          output: 'power',
          term: term,
        ),
    ],
  );
  final sugeno = SugenoEngine(
    inputs: inputs,
    outputs: [SugenoOutput('power')],
    rules: [
      for (final term in ['low', 'high'])
        SugenoRule(
          name: '$term demand → ${term == 'low' ? 20 : 80}',
          when: Term('demand', term),
          output: 'power',
          consequent: ConstantConsequent(term == 'low' ? 20 : 80),
        ),
    ],
  );
  final tsukamoto = TsukamotoEngine(
    inputs: inputs,
    outputs: [
      TsukamotoOutput(
        name: 'power',
        min: 0,
        max: 100,
        terms: {'low': Ramp(100, 0), 'high': Ramp(0, 100)},
      ),
    ],
    rules: [
      for (final term in ['low', 'high'])
        TsukamotoRule(
          name: '$term demand → $term ramp',
          when: Term('demand', term),
          output: 'power',
          term: term,
        ),
    ],
  );
  return [
    for (final engine in [mamdani, sugeno, tsukamoto])
      LabModel(
        FuzzyModelDocument(
          engine: engine,
          name: 'Demand comparison',
          inputUnits: {'demand': '%'},
          outputUnits: {'power': '%'},
        ),
      ),
  ];
}
