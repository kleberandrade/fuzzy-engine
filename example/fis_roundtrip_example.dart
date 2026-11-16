import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Run from the repository root. No files are written by this example.
void main() {
  final importer =
      FisImporter(noDecisionPolicy: FisNoDecisionPolicy.preserveNull);
  const exporter = FisExporter();
  final values = {'temperature': .5, 'humidity': .75};
  final mamdani = importer
      .decode(File('test/fixtures/fis/ventilation.fis').readAsStringSync());
  final mamdaniText = exporter.encodeMamdani(mamdani.engine,
      name: mamdani.name, acknowledgeRuntimeSettings: true);
  print('Mamdani: ${importer.decode(mamdaniText).evaluate(values).value}');
  final sugeno = importer
      .decodeSugeno(File('test/fixtures/fis/sugeno.fis').readAsStringSync());
  final sugenoText =
      exporter.encodeSugeno(sugeno, acknowledgeRuntimeSettings: true);
  print(
      'Sugeno weighted average: ${importer.decodeSugeno(sugenoText).evaluate(values).value}');
  final sum =
      importer.decodeSugeno(sugenoText.replaceFirst("'wtaver'", "'wtsum'"));
  print('Sugeno weighted sum: ${sum.evaluate(values).value}');
  print('FIS omits rule names, integration resolution and no-decision policy.');
}
