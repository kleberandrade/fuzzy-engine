import 'dart:convert';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Reproducible microbenchmark; run from the package root with an optional
/// positive evaluation count. Times include curve allocation and defuzzification.
void main(List<String> args) {
  final iterations = args.isEmpty ? 200 : int.parse(args.single);
  if (iterations <= 0) throw ArgumentError('Iterations must be positive.');
  for (final ruleCount in [1, 10, 100]) {
    final engine = FuzzyEngine(inputs: [
      FuzzyVariable(
          name: 'x', min: 0, max: 1, terms: {'high': Triangle(0, 1, 1)}),
    ], outputs: [
      FuzzyVariable(
          name: 'y', min: 0, max: 100, terms: {'high': Triangle(0, 100, 100)}),
    ], rules: [
      for (var i = 0; i < ruleCount; i++)
        FuzzyRule(
            name: 'rule $i',
            when: const Term('x', 'high'),
            output: 'y',
            term: 'high'),
    ]);
    for (var i = 0; i < 50; i++) {
      engine.evaluate({'x': .7});
    }
    var checksum = 0.0;
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      checksum += engine.evaluate({'x': .7}).value('y')!;
    }
    stopwatch.stop();
    print(jsonEncode({
      'rules': ruleCount,
      'intervals': engine.intervals,
      'evaluations': iterations,
      'microsecondsPerEvaluation': stopwatch.elapsedMicroseconds / iterations,
      'checksum': checksum,
    }));
  }
}
