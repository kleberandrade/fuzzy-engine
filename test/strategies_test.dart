import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';
import '../example/strategies_example.dart' show RightmostMaximum;

FuzzyEngine engine(
        {TNorm implication = const Minimum(),
        SNorm aggregation = const Maximum(),
        Defuzzifier defuzzifier = const Centroid(),
        FuzzyOperators operators = const FuzzyOperators(),
        bool duplicate = false,
        Condition? condition}) =>
    FuzzyEngine(
        operators: operators,
        implication: implication,
        aggregation: aggregation,
        defuzzifier: defuzzifier,
        inputs: [
          FuzzyVariable(name: 'input', min: 0, max: 1, terms: {
            'low': Triangle(0, 0, 1),
            'high': Triangle(0, 1, 1),
          })
        ],
        outputs: [
          FuzzyVariable(
              name: 'output',
              min: 0,
              max: 10,
              terms: {'falling': Triangle(0, 0, 10)})
        ],
        rules: [
          for (var i = 0; i < (duplicate ? 2 : 1); i++)
            FuzzyRule(
                name: 'rule $i',
                when: condition ?? const Term('input', 'high'),
                output: 'output',
                term: 'falling')
        ]);

void main() {
  test('built-in norms match algebraic reference values', () {
    expect(const Minimum().combine(.8, .5), .5);
    expect(const AlgebraicProduct().combine(.8, .5), closeTo(.4, 1e-12));
    expect(const BoundedDifference().combine(.8, .5), closeTo(.3, 1e-12));
    expect(const BoundedDifference().combine(.2, .3), 0);
    expect(const Maximum().combine(.8, .5), .8);
    expect(const ProbabilisticSum().combine(.8, .5), closeTo(.9, 1e-12));
    expect(const BoundedSum().combine(.8, .5), 1);
    expect(const BoundedSum().combine(.2, .3), .5);
    expect(const StandardNegation().complement(.8), closeTo(.2, 1e-12));
  });

  test('norms respect neutral/absorbing elements and boundedness on a grid',
      () {
    final ts = <TNorm>[
      const Minimum(),
      const AlgebraicProduct(),
      const BoundedDifference()
    ];
    final ss = <SNorm>[
      const Maximum(),
      const ProbabilisticSum(),
      const BoundedSum()
    ];
    for (var i = 0; i <= 100; i++) {
      final a = i / 100;
      for (final t in ts) {
        expect(t.combine(a, 1), closeTo(a, 1e-12));
        expect(t.combine(a, 0), 0);
      }
      for (final s in ss) {
        expect(s.combine(a, 0), a);
        expect(s.combine(a, 1), closeTo(1, 1e-12));
      }
      for (var j = 0; j <= 100; j++) {
        final b = j / 100;
        for (final t in ts) {
          expect(t.combine(a, b), inInclusiveRange(0, 1));
          expect(t.combine(a, b), closeTo(t.combine(b, a), 1e-12));
        }
        for (final s in ss) {
          expect(s.combine(a, b), inInclusiveRange(0, 1));
          expect(s.combine(a, b), closeTo(s.combine(b, a), 1e-12));
        }
      }
    }
  });

  test('custom antecedent operators propagate through nested expressions', () {
    final expression = const Term('input', 'high')
        .and(const Term('input', 'low'))
        .or(const Term('input', 'high').not());
    final e = engine(
        condition: expression,
        operators: const FuzzyOperators(
            conjunction: AlgebraicProduct(),
            disjunction: ProbabilisticSum(),
            negation: RationalNegation()));
    // Input=.8: AND=.8*.2=.16; NOT=.2/1.8=1/9;
    // OR=.16+1/9-.16/9=19/75.
    expect(e.evaluate({'input': .8}).rules.single.strength,
        closeTo(19 / 75, 1e-12));
  });

  test(
      'default clipping and product implication have different analytic centroids',
      () {
    expect(engine().evaluate({'input': .5}).value('output'),
        closeTo(35 / 9, 1e-5));
    expect(
        engine(implication: const AlgebraicProduct())
            .evaluate({'input': .5}).value('output'),
        closeTo(10 / 3, 1e-5));
  });

  test('probabilistic aggregation matches union of two falling ramps', () {
    // At full activation, aggregate is 1 - (x/10)^2;
    // centroid = 10 * (1/4)/(2/3) = 3.75.
    expect(
        engine(duplicate: true, aggregation: const ProbabilisticSum())
            .evaluate({'input': 1}).value('output'),
        closeTo(3.75, 1e-5));
  });

  test(
      'custom defuzzifier replaces centroid and receives the actual output curve',
      () {
    final r =
        engine(defuzzifier: const RightmostMaximum()).evaluate({'input': .5});
    expect(r.value('output'), 5);
    final sampled = r.outputSets['output']!;
    expect(sampled.degrees[0], .5);
    expect(sampled.degrees[500], .5);
    expect(sampled.degrees.last, 0);
    expect(sampled.xAt(500), 5);
    expect(() => r.outputSets.clear(), throwsUnsupportedError);
    expect(() => sampled.degrees[0] = 0, throwsUnsupportedError);
  });

  test(
      'empty output stays null without asking a custom strategy for a fallback',
      () {
    final r = engine(defuzzifier: const InvalidDefuzzifier(999))
        .evaluate({'input': 0});
    expect(r.value('output'), isNull);
    expect(r.outputSets['output']!.hasArea, isFalse);
  });

  test(
      'invalid custom extension degrees are rejected at every pipeline boundary',
      () {
    for (final bad in [double.nan, double.infinity, -.1, 1.1]) {
      expect(
          () => engine(implication: InvalidNorm(bad)).evaluate({'input': .5}),
          throwsStateError);
      expect(
          () => engine(aggregation: InvalidNorm(bad)).evaluate({'input': .5}),
          throwsStateError);
      expect(
          () => engine(
                  condition: const Term('input', 'high')
                      .and(const Term('input', 'low')),
                  operators: FuzzyOperators(conjunction: InvalidNorm(bad)))
              .evaluate({'input': .5}),
          throwsStateError);
      expect(
          () => engine(
                  condition: const Term('input', 'high')
                      .or(const Term('input', 'low')),
                  operators: FuzzyOperators(disjunction: InvalidNorm(bad)))
              .evaluate({'input': .5}),
          throwsStateError);
      expect(
          () => engine(
                  condition: const Term('input', 'high').not(),
                  operators: FuzzyOperators(negation: InvalidNegation(bad)))
              .evaluate({'input': .5}),
          throwsStateError);
    }
  });

  test('invalid custom crisp outputs are rejected', () {
    for (final value in [null, double.nan, double.infinity, -1.0, 11.0]) {
      expect(
          () => engine(defuzzifier: InvalidDefuzzifier(value))
              .evaluate({'input': .5}),
          throwsStateError);
    }
  });

  test(
      'sampled sets validate universe, sample count and degrees and copy input',
      () {
    final source = [1.0, .5, 0.0];
    final set = SampledFuzzySet(min: -10, max: 10, degrees: source);
    source[0] = 0;
    expect(set.degrees.first, 1);
    expect(set.xAt(0), -10);
    expect(set.xAt(2), 10);
    expect(() => set.xAt(3), throwsRangeError);
    for (final values in [
      [.5],
      [0.0, double.nan, 1.0],
      [0.0, 1.1, 0.0]
    ]) {
      expect(() => SampledFuzzySet(min: 0, max: 1, degrees: values),
          throwsArgumentError);
    }
    expect(() => SampledFuzzySet(min: 1, max: 0, degrees: [0, 1, 0]),
        throwsArgumentError);
    expect(
        () => SampledFuzzySet(min: 0, max: double.infinity, degrees: [0, 1, 0]),
        throwsArgumentError);
  });

  test('standalone centroid handles empty and translated symmetric sets', () {
    expect(
        const Centroid()
            .defuzzify(SampledFuzzySet(min: 0, max: 10, degrees: [0, 0, 0])),
        isNull);
    expect(
        const Centroid().defuzzify(
            SampledFuzzySet(min: -10, max: 20, degrees: [0, .5, 1, .5, 0])),
        closeTo(5, 1e-12));
  });

  test('condition evaluation without operators preserves defaults', () {
    final condition = const Term('x', 'a').and(const Term('x', 'b'));
    expect(
        condition.evaluate({
          'x': {'a': .8, 'b': .5}
        }),
        .5);
    expect(
        () => condition.evaluate({
              'x': {'a': .8}
            }),
        throwsArgumentError);
  });
}

class RationalNegation implements FuzzyNegation {
  const RationalNegation();
  @override
  double complement(double value) => (1 - value) / (1 + value);
}

class InvalidNorm implements TNorm, SNorm {
  const InvalidNorm(this.value);
  final double value;
  @override
  double combine(double a, double b) => value;
}

class InvalidNegation implements FuzzyNegation {
  const InvalidNegation(this.value);
  final double value;
  @override
  double complement(double value) => this.value;
}

class InvalidDefuzzifier implements Defuzzifier {
  const InvalidDefuzzifier(this.value);
  final double? value;
  @override
  double? defuzzify(SampledFuzzySet output) => value;
}
