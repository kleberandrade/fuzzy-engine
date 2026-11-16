import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Run from the repository root; --sugeno switches the engine family.
void main(List<String> args) {
  final sugeno = args.contains('--sugeno');
  final family = sugeno ? 'sugeno' : 'mamdani';
  final source = File('test/fixtures/fis/$family-multi.fis').readAsStringSync();
  final importer =
      FisImporter(noDecisionPolicy: FisNoDecisionPolicy.preserveNull);
  const inputs = {'temperature': .5, 'humidity': .75};
  final values = sugeno
      ? importer.decodeSugeno(source).evaluate(inputs).values
      : importer.decode(source).evaluate(inputs).values;
  for (final entry in values.entries) {
    stdout
        .writeln('${entry.key}: ${entry.value ?? "no decision / sem decisão"}');
  }
}
