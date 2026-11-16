import 'dart:convert';
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Deliberately imperfect model to explain conservative diagnostics.
FuzzyModelDocument modelToolsExample() => FuzzyModelDocument(
    name: 'Fan control inspection',
    description: 'Educational model with intentionally competing rules.',
    inputUnits: {'temperature': '°C'},
    outputUnits: {'fan': '%'},
    engine: FuzzyEngine(
        inputs: [
          FuzzyVariable(
              name: 'temperature',
              min: 0,
              max: 40,
              terms: {'cold': Ramp(40, 0), 'hot': Ramp(0, 40)}),
        ],
        outputs: [
          FuzzyVariable(
              name: 'fan',
              min: 0,
              max: 100,
              terms: {'low': Ramp(100, 0), 'high': Ramp(0, 100)}),
        ],
        intervals: 100,
        rules: [
          FuzzyRule(
              name: 'hot-high',
              when: const Term('temperature', 'hot'),
              output: 'fan',
              term: 'high'),
          FuzzyRule(
              name: 'hot-high-copy',
              when: const Term('temperature', 'hot'),
              output: 'fan',
              term: 'high'),
          FuzzyRule(
              name: 'hot-low',
              when: const Term('temperature', 'hot'),
              output: 'fan',
              term: 'low'),
          FuzzyRule(
              name: 'disabled-cold',
              when: const Term('temperature', 'cold'),
              output: 'fan',
              term: 'low',
              weight: 0),
        ]));

void main() {
  final codec = FuzzyModelCodec();
  final source = codec.encode(modelToolsExample());
  final restored = codec.decode(source);
  final engine = restored.engine as FuzzyEngine;
  print('JSON schema version: ${FuzzyModelCodec.schemaVersion}');
  print('Preserved units: ${restored.inputUnits} / ${restored.outputUnits}');
  print('At 20°C: ${engine.evaluate({'temperature': 20}).value('fan')}');
  final report = const FuzzyDiagnostics().analyze(restored, samplesPerInput: 5);
  print('Grid evaluations: ${report.evaluations}');
  print('Null decisions: ${report.nullOutputCounts}');
  for (final issue in report.issues) {
    print('${issue.severity.name} / ${issue.code.name}: ${issue.rules}');
  }
  print('Portable model: $source');
  print('Portable report: ${jsonEncode(report.toJson())}');
}
