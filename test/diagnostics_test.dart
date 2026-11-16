import 'dart:convert';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

FuzzyEngine complete({MembershipFunction? membership, double weight = 1}) =>
    FuzzyEngine(inputs: [
      FuzzyVariable(
          name: 'x',
          min: 0,
          max: 10,
          terms: {'on': membership ?? Rectangle(0, 10)})
    ], outputs: [
      FuzzyVariable(name: 'y', min: 0, max: 1, terms: {'on': Rectangle(0, 1)})
    ], rules: [
      FuzzyRule(
          name: 'r',
          when: const Term('x', 'on'),
          output: 'y',
          term: 'on',
          weight: weight)
    ], intervals: 10);
void main() {
  test('complete sampled model has full observed coverage', () {
    final r = const FuzzyDiagnostics().analyze(complete(), samplesPerInput: 3);
    expect(r.evaluations, 3);
    expect(r.successfulEvaluations, 3);
    expect(r.failedEvaluations, 0);
    expect(r.inputSamples['x'], [0, 5, 10]);
    expect(r.inputCoverageGaps['x'], isEmpty);
    expect(r.ruleActivationCounts['r'], 3);
    expect(r.maxRuleStrengths['r'], 1);
    expect(r.nullOutputCounts['y'], 0);
    expect(r.uncoveredEvaluations, 0);
    expect(r.issues, isEmpty);
    expect(r.hasErrors, isFalse);
  });
  test(
      'input gaps, unobserved rules and missing output decisions are sampled honestly',
      () {
    final engine = complete(membership: Triangle(1, 2, 3));
    final r = const FuzzyDiagnostics().analyze(engine, samplesPerInput: 3);
    expect(r.inputCoverageGaps['x'], [0, 5, 10]);
    expect(r.ruleActivationCounts['r'], 0);
    expect(r.nullOutputCounts['y'], 3);
    expect(r.uncoveredEvaluations, 3);
    expect(
        r.issues.map((i) => i.code),
        containsAll([
          DiagnosticCode.inputCoverageGap,
          DiagnosticCode.ruleNotObserved,
          DiagnosticCode.outputWithoutDecision
        ]));
    expect(engine.evaluate({'x': 2}).value('y'),
        isNotNull); // Not a continuous inactivity proof.
  });
  test('zero weights are reported separately and threshold is strict', () {
    final zero = const FuzzyDiagnostics()
        .analyze(complete(weight: 0), samplesPerInput: 2);
    expect(
        zero.issues
            .where((i) => i.code == DiagnosticCode.zeroWeightRule)
            .length,
        1);
    expect(zero.issues.any((i) => i.code == DiagnosticCode.ruleNotObserved),
        isFalse);
    final threshold = const FuzzyDiagnostics().analyze(complete(weight: .5),
        samplesPerInput: 2, activationThreshold: .5);
    expect(threshold.ruleActivationCounts['r'], 0);
    expect(threshold.nullOutputCounts['y'],
        0); // A threshold does not alter inference.
  });
  test(
      'Cartesian sampling is deterministic and budget rejection precedes callbacks',
      () {
    final member = CountingMembership();
    final e = FuzzyEngine(inputs: [
      for (final name in ['x', 'z'])
        FuzzyVariable(name: name, min: -1, max: 1, terms: {'on': member})
    ], outputs: complete().outputs, rules: complete().rules, intervals: 2);
    expect(
        () => const FuzzyDiagnostics()
            .analyze(e, samplesPerInput: 3, maxEvaluations: 8),
        throwsArgumentError);
    expect(member.calls, 0);
    final r = const FuzzyDiagnostics()
        .analyze(e, samplesPerInput: 3, maxEvaluations: 9);
    expect(r.evaluations, 9);
    expect(r.ruleActivationCounts['r'], 9);
    expect(r.inputSamples['x'], [-1, 0, 1]);
  });
  test('structural duplicates and competing consequents are distinct findings',
      () {
    final base = complete();
    final e = FuzzyEngine(
        inputs: base.inputs,
        outputs: [
          FuzzyVariable(
              name: 'y',
              min: 0,
              max: 1,
              terms: {'on': Rectangle(0, 1), 'other': Ramp(0, 1)})
        ],
        rules: [
          ...base.rules,
          FuzzyRule(
              name: 'same',
              when: const Term('x', 'on'),
              output: 'y',
              term: 'on'),
          FuzzyRule(
              name: 'competing',
              when: const Term('x', 'on'),
              output: 'y',
              term: 'other'),
        ],
        intervals: 2);
    final r = const FuzzyDiagnostics().analyze(e, samplesPerInput: 2);
    expect(
        r.issues
            .singleWhere((i) => i.code == DiagnosticCode.duplicateRules)
            .rules,
        ['r', 'same']);
    expect(
        r.issues
            .singleWhere((i) => i.code == DiagnosticCode.competingConsequents)
            .rules,
        ['r', 'same', 'competing']);
    expect(e.rules.length, 3);
  });
  test('Sugeno coefficient key order is canonical for structural comparison',
      () {
    final e = SugenoEngine(inputs: [
      for (final name in ['x', 'z'])
        FuzzyVariable(
            name: name, min: 0, max: 1, terms: {'on': Rectangle(0, 1)})
    ], outputs: [
      SugenoOutput('y'),
      SugenoOutput('unused')
    ], rules: [
      SugenoRule(
          name: 'a',
          when: const Term('x', 'on'),
          output: 'y',
          consequent: LinearConsequent(coefficients: {'x': 1, 'z': 2})),
      SugenoRule(
          name: 'b',
          when: const Term('x', 'on'),
          output: 'y',
          consequent: LinearConsequent(coefficients: {'z': 2, 'x': 1})),
    ]);
    final r = const FuzzyDiagnostics().analyze(
        FuzzyModelDocument(engine: e, inputUnits: {'x': 'm'}),
        samplesPerInput: 2);
    expect(
        r.issues.any((i) => i.code == DiagnosticCode.duplicateRules), isTrue);
    expect(r.issues.any((i) => i.code == DiagnosticCode.competingConsequents),
        isFalse);
    expect(r.nullOutputCounts['unused'], 4);
  });
  test(
      'custom runtime callbacks still work when structural analysis is skipped',
      () {
    final e = SugenoEngine(inputs: complete().inputs, outputs: [
      SugenoOutput('y')
    ], rules: [
      SugenoRule(
          name: 'custom',
          when: const Term('x', 'on'),
          output: 'y',
          consequent: CustomConsequent()),
    ]);
    final r = const FuzzyDiagnostics().analyze(e, samplesPerInput: 2);
    expect(r.ruleActivationCounts['custom'], 2);
    expect(r.failedEvaluations, 0);
    expect(r.issues.single.code, DiagnosticCode.structuralAnalysisSkipped);
  });
  test('numeric evaluation failures are counted and example inputs bounded',
      () {
    final e = SugenoEngine(
        inputs: complete().inputs,
        outputs: [SugenoOutput('y')],
        aggregation: SugenoAggregation.weightedSum,
        rules: [
          for (var i = 0; i < 2; i++)
            SugenoRule(
                name: 'r$i',
                when: const Term('x', 'on'),
                output: 'y',
                consequent: ConstantConsequent(double.maxFinite))
        ]);
    final r = const FuzzyDiagnostics()
        .analyze(e, samplesPerInput: 5, maxFailureExamples: 2);
    expect(r.failedEvaluations, 5);
    expect(r.successfulEvaluations, 0);
    expect(r.hasErrors, isTrue);
    expect(r.failureExamples.length, 2);
    expect(
        const FuzzyDiagnostics()
            .analyze(e, samplesPerInput: 2, maxFailureExamples: 0)
            .failureExamples,
        isEmpty);
    expect(r.nullOutputCounts['y'], 0);
    expect(
        r.issues.any((i) => i.code == DiagnosticCode.ruleNotObserved), isFalse);
    expect(r.issues.any((i) => i.code == DiagnosticCode.evaluationFailure),
        isTrue);
  });
  test(
      'invalid custom membership failures are not mislabeled as uncovered coordinates',
      () {
    final r = const FuzzyDiagnostics()
        .analyze(complete(membership: InvalidMembership()), samplesPerInput: 2);
    expect(r.inputMembershipFailures['x'], 2);
    expect(r.inputCoverageGaps['x'], isEmpty);
    expect(r.failedEvaluations, 2);
    expect(r.hasErrors, isTrue);
  });
  test('reports are deeply immutable, serializable and reproducible', () {
    final runner = const FuzzyDiagnostics();
    final model = complete();
    final first = runner.analyze(model, samplesPerInput: 2);
    expect(first.toJson(), runner.analyze(model, samplesPerInput: 2).toJson());
    expect(jsonDecode(jsonEncode(first.toJson()))['evaluations'], 2);
    expect(() => first.inputSamples['x']!.clear(), throwsUnsupportedError);
    expect(() => first.inputCoverageGaps.clear(), throwsUnsupportedError);
    expect(() => first.ruleActivationCounts.clear(), throwsUnsupportedError);
    expect(() => first.maxRuleStrengths.clear(), throwsUnsupportedError);
    expect(() => first.issues.clear(), throwsUnsupportedError);
  });
  test('invalid diagnostic arguments fail before sampling', () {
    expect(
        () => const FuzzyDiagnostics().analyze(Object()), throwsArgumentError);
    expect(
        () => const FuzzyDiagnostics().analyze(complete(), samplesPerInput: 1),
        throwsArgumentError);
    expect(
        () => const FuzzyDiagnostics().analyze(complete(), maxEvaluations: 0),
        throwsArgumentError);
    for (final threshold in [-.1, 1.0, double.nan])
      expect(
          () => const FuzzyDiagnostics()
              .analyze(complete(), activationThreshold: threshold),
          throwsArgumentError);
  });
}

class CountingMembership implements MembershipFunction {
  int calls = 0;
  @override
  double degree(double x) {
    calls++;
    return 1;
  }
}

class InvalidMembership implements MembershipFunction {
  @override
  double degree(double x) => double.nan;
}

class CustomConsequent implements SugenoConsequent {
  @override
  Iterable<String> get references => const [];
  @override
  double evaluate(Map<String, double> inputs) => 10;
}
