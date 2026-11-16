import 'dart:convert';
import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Informational JIT import timing; run from the repository root.
void main(List<String> args) {
  final count = args.isEmpty ? 1000 : int.parse(args.single);
  if (count <= 0) throw ArgumentError('Count must be positive.');
  final source = File('test/fixtures/fis/ventilation.fis').readAsStringSync();
  final importer =
      FisImporter(noDecisionPolicy: FisNoDecisionPolicy.preserveNull);
  for (var i = 0; i < 50; i++) {
    importer.decode(source);
  }
  var checksum = 0;
  final timer = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    checksum += importer.decode(source).engine.rules.length;
  }
  timer.stop();
  print(jsonEncode({
    'imports': count,
    'sourceCodeUnits': source.length,
    'microsecondsPerImport': timer.elapsedMicroseconds / count,
    'checksum': checksum,
  }));
}
