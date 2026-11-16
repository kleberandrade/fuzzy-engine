import 'dart:convert';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import '../example/model_tools_example.dart' show modelToolsExample;

/// Informational local benchmark; diagnostics include actual engine evaluations.
void main(List<String> args) {
  final count = args.isEmpty ? 200 : int.parse(args.single);
  if (count <= 0) throw ArgumentError('Iteration count must be positive.');
  final model = modelToolsExample(), codec = FuzzyModelCodec();
  final text = codec.encode(model);
  for (final operation in ['encode', 'decode', 'diagnose']) {
    Object? last;
    void run() {
      last = switch (operation) {
        'encode' => codec.encode(model),
        'decode' => codec.decode(text),
        _ => const FuzzyDiagnostics().analyze(model, samplesPerInput: 5),
      };
    }

    for (var i = 0; i < 20; i++) {
      run();
    }
    final timer = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      run();
    }
    timer.stop();
    print(jsonEncode({
      'operation': operation,
      'iterations': count,
      'microsecondsPerCall': timer.elapsedMicroseconds / count,
      'sourceCodeUnits': text.length,
      'resultType': last.runtimeType.toString()
    }));
  }
}
