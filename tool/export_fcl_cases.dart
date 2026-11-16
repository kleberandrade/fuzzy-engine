import 'dart:io';
import 'dart:convert';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Original/exported fixture and exact Dart traces for an external FCL runtime.
void main() {
  final original = File('test/fixtures/fcl/ventilation.fcl').readAsStringSync();
  final importer = FclImporter(
      inputRanges: {'temperature': FclRange(0, 1), 'humidity': FclRange(0, 1)});
  const exporter = FclExporter();
  final cases = <Object>[];
  for (final variant in ['default', 'inactive', 'tails', 'endpointOnly']) {
    final source = switch (variant) {
      'inactive' => original
          .replaceAll('WITH 0.8', 'WITH 0')
          .replaceAll('WITH 0.4', 'WITH 0'),
      'tails' => original.replaceFirst('(0,1) (1,0)', '(0.2,0.8) (0.8,0.2)'),
      'endpointOnly' => original
          .replaceFirst('(0,1) (10,0)', '(9.995,0) (10,1)')
          .replaceAll('WITH 0.4', 'WITH 0'),
      _ => original,
    };
    final model = importer.decode(source);
    final exported = exporter.encode(model, acknowledgeRuntimeSettings: true);
    for (final t in [0.0, .5, 1.0]) {
      for (final h in [0.0, .75, 1.0]) {
        final inputs = {'temperature': t, 'humidity': h};
        final result = model.evaluate(inputs);
        cases.add({
          'variant': variant,
          'source': source,
          'exportedSource': exported,
          'inputs': inputs,
          'value': result.value,
          'usedDefault': result.usedDefault,
          'defaultValue': model.defaultValue,
          'memberships': result.trace.memberships,
          'strengths': result.trace.rules.map((r) => r.strength).toList(),
          'degrees': result.trace.outputSets['fan']!.degrees,
          'intervals': model.engine.intervals
        });
      }
    }
  }
  stdout.writeln(jsonEncode(cases));
}
