import 'dart:convert';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Separates constructor inverse probes from steady-state inference timings.
void main(List<String> args) {
  final count = args.isEmpty ? 1000 : int.parse(args.single);
  if (count <= 0) throw ArgumentError('Count must be positive.');
  for (final ruleCount in [1, 10, 100]) {
    TsukamotoEngine build() => TsukamotoEngine(inputs: [
          FuzzyVariable(name: 'x', min: 0, max: 1, terms: {'high': Ramp(0, 1)})
        ], outputs: [
          TsukamotoOutput(
              name: 'y', min: 0, max: 100, terms: {'high': SShape(0, 100)})
        ], rules: [
          for (var i = 0; i < ruleCount; i++)
            TsukamotoRule(
                name: 'r$i',
                when: const Term('x', 'high'),
                output: 'y',
                term: 'high')
        ]);
    final construction = Stopwatch()..start();
    final engine = build();
    construction.stop();
    for (var i = 0; i < 50; i++) {
      engine.evaluate({'x': .7});
    }
    var checksum = 0.0;
    final timer = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      checksum += engine.evaluate({'x': .7}).value('y')!;
    }
    timer.stop();
    print(jsonEncode({
      'rules': ruleCount,
      'evaluations': count,
      'validationSamples': engine.validationSamples,
      'constructorMicroseconds': construction.elapsedMicroseconds,
      'microsecondsPerEvaluation': timer.elapsedMicroseconds / count,
      'checksum': checksum
    }));
  }
}
