import 'dart:convert';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Sugeno-only microbenchmark; it does not model equivalent Mamdani outputs.
void main(List<String> args) {
  final count = args.isEmpty ? 1000 : int.parse(args.single);
  if (count <= 0) throw ArgumentError('Evaluation count must be positive.');
  for (final method in SugenoAggregation.values) {
    for (final ruleCount in [1, 10, 100]) {
      final engine = SugenoEngine(
          inputs: [
            for (final name in ['load', 'temperature'])
              FuzzyVariable(
                  name: name, min: 0, max: 1, terms: {'high': Ramp(0, 1)}),
          ],
          outputs: [SugenoOutput('output')],
          operators: const FuzzyOperators(conjunction: AlgebraicProduct()),
          aggregation: method,
          rules: [
            for (var i = 0; i < ruleCount; i++)
              SugenoRule(
                  name: 'r$i',
                  when: const Term('load', 'high')
                      .and(const Term('temperature', 'high')),
                  output: 'output',
                  consequent: LinearConsequent(
                      intercept: 5,
                      coefficients: {'load': 10, 'temperature': 20})),
          ]);
      for (var i = 0; i < 50; i++) {
        engine.evaluate({'load': .8, 'temperature': .5});
      }
      var checksum = 0.0;
      final timer = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        checksum +=
            engine.evaluate({'load': .8, 'temperature': .5}).value('output')!;
      }
      timer.stop();
      print(jsonEncode({
        'method': method.name,
        'rules': ruleCount,
        'evaluations': count,
        'microsecondsPerEvaluation': timer.elapsedMicroseconds / count,
        'checksum': checksum
      }));
    }
  }
}
