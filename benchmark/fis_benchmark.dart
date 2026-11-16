import 'dart:convert';
import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Informational JIT import/export timing; run from the repository root.
void main(List<String> args) {
  final count = args.isEmpty ? 1000 : int.parse(args.single);
  if (count <= 0) throw ArgumentError('Count must be positive.');
  final importer =
      FisImporter(noDecisionPolicy: FisNoDecisionPolicy.preserveNull);
  const exporter = FisExporter();
  for (final family in ['mamdani', 'sugeno']) {
    final fixture = family == 'mamdani' ? 'ventilation' : 'sugeno';
    final source = File('test/fixtures/fis/$fixture.fis').readAsStringSync();
    final model = family == 'mamdani' ? importer.decode(source) : null;
    final sugeno = family == 'sugeno' ? importer.decodeSugeno(source) : null;
    for (final operation in ['import', 'export']) {
      int run() {
        if (operation == 'import') {
          return family == 'mamdani'
              ? importer.decode(source).engine.rules.length
              : importer.decodeSugeno(source).engine.rules.length;
        }
        return model != null
            ? exporter
                .encodeMamdani(model.engine,
                    name: model.name, acknowledgeRuntimeSettings: true)
                .length
            : exporter
                .encodeSugeno(sugeno!, acknowledgeRuntimeSettings: true)
                .length;
      }

      for (var i = 0; i < 50; i++) {
        run();
      }
      var checksum = 0;
      final timer = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        checksum += run();
      }
      timer.stop();
      print(jsonEncode({
        'family': family,
        'operation': operation,
        'count': count,
        'sourceCodeUnits': source.length,
        'microsecondsPerOperation': timer.elapsedMicroseconds / count,
        'checksum': checksum
      }));
    }
  }
}
