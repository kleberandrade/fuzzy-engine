import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

TsukamotoEngine model(
        {double weight = 1, MonotonicMembershipFunction? rising}) =>
    TsukamotoEngine(inputs: [
      FuzzyVariable(
          name: 'x',
          min: 0,
          max: 1,
          terms: {'low': Ramp(1, 0), 'high': Ramp(0, 1)})
    ], outputs: [
      TsukamotoOutput(
          name: 'y',
          min: 0,
          max: 100,
          terms: {'low': Ramp(100, 0), 'high': rising ?? Ramp(0, 100)})
    ], rules: [
      TsukamotoRule(
          name: 'low', when: const Term('x', 'low'), output: 'y', term: 'low'),
      TsukamotoRule(
          name: 'high',
          when: const Term('x', 'high'),
          output: 'y',
          term: 'high',
          weight: weight),
    ]);
TsukamotoEngine one(MonotonicMembershipFunction f,
        {Condition? condition,
        FuzzyOperators operators = const FuzzyOperators()}) =>
    TsukamotoEngine(
        inputs: [
          FuzzyVariable(name: 'x', min: 0, max: 1, terms: {'on': Ramp(0, 1)})
        ],
        outputs: [
          TsukamotoOutput(
              name: 'y', min: f.domainMin, max: f.domainMax, terms: {'on': f})
        ],
        operators: operators,
        rules: [
          TsukamotoRule(
              name: 'r',
              when: condition ?? const Term('x', 'on'),
              output: 'y',
              term: 'on')
        ]);
