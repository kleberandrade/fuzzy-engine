import 'dart:convert';
import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Export original and round-tripped cases for an independent Python evaluator.
void main() {
  final importer =
      FisImporter(noDecisionPolicy: FisNoDecisionPolicy.preserveNull);
  const exporter = FisExporter();
  final cases = <Map<String, Object?>>[];
  for (final family in ['mamdani', 'sugeno']) {
    final fixture = family == 'mamdani' ? 'ventilation' : 'sugeno';
    final original = File('test/fixtures/fis/$fixture.fis').readAsStringSync();
    for (final variant in [
      'default',
      'inactive',
      if (family == 'mamdani') ...['gaussian', 'product'],
      if (family == 'sugeno') 'weightedSum'
    ]) {
      final source = switch (variant) {
        'inactive' =>
          original.replaceAll('(0.8)', '(0)').replaceAll('(0.4)', '(0)'),
        'gaussian' =>
          original.replaceFirst("'trimf',[0 0 1]", "'gaussmf',[0.2 0.5]"),
        'product' => original
            .replaceFirst("AndMethod='min'", "AndMethod='prod'")
            .replaceFirst("OrMethod='max'", "OrMethod='probor'")
            .replaceFirst("ImpMethod='min'", "ImpMethod='prod'"),
        'weightedSum' => original.replaceFirst("'wtaver'", "'wtsum'"),
        _ => original,
      };
      final model = family == 'mamdani' ? importer.decode(source) : null;
      final sugeno = family == 'sugeno' ? importer.decodeSugeno(source) : null;
      final exported = model != null
          ? exporter.encodeMamdani(model.engine,
              name: model.name, acknowledgeRuntimeSettings: true)
          : exporter.encodeSugeno(sugeno!, acknowledgeRuntimeSettings: true);
      for (final x in [0.0, .5, 1.0]) {
        for (final y in [0.0, .75, 1.0]) {
          final inputs = {'temperature': x, 'humidity': y};
          final result = model?.engine.evaluate(inputs);
          final crisp = sugeno?.engine.evaluate(inputs);
          cases.add({
            'family': family,
            'variant': variant,
            'source': source,
            'exportedSource': exported,
            'inputs': inputs,
            'memberships': result?.memberships ?? crisp!.memberships,
            'strengths': result?.rules.map((r) => r.strength).toList() ??
                crisp!.rules.map((r) => r.strength).toList(),
            'value': result?.value('fan') ?? crisp?.value('fan'),
            if (result != null) 'degrees': result.outputSets['fan']!.degrees,
            if (result != null) 'intervals': model!.engine.intervals,
          });
        }
      }
    }
  }
  for (final family in ['mamdani', 'sugeno']) {
    final original =
        File('test/fixtures/fis/$family-multi.fis').readAsStringSync();
    for (final variant in [
      'multi',
      if (family == 'sugeno') 'multiWeightedSum'
    ]) {
      final source = variant == 'multiWeightedSum'
          ? original.replaceFirst("'wtaver'", "'wtsum'")
          : original;
      final model = family == 'mamdani' ? importer.decode(source) : null;
      final sugeno = family == 'sugeno' ? importer.decodeSugeno(source) : null;
      final exported = model != null
          ? exporter.encodeMamdani(model.engine,
              name: model.name, acknowledgeRuntimeSettings: true)
          : exporter.encodeSugeno(sugeno!, acknowledgeRuntimeSettings: true);
      for (final x in [0.0, .5, 1.0]) {
        for (final y in [0.0, .75, 1.0]) {
          final inputs = {'temperature': x, 'humidity': y};
          final result = model?.engine.evaluate(inputs);
          final crisp = sugeno?.engine.evaluate(inputs);
          for (final output in ['fan', 'heater']) {
            cases.add({
              'family': family,
              'variant': variant,
              'output': output,
              'source': source,
              'exportedSource': exported,
              'inputs': inputs,
              'memberships': result?.memberships ?? crisp!.memberships,
              'strengths': result != null
                  ? result.rules
                      .where((r) => r.rule.output == output)
                      .map((r) => r.strength)
                      .toList()
                  : crisp!.rules
                      .where((r) => r.rule.output == output)
                      .map((r) => r.strength)
                      .toList(),
              'value':
                  result != null ? result.value(output) : crisp!.value(output),
              if (result != null) 'degrees': result.outputSets[output]!.degrees,
              if (result != null) 'intervals': model!.engine.intervals,
            });
          }
        }
      }
    }
  }
  stdout.writeln(jsonEncode(cases));
}
