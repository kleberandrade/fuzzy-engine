import 'package:fuzzy_engine/fuzzy_engine.dart';

void main() {
  final engine = FuzzyEngine(
    inputs: [
      FuzzyVariable(name: 'temperature', min: 0, max: 50, terms: {
        'cold': Triangle(0, 0, 25),
        'warm': Triangle(0, 25, 50),
        'hot': Triangle(25, 50, 50),
      }),
    ],
    outputs: [
      FuzzyVariable(name: 'fanSpeed', min: 0, max: 100, terms: {
        'low': Triangle(0, 0, 50),
        'medium': Triangle(0, 50, 100),
        'high': Triangle(50, 100, 100),
      }),
    ],
    rules: [
      FuzzyRule(
          name: 'cold → low',
          when: const Term('temperature', 'cold'),
          output: 'fanSpeed',
          term: 'low'),
      FuzzyRule(
          name: 'warm → medium',
          when: const Term('temperature', 'warm'),
          output: 'fanSpeed',
          term: 'medium'),
      FuzzyRule(
          name: 'hot → high',
          when: const Term('temperature', 'hot'),
          output: 'fanSpeed',
          term: 'high'),
    ],
  );
  final result = engine.evaluate({'temperature': 32});
  print(result.value('fanSpeed')); // Approximately 51.85
  print(result.memberships); // cold: 0, warm: 0.72, hot: 0.28
  for (final activation in result.rules) {
    print('${activation.rule.name}: ${activation.strength}');
  }
}
