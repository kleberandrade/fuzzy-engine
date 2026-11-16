import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

void main() {
  final source = File('test/fixtures/fcl/ventilation.fcl').readAsStringSync();
  final importer = FclImporter(
      inputRanges: {'temperature': FclRange(0, 1), 'humidity': FclRange(0, 1)});
  final original = importer.decode(source);
  const exporter = FclExporter();
  String encode(FclModel model) =>
      exporter.encode(model, acknowledgeRuntimeSettings: true);
  FclModel build(
          {Condition? condition,
          MembershipFunction? function,
          String name = 'ventilation',
          String ruleName = '1',
          TNorm? and,
          SNorm? or,
          FuzzyNegation? not,
          TNorm? implication,
          SNorm? aggregation,
          Defuzzifier? defuzzifier}) =>
      FclModel.fromEngine(
          name: name,
          ruleBlockName: 'rules',
          defaultValue: -3,
          engine: FuzzyEngine(
              inputs: [
                FuzzyVariable(name: 'temperature', min: 0, max: 1, terms: {
                  'low': function ??
                      DiscreteSet(
                          [MembershipPoint(0, 1), MembershipPoint(1, 0)])
                }),
                original.engine.inputs[1]
              ],
              outputs: original.engine.outputs,
              rules: [
                FuzzyRule(
                    name: ruleName,
                    when: condition ?? const Term('temperature', 'low'),
                    output: 'fan',
                    term: 'low')
              ],
              operators: FuzzyOperators(
                  conjunction: and ?? const Minimum(),
                  disjunction: or ?? const Maximum(),
                  negation: not ?? const StandardNegation()),
              implication: implication ?? const Minimum(),
              aggregation: aggregation ?? const Maximum(),
              defuzzifier: defuzzifier ?? const Centroid()));

  test('exports canonical declarations, rules, weights, range and DEFAULT', () {
    final text = encode(original);
    expect(text, contains('DEFAULT := -1.0;'));
    expect(text, contains('RANGE := (0.0 .. 10.0);'));
    expect(
        text,
        contains(
            'RULE 2 : IF temperature IS NOT low OR humidity IS high THEN fan IS high WITH 0.4;'));
    final copy = importer.decode(text);
    expect(copy.name, original.name);
    expect(copy.ruleBlockName, original.ruleBlockName);
    for (final t in [0.0, .5, 1.0]) {
      for (final h in [0.0, .75, 1.0]) {
        final values = {'temperature': t, 'humidity': h};
        expect(copy.evaluate(values).value,
            closeTo(original.evaluate(values).value, 1e-12));
        expect(copy.evaluate(values).trace.memberships,
            original.evaluate(values).trace.memberships);
      }
    }
  });
  test('preserves numeric DEFAULT outside RANGE and inactive null explanation',
      () {
    final inactive = importer.decode(source
        .replaceAll('WITH 0.8', 'WITH 0')
        .replaceAll('WITH 0.4', 'WITH 0'));
    final result = importer
        .decode(encode(inactive))
        .evaluate({'temperature': 0, 'humidity': 0});
    expect(result.value, -1);
    expect(result.usedDefault, true);
    expect(result.trace.value('fan'), isNull);
  });
  test('normalizes imported tails and preserves maximum original point budget',
      () {
    final points =
        [for (var i = 1; i <= 4096; i++) '(${i / 4097},0.5)'].join(' ');
    final model = importer.decode(source.replaceFirst('(0,1) (1,0)', points));
    expect(
        (model.engine.inputs.first.terms['low']! as DiscreteSet).points.length,
        4098);
    final copy = importer.decode(encode(model));
    for (final x in [0.0, .5, 1.0]) {
      expect(copy.engine.inputs.first.terms['low']!.degree(x), .5);
    }
  });
  test(
      'zero support tails map exactly while nonzero interior jumps are rejected',
      () {
    final zero = build(
        function: DiscreteSet([
      MembershipPoint(.2, 0),
      MembershipPoint(.5, 1),
      MembershipPoint(.8, 0)
    ]));
    final copy = importer.decode(encode(zero));
    expect(copy.engine.inputs.first.terms['low']!.degree(0), 0);
    expect(
        () => encode(build(
            function:
                DiscreteSet([MembershipPoint(.2, 1), MembershipPoint(.8, 0)]))),
        throwsUnsupportedError);
    expect(
        () => encode(build(
            function:
                DiscreteSet([MembershipPoint(0, 0), MembershipPoint(.8, 1)]))),
        throwsUnsupportedError);
  });
  final invalid = <String, FclModel>{
    'nonlinear function': build(function: Gaussian(.5, .2)),
    'mixed operators': build(
        condition: const Term('temperature', 'low').and(
            const Term('humidity', 'low').or(const Term('humidity', 'high')))),
    'negated group': build(
        condition: const Term('temperature', 'low')
            .and(const Term('humidity', 'low'))
            .not()),
    'hedge':
        build(condition: const Term('temperature', 'low').hedge(const Very())),
    'AND': build(and: const AlgebraicProduct()),
    'OR': build(or: const ProbabilisticSum()),
    'implication': build(implication: const AlgebraicProduct()),
    'aggregation': build(aggregation: const ProbabilisticSum()),
    'defuzzifier': build(defuzzifier: const Bisector()),
    'arbitrary rule name': build(ruleName: 'namedRule'),
    'padded rule id': build(ruleName: '01'),
    'reserved identifier': build(name: 'IF'),
    'external reserved identifier': build(name: 'sin'),
    'leading underscore identifier': build(name: '_private'),
    'custom complement': build(not: _CustomComplement()),
    'injected identifier': build(name: 'bad;name'),
  };
  for (final entry in invalid.entries) {
    test('rejects ${entry.key}',
        () => expect(() => encode(entry.value), throwsUnsupportedError));
  }
  test('requires explicit runtime acknowledgement, finite DEFAULT and budgets',
      () {
    expect(() => exporter.encode(original, acknowledgeRuntimeSettings: false),
        throwsArgumentError);
    expect(
        () => const FclExporter(maxSourceLength: 20)
            .encode(original, acknowledgeRuntimeSettings: true),
        throwsUnsupportedError);
    expect(
        () => const FclExporter(maxDepth: 0)
            .encode(original, acknowledgeRuntimeSettings: true),
        throwsArgumentError);
    expect(
        () => FclModel.fromEngine(
            name: 'test',
            ruleBlockName: 'rules',
            engine: original.engine,
            defaultValue: double.nan),
        throwsArgumentError);
    final deep = build(
        condition: const Term('temperature', 'low')
            .and(const Term('humidity', 'low'))
            .and(const Term('humidity', 'high')));
    expect(
        () => const FclExporter(maxDepth: 1)
            .encode(deep, acknowledgeRuntimeSettings: true),
        throwsUnsupportedError);
  });
}

final class _CustomComplement implements FuzzyNegation {
  @override
  double complement(double value) => 1 - value;
}
