import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

FuzzyEngine climate({int intervals = 1000}) => FuzzyEngine(
      intervals: intervals,
      inputs: [
        FuzzyVariable(name: 'temperature', min: 0, max: 40, terms: {
          'hot': Triangle(0, 40, 40),
        }),
        FuzzyVariable(name: 'humidity', min: 0, max: 100, terms: {
          'humid': Triangle(0, 100, 100),
        }),
      ],
      outputs: [
        FuzzyVariable(name: 'fan', min: 0, max: 100, terms: {
          'high': Triangle(0, 100, 100),
        }),
      ],
      rules: [
        FuzzyRule(
            name: 'hot and humid',
            when: const Term('temperature', 'hot')
                .and(const Term('humidity', 'humid')),
            output: 'fan',
            term: 'high',
            weight: .8),
        FuzzyRule(
            name: 'hot or dry',
            when: const Term('temperature', 'hot')
                .or(const Term('humidity', 'humid').not()),
            output: 'fan',
            term: 'high',
            weight: .4),
      ],
    );

void main() {
  test('multi-input inference preserves nested rule and weight semantics', () {
    final r = climate().evaluate({'temperature': 30, 'humidity': 50});
    expect(r.memberships['temperature']!['hot'], .75);
    expect(r.memberships['humidity']!['humid'], .5);
    expect(r.rules[0].antecedent, .5);
    expect(r.rules[0].strength, closeTo(.4, 1e-12));
    expect(r.rules[1].antecedent, .75);
    expect(r.rules[1].strength, closeTo(.3, 1e-12));
    // Max aggregation clips rising triangle at .4: triangle on [0,40]
    // plus rectangle on [40,100]. Area=32; first moment=1893 1/3.
    expect(r.value('fan'), closeTo(355 / 6, .001));
  });

  test('input map ordering does not change results', () {
    final engine = climate();
    expect(engine.evaluate({'humidity': 50, 'temperature': 30}).outputs,
        engine.evaluate({'temperature': 30, 'humidity': 50}).outputs);
  });

  test('missing and extra inputs are rejected for multi-input models', () {
    final engine = climate();
    expect(() => engine.evaluate({'temperature': 30}), throwsArgumentError);
    expect(() => engine.evaluate({'temperature': 30, 'typo': 50}),
        throwsArgumentError);
    expect(
        () => engine.evaluate({'temperature': 30, 'humidity': 50, 'extra': 1}),
        throwsArgumentError);
  });

  test('unknown term nested inside NOT OR AND is validated eagerly', () {
    final base = climate();
    expect(
        () => FuzzyEngine(inputs: base.inputs, outputs: base.outputs, rules: [
              FuzzyRule(
                  name: 'invalid',
                  when: const Term('temperature', 'hot').and(
                      const Term('humidity', 'humid')
                          .or(const Term('humidity', 'typo').not())),
                  output: 'fan',
                  term: 'high'),
            ]),
        throwsArgumentError);
  });

  test('higher numerical resolution converges to an analytic centroid', () {
    final coarse = climate(intervals: 8)
        .evaluate({'temperature': 30, 'humidity': 50}).value('fan')!;
    final fine = climate(intervals: 1000)
        .evaluate({'temperature': 30, 'humidity': 50}).value('fan')!;
    const exact = 355 / 6;
    expect((fine - exact).abs(), lessThan((coarse - exact).abs()));
    expect(fine, closeTo(exact, .001));
  });

  test('all rule combinations stay finite and bounded across input space', () {
    final engine = climate(intervals: 100);
    for (var t = 0; t <= 40; t += 5) {
      for (var h = 0; h <= 100; h += 10) {
        final r = engine
            .evaluate({'temperature': t.toDouble(), 'humidity': h.toDouble()});
        if (t == 0 && h == 100) {
          expect(r.value('fan'), isNull);
        } else {
          final output = r.value('fan')!;
          expect(output.isFinite, isTrue);
          expect(output, inInclusiveRange(0, 100));
        }
      }
    }
  });

  test('evaluation results are isolated from future calls', () {
    final engine = climate();
    final first = engine.evaluate({'temperature': 30, 'humidity': 50});
    engine.evaluate({'temperature': 0, 'humidity': 100});
    expect(first.rules.first.strength, closeTo(.4, 1e-12));
    expect(() => first.outputs['fan'] = 0, throwsUnsupportedError);
    expect(() => first.rules.clear(), throwsUnsupportedError);
    expect(() => first.memberships.clear(), throwsUnsupportedError);
  });
}
