import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Run from the repository root; no files are written.
void main() {
  final source = File('test/fixtures/fcl/ventilation.fcl').readAsStringSync();
  final model = FclImporter(inputRanges: {
    'temperature': FclRange(0, 1),
    'humidity': FclRange(0, 1),
  }).decode(source);
  final result = model.evaluate({'temperature': .5, 'humidity': .75});
  final exported =
      const FclExporter().encode(model, acknowledgeRuntimeSettings: true);
  print(
      'Exported FCL: ${exported.length} characters; input ranges and resolution are external.');
  print('${model.name}: ${result.value}; default: ${result.usedDefault}');
  for (final rule in result.trace.rules) {
    print('${rule.rule.name}: ${rule.strength}');
  }
}