void main() {
  test(
      'independent v2 reference fixture agrees with weighted inverse arithmetic',
      () {
    final source = File('test/fixtures/tsukamoto-v2.json').readAsStringSync();
    expect(
        FuzzyModelCodec()
            .decodeTsukamoto(source)
            .evaluate({'x': .25}).value('y'),
        closeTo(325 / 14, 1e-12));
  });
  final functions = <String, MonotonicMembershipFunction>{
    'rising ramp': Ramp(2, 8),
    'falling ramp': Ramp(8, 2),
    'S shape': SShape(2, 8),
    'Z shape': ZShape(2, 8),
  };
  for (final entry in functions.entries) {
    test('${entry.key} analytical inverse is finite, monotonic and consistent',
        () {
      final f = entry.value;
      expect(f.domainMin, 2);
      expect(f.domainMax, 8);
      double? previous;
      for (var i = 0; i <= 1000; i++) {
        final alpha = i / 1000, value = f.inverse(i / 1000);
        expect(value, inInclusiveRange(2, 8));
        expect(f.degree(value), closeTo(alpha, 1e-12));
        if (previous != null) {
          expect(
              f.isIncreasing ? value >= previous : value <= previous, isTrue);
        }
        previous = value;
      }
      expect(f.inverse(0), f.isIncreasing ? 2 : 8);
      expect(f.inverse(1), f.isIncreasing ? 8 : 2);
      for (final bad in [-.1, 1.1, double.nan, double.infinity]) {
        expect(() => f.inverse(bad), throwsArgumentError);
      }
    });
  }
  test('smooth inverses match independently derived quadratic roots', () {
    expect(SShape(0, 100).inverse(.25), closeTo(100 * math.sqrt(.125), 1e-12));
    expect(SShape(0, 100).inverse(.75),
        closeTo(100 * (1 - math.sqrt(.125)), 1e-12));
    expect(ZShape(0, 100).inverse(.25),
        closeTo(100 * (1 - math.sqrt(.125)), 1e-12));
  });
  test('unweighted paired ramps produce a hand-derived linear control surface',
      () {
    for (var i = 0; i <= 100; i++) {
      final x = i / 100;
      expect(model().evaluate({'x': x}).value('y'), closeTo(100 * x, 1e-10));
    }
  });
  test(
      'rule weight applies before inversion and also during weighted averaging',
      () {
    final r = model(weight: .5).evaluate({'x': .25});
    expect(r.rules.map((a) => a.strength), [.75, .125]);
    expect(r.rules.map((a) => a.inverseValue), [25, 12.5]);
    expect(r.rules.map((a) => a.weightedContribution), [18.75, 1.5625]);
    expect(r.totalWeights['y'], .875);
    expect(r.value('y'), closeTo(325 / 14, 1e-12));
  });
  test('single smooth consequent uses inversion, not integral defuzzification',
      () {
    expect(one(SShape(0, 100)).evaluate({'x': .25}).value('y'),
        closeTo(100 * math.sqrt(.125), 1e-12));
    expect(one(ZShape(0, 100)).evaluate({'x': .25}).value('y'),
        closeTo(100 * (1 - math.sqrt(.125)), 1e-12));
  });
  test('no positive rule returns null and inactive inverse values stay null',
      () {
    final r = model(weight: 0).evaluate({'x': 1});
    expect(r.value('y'), isNull);
    expect(r.totalWeights['y'], 0);
    expect(
        r.rules.every(
            (a) => a.inverseValue == null && a.weightedContribution == null),
        isTrue);
    expect(model().evaluate({'x': 0}).value('y'), 0);
  });
  test('hedges and selected operators are shared by Tsukamoto antecedents', () {
    final condition =
        const Term('x', 'on').and(const Term('x', 'on')).hedge(const Very());
    final r = one(Ramp(0, 100),
            condition: condition,
            operators: const FuzzyOperators(conjunction: AlgebraicProduct()))
        .evaluate({'x': .5});
    expect(r.rules.single.strength, .0625);
    expect(r.value('y'), 6.25);
  });
  test('multiple outputs reduce separately and unused outputs stay null', () {
    final base = model();
    final e = TsukamotoEngine(
        inputs: base.inputs,
        outputs: [
          ...base.outputs,
          TsukamotoOutput(
              name: 'unused', min: 0, max: 10, terms: {'on': Ramp(0, 10)})
        ],
        rules: base.rules);
    expect(e.evaluate({'x': .3}).outputs['unused'], isNull);
    expect(e.evaluate({'x': .3}).totalWeights['unused'], 0);
  });
  test('output transition may occupy a bounded subset of the output universe',
      () {
    final base = model();
    final e = TsukamotoEngine(
        inputs: base.inputs,
        outputs: [
          TsukamotoOutput(
              name: 'y',
              min: -10,
              max: 100,
              terms: {'low': Ramp(80, 20), 'high': Ramp(20, 80)})
        ],
        rules: base.rules);
    expect(e.evaluate({'x': 0}).value('y'), 20);
    expect(e.evaluate({'x': 1}).value('y'), 80);
  });
  test('incorrect inverse/domain/direction and endpoints are rejected', () {
    for (final f in [
      CustomMonotonic(inverseFn: (a) => double.nan),
      CustomMonotonic(inverseFn: (a) => 2),
      CustomMonotonic(inverseFn: (a) => 1 - a),
      CustomMonotonic(forward: (x) => .1 + .8 * x),
      CustomMonotonic(increasing: false),
    ]) {
      expect(() => one(f), throwsArgumentError);
    }
    expect(
        () => TsukamotoOutput(
            name: 'y', min: 0, max: 1, terms: {'on': Ramp(-1, 2)}),
        throwsArgumentError);
    expect(
        () => TsukamotoOutput(
            name: ' ', min: 0, max: 1, terms: {'on': Ramp(0, 1)}),
        throwsArgumentError);
  });
  test(
      'runtime inversion catches an error deliberately missed by constructor probes',
      () {
    final f = CustomMonotonic(inverseFn: (a) => a == .1 ? .9 : a);
    final e = one(f);
    expect(() => e.evaluate({'x': .1}), throwsStateError);
    final report = const FuzzyDiagnostics().analyze(e, samplesPerInput: 11);
    expect(report.failedEvaluations, 1);
    expect(report.hasErrors, isTrue);
  });
  test('input/model errors follow the shared contract', () {
    final e = model();
    for (final inputs in <Map<String, double>>[
      {},
      {'typo': .5},
      {'x': -.1},
      {'x': 1.1},
      {'x': double.nan}
    ]) {
      expect(() => e.evaluate(inputs), throwsArgumentError);
    }
    expect(() => e.evaluate({'x': .5}).value('unknown'), throwsArgumentError);
    expect(
        () => TsukamotoEngine(
            inputs: e.inputs,
            outputs: e.outputs,
            rules: [...e.rules, ...e.rules]),
        throwsArgumentError);
    expect(
        () => TsukamotoEngine(
            inputs: [...e.inputs, ...e.inputs],
            outputs: e.outputs,
            rules: e.rules),
        throwsArgumentError);
    expect(
        () => TsukamotoEngine(
            inputs: e.inputs,
            outputs: [...e.outputs, ...e.outputs],
            rules: e.rules),
        throwsArgumentError);
    expect(
        () => TsukamotoEngine(inputs: e.inputs, outputs: e.outputs, rules: []),
        throwsArgumentError);
    expect(
        () => TsukamotoEngine(inputs: e.inputs, outputs: e.outputs, rules: [
              TsukamotoRule(
                  name: 'bad',
                  when: const Term('x', 'missing'),
                  output: 'y',
                  term: 'high')
            ]),
        throwsArgumentError);
    expect(
        () => TsukamotoEngine(inputs: e.inputs, outputs: e.outputs, rules: [
              TsukamotoRule(
                  name: 'bad',
                  when: const Term('x', 'high'),
                  output: 'missing',
                  term: 'high')
            ]),
        throwsArgumentError);
    for (final n in [1, 1002]) {
      expect(
          () => TsukamotoEngine(
              inputs: e.inputs,
              outputs: e.outputs,
              rules: e.rules,
              validationSamples: n),
          throwsArgumentError);
    }
    for (final t in [-1.0, double.nan, .01]) {
      expect(
          () => TsukamotoEngine(
              inputs: e.inputs,
              outputs: e.outputs,
              rules: e.rules,
              inverseTolerance: t),
          throwsArgumentError);
    }
  });
  test('results and model collections remain immutable across evaluations', () {
    final e = model();
    final r = e.evaluate({'x': .25});
    e.evaluate({'x': .8});
    expect(r.value('y'), 25);
    expect(() => e.outputs.single.terms.clear(), throwsUnsupportedError);
    expect(() => e.inputs.clear(), throwsUnsupportedError);
    expect(() => e.rules.clear(), throwsUnsupportedError);
    expect(() => r.outputs.clear(), throwsUnsupportedError);
    expect(() => r.memberships['x']!.clear(), throwsUnsupportedError);
    expect(() => r.rules.clear(), throwsUnsupportedError);
    expect(() => r.totalWeights.clear(), throwsUnsupportedError);
  });
  test('extreme bounded outputs use shared stable averaging', () {
    final e = one(Ramp(1e308, 1.5e308));
    expect(e.evaluate({'x': .5}).value('y'), closeTo(1.25e308, 1e294));
  });
  test('JSON v2 retains Tsukamoto metadata, options and analytical decisions',
      () {
    final original = model(rising: SShape(0, 100)), codec = FuzzyModelCodec();
    final document = FuzzyModelDocument(
        engine: original,
        inputUnits: {'x': 'fraction'},
        outputUnits: {'y': '%'});
    final source = codec.encode(document),
        restored = codec.decodeTsukamoto(codec.encode(document));
    expect(jsonDecode(source)['schemaVersion'], 2);
    expect(
        codec.toJson(restored)['settings'], codec.toJson(original)['settings']);
    expect(codec.decode(source).outputUnits, {'y': '%'});
    for (var i = 0; i <= 20; i++) {
      expect(restored.evaluate({'x': i / 20}).outputs,
          original.evaluate({'x': i / 20}).outputs);
    }
    expect(() => FuzzyModelCodec(exportVersion: 1).encode(original),
        throwsUnsupportedError);
    expect(() => codec.decodeSugeno(source), throwsFormatException);
    final raw = jsonDecode(source) as Map<String, dynamic>;
    raw['schemaVersion'] = 1;
    expect(() => codec.decode(jsonEncode(raw)), throwsFormatException);
  });
  test(
      'v2 rejects noninvertible output functions and invalid validation options',
      () {
    final source = FuzzyModelCodec().encode(model());
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (m) => m['outputs'][0]['terms']['high'] = {
            'type': 'sigmoid',
            'parameters': [50, .1]
          },
      (m) => m['settings']['validationSamples'] = 1002,
      (m) => m['settings']['inverseTolerance'] = .01,
    ]) {
      final raw = jsonDecode(source) as Map<String, dynamic>;
      mutate(raw);
      expect(() => FuzzyModelCodec().decode(jsonEncode(raw)),
          throwsFormatException);
    }
  });
  test(
      'legacy Mamdani/Sugeno export stays explicit and imports remain compatible',
      () {
    final engine = FuzzyEngine(inputs: model().inputs, outputs: [
      FuzzyVariable(name: 'y', min: 0, max: 100, terms: {'high': Ramp(0, 100)})
    ], rules: [
      FuzzyRule(
          name: 'r', when: const Term('x', 'high'), output: 'y', term: 'high')
    ]);
    final legacy = FuzzyModelCodec(exportVersion: 1).encode(engine);
    expect(jsonDecode(legacy)['schemaVersion'], 1);
    expect(FuzzyModelCodec().decodeMamdani(legacy).evaluate({'x': .5}).outputs,
        engine.evaluate({'x': .5}).outputs);
    expect(() => FuzzyModelCodec(exportVersion: 3), throwsArgumentError);
  });
  test(
      'Larsen preset selects product implication without changing antecedent defaults',
      () {
    final inputs = [
      FuzzyVariable(name: 'x', min: 0, max: 1, terms: {'high': Ramp(0, 1)})
    ];
    final outputs = [
      FuzzyVariable(name: 'y', min: 0, max: 10, terms: {'falling': Ramp(10, 0)})
    ];
    final rules = [
      FuzzyRule(
          name: 'r',
          when: const Term('x', 'high'),
          output: 'y',
          term: 'falling')
    ];
    final larsen =
        FuzzyEngine.larsen(inputs: inputs, outputs: outputs, rules: rules);
    expect(larsen.evaluate({'x': .5}).value('y'), closeTo(10 / 3, 1e-5));
    expect(
        FuzzyEngine(inputs: inputs, outputs: outputs, rules: rules)
            .evaluate({'x': .5}).value('y'),
        closeTo(35 / 9, 1e-5));
    final restored =
        FuzzyModelCodec().decodeMamdani(FuzzyModelCodec().encode(larsen));
    expect(restored.evaluate({'x': .5}).outputs,
        larsen.evaluate({'x': .5}).outputs);
  });
}

class CustomMonotonic implements MonotonicMembershipFunction {
  CustomMonotonic({this.inverseFn, this.forward, this.increasing = true});
  final double Function(double)? inverseFn, forward;
  final bool increasing;
  @override
  double get domainMin => 0;
  @override
  double get domainMax => 1;
  @override
  bool get isIncreasing => increasing;
  @override
  double degree(double x) => forward?.call(x) ?? x;
  @override
  double inverse(double membership) =>
      inverseFn?.call(membership) ?? membership;
}
