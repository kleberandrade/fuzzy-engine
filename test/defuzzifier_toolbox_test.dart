import 'dart:math' as math;
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

SampledFuzzySet sample(double Function(double) f,
        {int intervals = 1000, double min = 0, double max = 10}) =>
    SampledFuzzySet(
        min: min,
        max: max,
        degrees: [for (var i = 0; i <= intervals; i++) f(i / intervals)]);

void main() {
  test(
      'bisector of linear shoulders matches exact area formulas even on coarse grids',
      () {
    for (final n in [2, 3, 10, 1000]) {
      expect(const Bisector().defuzzify(sample((t) => 1 - t, intervals: n)),
          closeTo(10 * (1 - math.sqrt(.5)), 1e-10));
      expect(const Bisector().defuzzify(sample((t) => t, intervals: n)),
          closeTo(10 * math.sqrt(.5), 1e-10));
    }
  });
  test('bisector respects translation, scaling and constant plateaus', () {
    expect(
        const Bisector().defuzzify(sample((t) => 1 - t, min: -100, max: 200)),
        closeTo(-100 + 300 * (1 - math.sqrt(.5)), 1e-10));
    expect(const Bisector().defuzzify(sample((t) => .2)), closeTo(5, 1e-10));
    expect(const Bisector().defuzzify(sample((t) => 1e-300 * (1 - t))),
        closeTo(10 * (1 - math.sqrt(.5)), 1e-10));
  });
  test('bisector selects left edge of a half-area zero plateau', () {
    final set = SampledFuzzySet(min: 0, max: 10, degrees: [1, 0, 0, 0, 1]);
    expect(const Bisector().defuzzify(set), 2.5);
  });
  test('maxima methods distinguish disconnected maxima and arithmetic mean',
      () {
    final set = SampledFuzzySet(min: 0, max: 10, degrees: [1, 1, 0, 1, 0]);
    expect(SmallestOfMaximum().defuzzify(set), 0);
    expect(LargestOfMaximum().defuzzify(set), 7.5);
    expect(MeanOfMaximum().defuzzify(set), closeTo(10 / 3, 1e-12));
  });
  test('maxima tolerance is absolute and opt-in', () {
    final set = SampledFuzzySet(min: 0, max: 10, degrees: [.999, 1, .998]);
    expect(SmallestOfMaximum().defuzzify(set), 5);
    expect(SmallestOfMaximum(tolerance: .00101).defuzzify(set), 0);
    expect(MeanOfMaximum(tolerance: .00101).defuzzify(set), 2.5);
    expect(LargestOfMaximum(tolerance: .003).defuzzify(set), 10);
    expect(SmallestOfMaximum(tolerance: 1).defuzzify(set), 0);
  });
  test('invalid tolerances are rejected by all maxima strategies', () {
    for (final t in [-.1, 1.1, double.nan, double.infinity]) {
      expect(() => SmallestOfMaximum(tolerance: t), throwsArgumentError);
      expect(() => LargestOfMaximum(tolerance: t), throwsArgumentError);
      expect(() => MeanOfMaximum(tolerance: t), throwsArgumentError);
    }
  });
  final methods = <String, Defuzzifier>{
    'bisector': const Bisector(),
    'smallest': SmallestOfMaximum(),
    'largest': LargestOfMaximum(),
    'mean': MeanOfMaximum(),
  };
  for (final entry in methods.entries) {
    test('${entry.key} handles empty, symmetric and endpoint-only sampled sets',
        () {
      expect(entry.value.defuzzify(sample((t) => 0)), isNull);
      expect(
          entry.value.defuzzify(
              SampledFuzzySet(min: -10, max: 10, degrees: [0, .5, 1, .5, 0])),
          closeTo(0, 1e-12));
      final endpoint = entry.value
          .defuzzify(SampledFuzzySet(min: 0, max: 1, degrees: [1, 0, 0]));
      expect(endpoint, inInclusiveRange(0, 1));
    });
    test('${entry.key} works through the inference pipeline', () {
      final engine = FuzzyEngine(inputs: [
        FuzzyVariable(name: 'x', min: 0, max: 1, terms: {'high': Ramp(0, 1)}),
      ], outputs: [
        FuzzyVariable(
            name: 'y', min: 0, max: 10, terms: {'falling': Ramp(10, 0)}),
      ], rules: [
        FuzzyRule(
            name: 'r',
            when: const Term('x', 'high'),
            output: 'y',
            term: 'falling')
      ], defuzzifier: entry.value);
      final result = engine.evaluate({'x': 1});
      final expected = entry.key == 'bisector' ? 10 * (1 - math.sqrt(.5)) : 0.0;
      expect(result.value('y'), closeTo(expected, 1e-10));
      expect(engine.evaluate({'x': 0}).value('y'), isNull);
    });
  }
}
