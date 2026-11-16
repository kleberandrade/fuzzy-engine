import 'dart:convert';
import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Informational JIT import timing; file IO and inference are excluded.
void main() {
  final source = File('test/fixtures/fcl/ventilation.fcl').readAsStringSync();
  final importer = FclImporter(
      inputRanges: {'temperature': FclRange(0, 1), 'humidity': FclRange(0, 1)});
  for (var i = 0; i < 50; i++) {
    importer.decode(source);
  }
  var checksum = 0;
  final watch = Stopwatch()..start();
  for (var i = 0; i < 1000; i++) {
    checksum += importer.decode(source).engine.rules.length;
  }
  watch.stop();
  final model = importer.decode(source);
  const exporter = FclExporter();
  for (var i = 0; i < 50; i++) {
    exporter.encode(model, acknowledgeRuntimeSettings: true);
  }
  var exportedUnits = 0;
  final exportWatch = Stopwatch()..start();
  for (var i = 0; i < 1000; i++) {
    exportedUnits +=
        exporter.encode(model, acknowledgeRuntimeSettings: true).length;
  }
  exportWatch.stop();
  print(jsonEncode({
    'imports': 1000,
    'microsecondsPerImport': watch.elapsedMicroseconds / 1000,
    'checksum': checksum,
    'microsecondsPerExport': exportWatch.elapsedMicroseconds / 1000,
    'exportedCodeUnits': exportedUnits
  }));
}
