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

/// Two-input educational ventilation model; output is fan demand, not a safety control.
FuzzyEngine ventilationController() {
  FuzzyVariable input(String name, double min, double max) =>
      FuzzyVariable(name: name, min: min, max: max, terms: {
        'low': Triangle(min, min, (min + max) / 2),
        'medium': Triangle(min, (min + max) / 2, max),
        'high': Triangle((min + max) / 2, max, max),
      });
  const names = ['low', 'medium', 'high'];
  const table = [
    ['low', 'low', 'medium'],
    ['low', 'medium', 'high'],
    ['medium', 'high', 'high']
  ];
  return FuzzyEngine(
      inputs: [input('temperature', 0, 40), input('humidity', 0, 100)],
      outputs: [input('fanDemand', 0, 100)],
      intervals: 200,
      rules: [
        for (var t = 0; t < 3; t++)
          for (var h = 0; h < 3; h++)
            FuzzyRule(
                name: '${names[t]} + ${names[h]} → ${table[t][h]}',
                when: Term('temperature', names[t])
                    .and(Term('humidity', names[h])),
                output: 'fanDemand',
                term: table[t][h]),
      ]);
}
