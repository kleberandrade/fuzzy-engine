import 'dart:convert';
import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

void main() {
  final reference = jsonDecode(
          File('test/fixtures/fis/external-reference.json').readAsStringSync())
      as Map<String, dynamic>;
  for (final raw in reference['cases'] as List) {
    final fixture = raw as Map<String, dynamic>;
    final inputs = (fixture['inputs'] as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, (value as num).toDouble()));
    test('scikit-fuzzy ${fixture['family']} ${fixture['variant']} $inputs', () {
      final importer = FisImporter(
          noDecisionPolicy: FisNoDecisionPolicy.preserveNull,
          intervals: fixture['intervals'] as int);
      final expected = fixture['externalValue'] as num?;
      final tolerance = (fixture['crispTolerance'] as num).toDouble();
      void verify(double? value, Map<String, Map<String, double>> memberships,
          Iterable<double> strengths) {
        if (expected == null) {
          expect(value, isNull);
        } else {
          expect(value, closeTo(expected, tolerance));
        }
        final actualStrengths = strengths.toList();
        final expectedStrengths = fixture['strengths'] as List;
        expect(actualStrengths.length, expectedStrengths.length);
        for (var i = 0; i < actualStrengths.length; i++) {
          expect(
              actualStrengths[i], closeTo(expectedStrengths[i] as num, 1e-12));
        }
        for (final variable in memberships.entries) {
          for (final term in variable.value.entries) {
            expect(
                term.value,
                closeTo(fixture['memberships'][variable.key][term.key] as num,
                    1e-12));
          }
        }
      }

      const exporter = FisExporter();
      if (fixture['family'] == 'mamdani') {
        final model = importer.decode(fixture['source'] as String);
        for (final engine in [
          model.engine,
          importer
              .decode(exporter.encodeMamdani(model.engine,
                  name: model.name, acknowledgeRuntimeSettings: true))
              .engine
        ]) {
          final result = engine.evaluate(inputs);
          verify(result.value('fan'), result.memberships,
              result.rules.map((r) => r.strength));
        }
      } else {
        final model = importer.decodeSugeno(fixture['source'] as String);
        for (final engine in [
          model.engine,
          importer
              .decodeSugeno(exporter.encodeSugeno(model,
                  acknowledgeRuntimeSettings: true))
              .engine
        ]) {
          final result = engine.evaluate(inputs);
          verify(result.value('fan'), result.memberships,
              result.rules.map((r) => r.strength));
        }
      }
    });
  }
}
