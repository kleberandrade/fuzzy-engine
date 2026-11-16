import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Compare constant/linear consequents and the two Sugeno reductions.
void main() {
  final inputs = [
    FuzzyVariable(name: 'temperature', min: 0, max: 40, terms: {
      'cold': Ramp(40, 0),
      'hot': Ramp(0, 40),
    }),
  ];
  for (final linear in [false, true]) {
    for (final aggregation in SugenoAggregation.values) {
      final engine = SugenoEngine(
          inputs: inputs,
          outputs: [SugenoOutput('fan')],
          aggregation: aggregation,
          rules: [
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
                weight: .5,
                output: 'fan',
                consequent: linear
                    ? LinearConsequent(
                        intercept: 20, coefficients: {'temperature': 2})
                    : ConstantConsequent(80)),
          ]);
      final result = engine.evaluate({'temperature': 10});
      print('${linear ? 'linear' : 'constant'} / ${aggregation.name}: '
          '${result.value('fan')!.toStringAsFixed(4)}');
      for (final activation in result.rules) {
        print('  ${activation.rule.name}: w=${activation.strength}, '
            'z=${activation.consequentValue}, w*z=${activation.weightedContribution}');
      }
    }
  }
}
