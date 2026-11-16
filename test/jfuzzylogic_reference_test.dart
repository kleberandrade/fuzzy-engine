import 'dart:convert';
import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

void main() {
  final reference = jsonDecode(
      File('test/fixtures/fcl/jfuzzylogic-reference.json').readAsStringSync());
  for (final fixture in reference['cases'] as List) {
    final inputs = (fixture['inputs'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toDouble()));
    test('jFuzzyLogic ${fixture['variant']} $inputs', () {
      final importer = FclImporter(inputRanges: {
        'temperature': FclRange(0, 1),
        'humidity': FclRange(0, 1)
      }, intervals: fixture['intervals'] as int);
      final model = importer.decode(fixture['source'] as String);
      final exported =
          const FclExporter().encode(model, acknowledgeRuntimeSettings: true);
      for (final candidate in [model, importer.decode(exported)]) {
        final result = candidate.evaluate(inputs);
        expect(
            result.value,
            closeTo(fixture['trapezoidalValue'] as num,
                fixture['tolerance'] as num));
        expect(result.usedDefault, fixture['usedDefault']);
        for (var i = 0; i < result.trace.rules.length; i++) {
          expect(result.trace.rules[i].strength,
              closeTo(fixture['strengths'][i] as num, 1e-12));
        }
        for (final variable in result.trace.memberships.entries) {
          for (final term in variable.value.entries) {
            expect(
                term.value,
                closeTo(fixture['memberships'][variable.key][term.key] as num,
                    1e-12));
          }
        }
      }
    });
  }
}
