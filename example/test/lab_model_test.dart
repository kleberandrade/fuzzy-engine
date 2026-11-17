import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:fuzzy_engine_example/lab_model.dart';

void main() {
  test('three families share inputs but retain consequent semantics', () {
    final models = comparisonModels();
    expect(models.map((m) => m.family), ['Mamdani', 'Sugeno', 'Tsukamoto']);
    final results = models.map((m) => m.evaluate({'demand': 25})).toList();
    expect(results[1].outputs['power'], closeTo(35, 1e-9));
    expect(results[2].outputs['power'], closeTo(25, 1e-9));
    for (final result in results) {
      expect(result.rules.map((r) => r.strength), [.75, .25]);
      expect(result.outputs['power'], isNotNull);
    }
  });
  test('JSON preserves metadata and decisions for every family', () {
    for (final model in comparisonModels()) {
      final restored = LabModel.import(model.export());
      expect(restored.family, model.family);
      expect(restored.document.name, model.document.name);
      expect(
        restored.evaluate({'demand': 32}).outputs,
        model.evaluate({'demand': 32}).outputs,
      );
    }
  });
  test('defuzzifier changes only Mamdani reduction and survives export', () {
    final model = comparisonModels().first;
    final changed = model.withDefuzzifier('Smallest of maximum');
    expect(changed.evaluate({'demand': 25}).outputs['power'], 0);
    expect(model.evaluate({'demand': 25}).outputs['power'], greaterThan(0));
    expect(
      LabModel.import(changed.export()).evaluate({'demand': 25}).outputs,
      changed.evaluate({'demand': 25}).outputs,
    );
  });
  test('reject malformed or oversized models', () {
    expect(() => LabModel.import('{}'), throwsFormatException);
    expect(() => LabModel.import('x' * 100001), throwsFormatException);
    final json = FuzzyModelCodec().toJson(comparisonModels().first.document);
    (json['settings'] as Map)['intervals'] = 100000;
    expect(() => LabModel.importJson(json), throwsFormatException);
  });
  test('uncovered input is no decision, never zero', () {
    final model = LabModel(
      FuzzyModelDocument(
        engine: FuzzyEngine(
          inputs: [
            FuzzyVariable(
              name: 'x',
              min: 0,
              max: 10,
              terms: {'low': Triangle(0, 0, 5)},
            ),
          ],
          outputs: [
            FuzzyVariable(
              name: 'y',
              min: 0,
              max: 10,
              terms: {'low': Triangle(0, 0, 5)},
            ),
          ],
          rules: [
            FuzzyRule(
              name: 'low',
              when: const Term('x', 'low'),
              output: 'y',
              term: 'low',
            ),
          ],
        ),
      ),
    );
    expect(model.evaluate({'x': 10}).outputs['y'], isNull);
  });
}
