import 'package:fuzzy_engine/fuzzy_engine.dart';

TsukamotoEngine tsukamotoExample() => TsukamotoEngine(inputs: [
      FuzzyVariable(name: 'demand', min: 0, max: 1, terms: {
        'low': Ramp(1, 0),
        'high': Ramp(0, 1),
      })
    ], outputs: [
      TsukamotoOutput(name: 'power', min: 0, max: 100, terms: {
        'low': Ramp(100, 0),
        'high': Ramp(0, 100),
      })
    ], rules: [
      TsukamotoRule(
          name: 'low demand',
          when: const Term('demand', 'low'),
          output: 'power',
          term: 'low'),
      TsukamotoRule(
          name: 'high demand',
          when: const Term('demand', 'high'),
          output: 'power',
          term: 'high',
          weight: .5),
    ]);

void main() {
  final engine = tsukamotoExample();
  final result = engine.evaluate({'demand': .25});
  print('Power: ${result.value('power')!.toStringAsFixed(6)}%'); // 23.214286
  for (final activation in result.rules) {
    print(
        '${activation.rule.name}: strength=${activation.strength}, inverse=${activation.inverseValue}');
  }
  final codec = FuzzyModelCodec();
  final source = codec.encode(FuzzyModelDocument(
      engine: engine,
      name: 'Tsukamoto power control',
      inputUnits: {'demand': 'fraction'},
      outputUnits: {'power': '%'}));
  final restored = codec.decodeTsukamoto(source);
  print('JSON version: ${FuzzyModelCodec.schemaVersion}');
  print('Round-trip decision: ${restored.evaluate({
        'demand': .25
      }).value('power')}');
  final report = const FuzzyDiagnostics().analyze(engine, samplesPerInput: 5);
  print('Diagnostic errors: ${report.hasErrors}');
  print('ZShape inverse at degree .25: ${ZShape(0, 100).inverse(.25)}');
}
