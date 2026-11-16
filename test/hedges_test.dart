import 'dart:math' as math;
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

void main() {
  test('linguistic modifiers concentrate and dilate degrees', () {
    const term = Term('x', 'high');
    final values = {
      'x': {'high': .25}
    };
    expect(term.hedge(const Very()).evaluate(values), .0625);
    expect(term.hedge(const Somewhat()).evaluate(values), .5);
    expect(
        term.hedge(const Very()).hedge(const Somewhat()).evaluate(values), .25);
    expect(term.hedge(const Very()).not().evaluate(values), .9375);
    expect(term.not().hedge(const Very()).evaluate(values), .5625);
  });
  test(
      'hedges on compound expressions retain operator configuration and references',
      () {
    final c =
        const Term('x', 'a').and(const Term('x', 'b')).hedge(const Somewhat());
    expect(
        c.evaluate({
          'x': {'a': .8, 'b': .5}
        }, operators: const FuzzyOperators(conjunction: AlgebraicProduct())),
        closeTo(math.sqrt(.4), 1e-12));
    expect(c.references.map((r) => r.term), ['a', 'b']);
  });
  test('hedges participate in engine inference before rule weighting', () {
    final engine = FuzzyEngine(inputs: [
      FuzzyVariable(name: 'x', min: 0, max: 1, terms: {'high': Ramp(0, 1)}),
    ], outputs: [
      FuzzyVariable(name: 'y', min: 0, max: 1, terms: {'high': Ramp(0, 1)}),
    ], rules: [
      FuzzyRule(
          name: 'very high',
          when: const Term('x', 'high').hedge(const Very()),
          output: 'y',
          term: 'high',
          weight: .5)
    ]);
    expect(
        engine.evaluate({'x': .8}).rules.single.strength, closeTo(.32, 1e-12));
    expect(
        () =>
            FuzzyEngine(inputs: engine.inputs, outputs: engine.outputs, rules: [
              FuzzyRule(
                  name: 'invalid',
                  when: const Term('x', 'missing').hedge(const Very()),
                  output: 'y',
                  term: 'high'),
            ]),
        throwsArgumentError);
  });
  test('custom hedge invalid results are rejected', () {
    for (final v in [-.1, 1.1, double.nan, double.infinity]) {
      expect(
          () => const Term('x', 'high').hedge(BadHedge(v)).evaluate({
                'x': {'high': .5}
              }),
          throwsStateError);
    }
  });
}

class BadHedge implements FuzzyHedge {
  const BadHedge(this.value);
  final double value;
  @override
  double transform(double degree) => value;
}
