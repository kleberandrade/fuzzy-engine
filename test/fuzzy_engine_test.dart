import 'dart:math' as math;
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

FuzzyEngine model(
        {int intervals = 1000, double weight = 1, bool gap = false}) =>
    FuzzyEngine(inputs: [
      FuzzyVariable(
          name: 'x',
          min: 0,
          max: 10,
          terms: {'on': gap ? Triangle(0, 0, 2) : Trapezoid(0, 0, 10, 10)})
    ], outputs: [
      FuzzyVariable(
          name: 'y', min: 0, max: 10, terms: {'shape': Triangle(0, 0, 10)})
    ], rules: [
      FuzzyRule(
          name: 'rule',
          when: const Term('x', 'on'),
          output: 'y',
          term: 'shape',
          weight: weight)
    ], intervals: intervals);
void main() {
  group('membership', () {
    test('triangles and shoulders', () {
      final f = Triangle(0, 5, 10);
      expect([
        f.degree(-1),
        f.degree(0),
        f.degree(2.5),
        f.degree(5),
        f.degree(7.5),
        f.degree(10)
      ], [
        0,
        0,
        .5,
        1,
        .5,
        0
      ]);
      expect(Triangle(0, 0, 10).degree(0), 1);
      expect(Triangle(0, 10, 10).degree(10), 1);
    });
    test('trapezoid inclusive shoulders and plateau', () {
      final f = Trapezoid(0, 2, 8, 10);
      expect([
        f.degree(-1),
        f.degree(1),
        f.degree(2),
        f.degree(8),
        f.degree(9),
        f.degree(11)
      ], [
        0,
        .5,
        1,
        1,
        .5,
        0
      ]);
      expect(Trapezoid(0, 0, 10, 10).degree(0), 1);
      expect(Trapezoid(0, 0, 10, 10).degree(10), 1);
    });
    test('Gaussian matches analytic values', () {
      final f = Gaussian(5, 2);
      expect(f.degree(5), 1);
      expect(f.degree(7), closeTo(math.exp(-.5), 1e-12));
      expect(f.degree(3), f.degree(7));
    });
    test('reject invalid parameters and nonfinite arguments', () {
      expect(() => Triangle(1, 0, 2), throwsArgumentError);
      expect(() => Triangle(1, 1, 1), throwsArgumentError);
      expect(() => Trapezoid(0, 3, 2, 4), throwsArgumentError);
      expect(() => Gaussian(0, 0), throwsArgumentError);
      expect(() => Gaussian(double.nan, 1), throwsArgumentError);
      expect(
          () => Triangle(0, 1, 2).degree(double.infinity), throwsArgumentError);
    });
  });
  test('composable min/max/complement', () {
    const a = Term('x', 'a'), b = Term('x', 'b');
    final values = {
      'x': {'a': .3, 'b': .8}
    };
    expect(a.and(b).evaluate(values), .3);
    expect(a.or(b).evaluate(values), .8);
    expect(a.not().evaluate(values), .7);
    expect(a.or(b).not().references.length, 2);
  });
  test('centroid agrees with analytic right triangle centroid', () {
    final result = model().evaluate({'x': 5});
    expect(result.value('y'), closeTo(10 / 3, .00001));
    expect(result.memberships['x']!['on'], 1);
    expect(result.rules.single.strength, 1);
  });
  test('weighted clipping has analytic centroid', () {
    // Clipped descending triangle: rectangle [0,5] plus triangle [5,10].
    expect(model(weight: .5).evaluate({'x': 5}).value('y'),
        closeTo(35 / 9, .00001));
  });
  test('no activated area returns null including zero-weight rule', () {
    expect(model(gap: true).evaluate({'x': 5}).value('y'), isNull);
    expect(model(weight: 0).evaluate({'x': 5}).value('y'), isNull);
  });
  test('centroid independent of translated output universe', () {
    final e = FuzzyEngine(
        inputs: model().inputs,
        outputs: [
          FuzzyVariable(
              name: 'y',
              min: -20,
              max: -10,
              terms: {'shape': Triangle(-20, -20, -10)})
        ],
        rules: model().rules);
    expect(e.evaluate({'x': 0}).value('y'), closeTo(-20 + 10 / 3, .00001));
  });
  test('max aggregation is idempotent and supports multiple outputs', () {
    final base = model();
    final e = FuzzyEngine(inputs: base.inputs, outputs: [
      ...base.outputs,
      FuzzyVariable(
          name: 'z', min: 0, max: 10, terms: {'shape': Triangle(0, 5, 10)})
    ], rules: [
      ...base.rules,
      FuzzyRule(
          name: 'duplicate consequent',
          when: const Term('x', 'on'),
          output: 'y',
          term: 'shape'),
      FuzzyRule(
          name: 'second output',
          when: const Term('x', 'on'),
          output: 'z',
          term: 'shape')
    ]);
    final r = e.evaluate({'x': 5});
    expect(r.value('y'), base.evaluate({'x': 5}).value('y'));
    expect(r.value('z'), closeTo(5, 1e-10));
  });
  test('invalid evaluations fail explicitly', () {
    final e = model();
    for (final v in <Map<String, double>>[
      {},
      {'other': 2},
      {'x': -1},
      {'x': 11},
      {'x': double.nan},
      {'x': double.infinity}
    ]) {
      expect(() => e.evaluate(v), throwsArgumentError);
    }
    expect(() => e.evaluate({'x': 5}).value('typo'), throwsArgumentError);
    expect(() => e.evaluate({'x': 5}).memberships['x']!['on'] = 0,
        throwsUnsupportedError);
  });
  test('invalid model references and duplicate variables rejected eagerly', () {
    final base = model();
    expect(
        () => FuzzyEngine(inputs: base.inputs, outputs: base.outputs, rules: [
              FuzzyRule(
                  name: 'bad',
                  when: const Term('x', 'typo'),
                  output: 'y',
                  term: 'shape')
            ]),
        throwsArgumentError);
    expect(
        () => FuzzyEngine(
            inputs: [...base.inputs, ...base.inputs],
            outputs: base.outputs,
            rules: base.rules),
        throwsArgumentError);
    expect(
        () => FuzzyEngine(
            inputs: base.inputs,
            outputs: base.outputs,
            rules: [...base.rules, ...base.rules]),
        throwsArgumentError);
    expect(() => model(intervals: 1), throwsArgumentError);
    expect(() => model(weight: 2), throwsArgumentError);
  });
  test('custom functions cannot silently return invalid degrees', () {
    final e = FuzzyEngine(inputs: [
      FuzzyVariable(name: 'x', min: 0, max: 10, terms: {'on': BadMembership()})
    ], outputs: model().outputs, rules: model().rules);
    expect(() => e.evaluate({'x': 1}), throwsStateError);
  });
}

class BadMembership implements MembershipFunction {
  @override
  double degree(double x) => double.nan;
}
