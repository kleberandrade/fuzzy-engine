import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Small reusable educational models; thresholds need domain calibration.
FuzzyEngine controller(String input, String output, double min, double max) {
  final mid = (min + max) / 2;
  return FuzzyEngine(inputs: [
    FuzzyVariable(name: input, min: min, max: max, terms: {
      'low': Triangle(min, min, mid),
      'medium': Triangle(min, mid, max),
      'high': Triangle(mid, max, max),
    }),
  ], outputs: [
    FuzzyVariable(name: output, min: 0, max: 100, terms: {
      'low': Triangle(0, 0, 50),
      'medium': Triangle(0, 50, 100),
      'high': Triangle(50, 100, 100),
    }),
  ], rules: [
    for (final term in ['low', 'medium', 'high'])
      FuzzyRule(
          name: '$input:$term',
          when: Term(input, term),
          output: output,
          term: input == 'soilMoisture'
              ? {'low': 'high', 'medium': 'medium', 'high': 'low'}[term]!
              : term),
  ]);
}
