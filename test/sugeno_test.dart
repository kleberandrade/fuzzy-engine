import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

SugenoEngine model(
        {SugenoAggregation aggregation = SugenoAggregation.weightedAverage,
        bool linear = false,
        double hotWeight = .5}) =>
    SugenoEngine(aggregation: aggregation, inputs: [
      FuzzyVariable(name: 'temperature', min: 0, max: 40, terms: {
        'cold': Ramp(40, 0),
        'hot': Ramp(0, 40),
      })
    ], outputs: [
      SugenoOutput('fan')
    ], rules: [
      SugenoRule(
          name: 'cold',
          when: const Term('temperature', 'cold'),
          output: 'fan',
          consequent: linear
              ? LinearConsequent(
                  intercept: 10, coefficients: {'temperature': 1})
              : ConstantConsequent(20)),
      SugenoRule(
          name: 'hot',
          when: const Term('temperature', 'hot'),
          output: 'fan',
          weight: hotWeight,
          consequent: linear
              ? LinearConsequent(
                  intercept: 20, coefficients: {'temperature': 2})
              : ConstantConsequent(80)),
    ]);

SugenoEngine fixed(List<double> values,
        {double strength = 1,
        SugenoAggregation aggregation = SugenoAggregation.weightedAverage}) =>
    SugenoEngine(aggregation: aggregation, inputs: [
      FuzzyVariable(
          name: 'x', min: 0, max: 1, terms: {'on': FixedDegree(strength)})
    ], outputs: [
      SugenoOutput('y')
    ], rules: [
      for (var i = 0; i < values.length; i++)
        SugenoRule(
            name: 'r$i',
            when: const Term('x', 'on'),
            output: 'y',
            consequent: ConstantConsequent(values[i]))
    ]);

