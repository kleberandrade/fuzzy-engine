import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Example extension: select the rightmost sampled global maximum.
/// Uses exact equality on sampled degrees; no interpolated peak is inferred.
class RightmostMaximum implements Defuzzifier {
  const RightmostMaximum();
  @override
  double? defuzzify(SampledFuzzySet output) {
    if (!output.hasArea) return null;
    var peak = 0;
    for (var i = 1; i < output.degrees.length; i++) {
      if (output.degrees[i] >= output.degrees[peak]) peak = i;
    }
    return output.xAt(peak);
  }
}

void main() {
  final inputs = [
    FuzzyVariable(
        name: 'heat', min: 0, max: 1, terms: {'high': Triangle(0, 1, 1)}),
    FuzzyVariable(
        name: 'humidity', min: 0, max: 1, terms: {'high': Triangle(0, 1, 1)}),
  ];
  final outputs = [
    FuzzyVariable(
        name: 'fan', min: 0, max: 100, terms: {'high': Triangle(0, 100, 100)}),
  ];
  final rules = [
    FuzzyRule(
        name: 'heat and humidity',
        when: const Term('heat', 'high').and(const Term('humidity', 'high')),
        output: 'fan',
        term: 'high'),
  ];
  final productEngine = FuzzyEngine(
      inputs: inputs,
      outputs: outputs,
      rules: rules,
      operators: const FuzzyOperators(
          conjunction: AlgebraicProduct(), disjunction: ProbabilisticSum()),
      implication: const AlgebraicProduct(),
      aggregation: const ProbabilisticSum());
  final result = productEngine.evaluate({'heat': .8, 'humidity': .5});
  print('Activation: ${result.rules.single.strength}'); // 0.4
  print('Centroid: ${result.value('fan')!.toStringAsFixed(2)}'); // 66.67
  print('Curve samples: ${result.outputSets['fan']!.degrees.length}'); // 1001

  final customEngine = FuzzyEngine(
      inputs: inputs,
      outputs: outputs,
      rules: rules,
      defuzzifier: const RightmostMaximum());
  print('Custom peak: ${customEngine.evaluate({
        'heat': .8,
        'humidity': .5
      }).value('fan')}'); // 100.0
}
