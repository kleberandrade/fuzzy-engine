import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Run from the repository root:
/// dart run example/fis_example.dart test/fixtures/fis/ventilation.fis
void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run example/fis_example.dart <model.fis>');
    exitCode = 64;
    return;
  }
  final model = FisImporter(
    noDecisionPolicy: FisNoDecisionPolicy.preserveNull,
    intervals: 1000,
  ).decode(File(args.single).readAsStringSync());
  // Inputs for the bundled ventilation fixture; adapt names and ranges for yours.
  final result = model.evaluate({'temperature': .5, 'humidity': .75});
  print('${model.name}: ${result.value}; fallback: ${result.usedFallback}');
  for (final activation in result.trace.rules) {
    print('${activation.rule.name}: ${activation.strength}');
  }
}