void main() {
  test('zero-order normalized weighted average matches hand calculation', () {
    final result = model().evaluate({'temperature': 10});
    expect(result.memberships['temperature'], {'cold': .75, 'hot': .25});
    expect(result.rules.map((a) => a.strength), [.75, .125]);
    expect(result.rules.map((a) => a.consequentValue), [20, 80]);
    expect(result.rules.map((a) => a.weightedContribution), [15, 10]);
    expect(result.totalWeights['fan'], .875);
    expect(result.value('fan'), closeTo(200 / 7, 1e-12));
  });
  test('weighted sum is distinct from normalized average', () {
    expect(
        model(aggregation: SugenoAggregation.weightedSum)
            .evaluate({'temperature': 10}).value('fan'),
        25);
  });
  test('first-order consequents use crisp inputs before reduction', () {
    final result = model(linear: true).evaluate({'temperature': 10});
    expect(result.rules.map((a) => a.consequentValue), [20, 40]);
    expect(result.value('fan'), closeTo(160 / 7, 1e-12));
    expect(
        model(linear: true, aggregation: SugenoAggregation.weightedSum)
            .evaluate({'temperature': 10}).value('fan'),
        20);
  });
  test('linear consequent handles named coefficients, signs and empty maps',
      () {
    final linear =
        LinearConsequent(intercept: -5, coefficients: {'x': 2, 'y': -3});
    expect(linear.evaluate({'y': 4, 'x': 10}), 3);
    expect(linear.references.toSet(), {'x', 'y'});
    expect(LinearConsequent(intercept: 7, coefficients: {}).evaluate({}), 7);
    expect(() => linear.evaluate({'x': 1}), throwsArgumentError);
    expect(
        () => linear.evaluate({'x': double.nan, 'y': 2}), throwsArgumentError);
  });
  test(
      'multi-input conditions preserve configured operators, hedges and rule weights',
      () {
    final engine = SugenoEngine(
        inputs: [
          FuzzyVariable(name: 'x', min: 0, max: 1, terms: {'on': Ramp(0, 1)}),
          FuzzyVariable(name: 'y', min: 0, max: 1, terms: {'on': Ramp(0, 1)}),
        ],
        outputs: [SugenoOutput('z')],
        operators: const FuzzyOperators(conjunction: AlgebraicProduct()),
        rules: [
          SugenoRule(
              name: 'compound',
              when: const Term('x', 'on')
                  .and(const Term('y', 'on'))
                  .hedge(const Very()),
              output: 'z',
              consequent: LinearConsequent(coefficients: {'x': 10, 'y': 20}),
              weight: .5),
        ]);
    final r = engine.evaluate({'y': .5, 'x': .8});
    expect(r.rules.single.antecedent, closeTo(.16, 1e-12));
    expect(r.rules.single.strength, closeTo(.08, 1e-12));
    expect(r.value('z'), closeTo(18, 1e-12));
  });
  test(
      'outputs reduce independently and declared outputs without rules remain null',
      () {
    final base = model();
    final e = SugenoEngine(inputs: base.inputs, outputs: [
      ...base.outputs,
      SugenoOutput('other'),
      SugenoOutput('unused')
    ], rules: [
      ...base.rules,
      SugenoRule(
          name: 'other',
          when: const Term('temperature', 'hot'),
          output: 'other',
          consequent: ConstantConsequent(-100)),
    ]);
    final r = e.evaluate({'temperature': 10});
    expect(r.value('fan'), closeTo(200 / 7, 1e-12));
    expect(r.value('other'), -100);
    expect(r.value('unused'), isNull);
    expect(r.totalWeights, {'fan': .875, 'other': .25, 'unused': 0});
  });
  for (final aggregation in SugenoAggregation.values) {
    test(
        '$aggregation distinguishes zero activation from a zero-valued consequent',
        () {
      expect(
          fixed([20], strength: 0, aggregation: aggregation)
              .evaluate({'x': .5}).value('y'),
          isNull);
      expect(
          fixed([0], aggregation: aggregation).evaluate({'x': .5}).value('y'),
          0);
    });
    test('$aggregation skips inactive and zero-weight consequents', () {
      final e = SugenoEngine(
          inputs: fixed([0]).inputs,
          outputs: [SugenoOutput('y')],
          aggregation: aggregation,
          rules: [
            SugenoRule(
                name: 'inactive',
                when: const Term('x', 'on').not(),
                output: 'y',
                consequent: BombConsequent()),
            SugenoRule(
                name: 'zero weight',
                when: const Term('x', 'on'),
                weight: 0,
                output: 'y',
                consequent: BombConsequent()),
          ]);
      final r = e.evaluate({'x': .5});
      expect(r.value('y'), isNull);
      expect(r.totalWeights['y'], 0);
      expect(r.rules.map((a) => a.consequentValue), [null, null]);
      expect(r.rules.map((a) => a.weightedContribution), [null, null]);
    });
  }
  test('input errors match the Mamdani input contract', () {
    for (final values in <Map<String, double>>[
      {},
      {'typo': 10},
      {'temperature': 10, 'extra': 1},
      {'temperature': -1},
      {'temperature': 41},
      {'temperature': double.nan},
      {'temperature': double.infinity}
    ]) {
      expect(() => model().evaluate(values), throwsArgumentError);
    }
    expect(() => model().evaluate({'temperature': 10}).value('typo'),
        throwsArgumentError);
  });
  test(
      'model validation rejects duplicates, bad references and empty configurations',
      () {
    final e = model();
    expect(() => SugenoEngine(inputs: [], outputs: e.outputs, rules: e.rules),
        throwsArgumentError);
    expect(() => SugenoEngine(inputs: e.inputs, outputs: [], rules: e.rules),
        throwsArgumentError);
    expect(() => SugenoEngine(inputs: e.inputs, outputs: e.outputs, rules: []),
        throwsArgumentError);
    expect(
        () => SugenoEngine(
            inputs: [...e.inputs, ...e.inputs],
            outputs: e.outputs,
            rules: e.rules),
        throwsArgumentError);
    expect(
        () => SugenoEngine(
            inputs: e.inputs,
            outputs: [...e.outputs, ...e.outputs],
            rules: e.rules),
        throwsArgumentError);
    expect(
        () => SugenoEngine(
            inputs: e.inputs,
            outputs: e.outputs,
            rules: [...e.rules, ...e.rules]),
        throwsArgumentError);
    for (final rule in [
      SugenoRule(
          name: 'wrong term',
          when: const Term('temperature', 'missing').hedge(const Very()),
          output: 'fan',
          consequent: ConstantConsequent(1)),
      SugenoRule(
          name: 'wrong output',
          when: const Term('temperature', 'hot'),
          output: 'missing',
          consequent: ConstantConsequent(1)),
      SugenoRule(
          name: 'wrong coefficient',
          when: const Term('temperature', 'hot'),
          output: 'fan',
          consequent: LinearConsequent(coefficients: {'typo': 0})),
      SugenoRule(
          name: 'wrong custom reference',
          when: const Term('temperature', 'hot'),
          output: 'fan',
          consequent: CustomConsequent(1, references: ['missing'])),
    ]) {
      expect(
          () =>
              SugenoEngine(inputs: e.inputs, outputs: e.outputs, rules: [rule]),
          throwsArgumentError);
    }
  });
  test('parameters must be finite and names nonempty', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity
    ]) {
      expect(() => ConstantConsequent(value), throwsArgumentError);
      expect(() => LinearConsequent(intercept: value, coefficients: {}),
          throwsArgumentError);
      expect(() => LinearConsequent(coefficients: {'x': value}),
          throwsArgumentError);
    }
    expect(() => SugenoOutput(' '), throwsArgumentError);
    expect(() => LinearConsequent(coefficients: {' ': 1}), throwsArgumentError);
    for (final weight in [-.1, 1.1, double.nan, double.infinity]) {
      expect(
          () => SugenoRule(
              name: 'r',
              when: const Term('x', 'a'),
              output: 'y',
              consequent: ConstantConsequent(1),
              weight: weight),
          throwsArgumentError);
    }
    expect(
        () => SugenoRule(
            name: ' ',
            when: const Term('x', 'a'),
            output: 'y',
            consequent: ConstantConsequent(1)),
        throwsArgumentError);
  });
  test('coefficient maps are copied and immutable', () {
    final coefficients = {'x': 2.0};
    final c = LinearConsequent(intercept: 1, coefficients: coefficients);
    coefficients['x'] = 100;
    expect(c.evaluate({'x': 3}), 7);
    expect(() => c.coefficients.clear(), throwsUnsupportedError);
  });
  test('custom consequents receive immutable crisp inputs', () {
    final e = SugenoEngine(inputs: fixed([1]).inputs, outputs: [
      SugenoOutput('y')
    ], rules: [
      SugenoRule(
          name: 'read',
          when: const Term('x', 'on'),
          output: 'y',
          consequent: ReadCrispConsequent()),
    ]);
    expect(e.evaluate({'x': .25}).value('y'), 25);
  });
  test('nonfinite custom consequent values are rejected when active', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity
    ]) {
      final e = SugenoEngine(inputs: fixed([1]).inputs, outputs: [
        SugenoOutput('y')
      ], rules: [
        SugenoRule(
            name: 'bad',
            when: const Term('x', 'on'),
            output: 'y',
            consequent: CustomConsequent(value)),
      ]);
      expect(() => e.evaluate({'x': .5}), throwsStateError);
    }
  });
  test('result explanations and engine configuration collections are immutable',
      () {
    final e = model();
    final first = e.evaluate({'temperature': 10});
    e.evaluate({'temperature': 30});
    expect(first.value('fan'), closeTo(200 / 7, 1e-12));
    expect(() => e.inputs.clear(), throwsUnsupportedError);
    expect(() => e.outputs.clear(), throwsUnsupportedError);
    expect(() => e.rules.clear(), throwsUnsupportedError);
    expect(() => first.outputs.clear(), throwsUnsupportedError);
    expect(() => first.rules.clear(), throwsUnsupportedError);
    expect(() => first.totalWeights.clear(), throwsUnsupportedError);
    expect(() => first.memberships.clear(), throwsUnsupportedError);
    expect(() => first.memberships['temperature']!.clear(),
        throwsUnsupportedError);
  });
  test('normalization preserves tiny common activation weights', () {
    final r = fixed([.1, .3], strength: 5e-324).evaluate({'x': .5});
    expect(r.value('y'), closeTo(.2, 1e-15));
    expect(r.totalWeights['y'], 1e-323);
    expect(
        r.rules.first.weightedContribution, 0); // Raw IEEE product underflows.
  });
  test('averages remain finite at extreme equal consequent values', () {
    for (final count in [2, 3, 7, 100]) {
      expect(
          fixed(List.filled(count, double.maxFinite))
              .evaluate({'x': .5}).value('y'),
          double.maxFinite);
      expect(
          fixed(List.filled(count, -double.maxFinite))
              .evaluate({'x': .5}).value('y'),
          -double.maxFinite);
    }
  });
  test('average handles signed cancellation without overflowing raw numerator',
      () {
    expect(fixed([1e308, 1e308, -1e308, -1e308]).evaluate({'x': .5}).value('y'),
        0);
    expect(fixed([1e308, -1e308, 1e-308]).evaluate({'x': .5}).value('y'),
        closeTo(1e-308 / 3, 5e-324));
  });
  test('weighted sum supports signed cancellation and rejects genuine overflow',
      () {
    expect(
        fixed([1e308, 1e308, -1e308, -1e308, 3],
                aggregation: SugenoAggregation.weightedSum)
            .evaluate({'x': .5}).value('y'),
        closeTo(3, 1e-12));
    expect(
        () => fixed([1e308, 1e308], aggregation: SugenoAggregation.weightedSum)
            .evaluate({'x': .5}),
        throwsStateError);
  });
  test('linear arithmetic is compensated and rejects unrepresentable products',
      () {
    expect(
        LinearConsequent(
                intercept: 1e308,
                coefficients: {'x': 1e308, 'y': -1e308, 'z': -1e308, 'r': 3})
            .evaluate({'x': 1, 'y': 1, 'z': 1, 'r': 1}),
        closeTo(3, 1e-12));
    expect(
        () => LinearConsequent(coefficients: {'x': double.maxFinite})
            .evaluate({'x': 2}),
        throwsStateError);
  });
  test('normalization is invariant to duplicated rules but weighted sum is not',
      () {
    expect(fixed([20, 80]).evaluate({'x': .5}).value('y'), 50);
    expect(fixed([20, 80, 20, 80]).evaluate({'x': .5}).value('y'), 50);
    expect(
        fixed([20, 80, 20, 80], aggregation: SugenoAggregation.weightedSum)
            .evaluate({'x': .5}).value('y'),
        200);
  });
  test(
      'consequent values are not restricted to membership degrees or output bounds',
      () {
    expect(fixed([-200, 400]).evaluate({'x': .5}).value('y'), 100);
    expect(
        fixed([400, 400], aggregation: SugenoAggregation.weightedSum)
            .evaluate({'x': .5}).value('y'),
        800);
  });
}

class FixedDegree implements MembershipFunction {
  const FixedDegree(this.value);
  final double value;
  @override
  double degree(double x) => value;
}

class BombConsequent implements SugenoConsequent {
  @override
  Iterable<String> get references => const [];
  @override
  double evaluate(Map<String, double> inputs) =>
      throw StateError('Inactive consequent must not be evaluated.');
}

class CustomConsequent implements SugenoConsequent {
  CustomConsequent(this.value, {this.references = const []});
  final double value;
  @override
  final Iterable<String> references;
  @override
  double evaluate(Map<String, double> inputs) => value;
}

class ReadCrispConsequent implements SugenoConsequent {
  @override
  Iterable<String> get references => const ['x'];
  @override
  double evaluate(Map<String, double> inputs) {
    expect(() => inputs['x'] = 0, throwsUnsupportedError);
    return inputs['x']! * 100;
  }
}
