import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

void main() {
  const exporter = FisExporter();
  final sources = {
    for (final family in ['mamdani', 'sugeno'])
      family: File('test/fixtures/fis/$family-multi.fis').readAsStringSync()
  };
  FisImporter importer(
          [FisNoDecisionPolicy policy = FisNoDecisionPolicy.preserveNull]) =>
      FisImporter(noDecisionPolicy: policy, intervals: 4);

  test(
      'Mamdani expands shared consequents and keeps output-specific null/fallback',
      () {
    final model = importer().decode(sources['mamdani']!);
    final result = model.evaluate({'temperature': .5, 'humidity': .75});
    expect(model.engine.outputs.map((o) => o.name), ['fan', 'heater']);
    expect(model.engine.rules.map((r) => r.name),
        ['rule1:output1', 'rule1:output2', 'rule2:output2', 'rule3:output1']);
    expect(result.trace.rules.map((r) => r.strength),
        [closeTo(.2, 1e-14), closeTo(.2, 1e-14), closeTo(.3, 1e-14), 0]);
    // Output fan has only clipped low shoulder; heater combines two terms.
    expect(result.trace.outputSets['fan']!.degrees, [.2, .2, .2, .2, 0]);
    expect(result.trace.outputSets['heater']!.degrees,
        [closeTo(.3, 1e-14), closeTo(.3, 1e-14), closeTo(.3, 1e-14), .25, .2]);
    expect(result.values['fan'], closeTo(30 / 7, 1e-12));
    expect(result.values['heater'], closeTo(175 / 22, 1e-12));
    expect(() => result.value, throwsStateError);
    final partial = importer(FisNoDecisionPolicy.midpoint)
        .decode(sources['mamdani']!)
        .evaluate({'temperature': 1, 'humidity': 1});
    expect(partial.fallbackOutputs, {'fan'});
    expect(partial.values['fan'], 5);
    expect(partial.trace.value('fan'), isNull);
    expect(partial.values['heater'], isNotNull);
    expect(partial.usedFallback, isTrue);
    expect(() => partial.values['fan'] = 0, throwsUnsupportedError);
    expect(() => partial.fallbackOutputs.add('heater'), throwsUnsupportedError);
  });

  test(
      'Sugeno denominators exclude ignored outputs and preserve unused catalogs',
      () {
    final model = importer().decodeSugeno(sources['sugeno']!);
    final result = model.evaluate({'temperature': .5, 'humidity': .75});
    // fan: only z=10 participates, heater: z=11 and z=100 with w=.2,.3.
    expect(result.values['fan'], closeTo(10, 1e-12));
    expect(result.values['heater'], closeTo(64.4, 1e-12));
    expect(model.outputs['heater']!.consequents.keys,
        ['constant', 'linear', 'unused']);
    expect(model.outputs['heater']!.min, -20);
    expect(model.outputs['heater']!.max, 40);
    expect(() => result.value, throwsStateError);
    expect(() => model.consequents, throwsStateError);
    expect(() => model.outputMin, throwsStateError);
    expect(() => model.outputMax, throwsStateError);
    final sum = importer()
        .decodeSugeno(sources['sugeno']!.replaceFirst("'wtaver'", "'wtsum'"));
    final summed = sum.evaluate({'temperature': .5, 'humidity': .75});
    expect(summed.values['fan'], closeTo(2, 1e-12));
    expect(summed.values['heater'], closeTo(32.2, 1e-12));
    final partial = importer(FisNoDecisionPolicy.midpoint)
        .decodeSugeno(sources['sugeno']!)
        .evaluate({'temperature': 1, 'humidity': 1});
    expect(partial.values, {'fan': 45, 'heater': 100});
    expect(partial.fallbackOutputs, {'fan'});
    expect(partial.trace.value('fan'), isNull);
    expect(() => partial.values.clear(), throwsUnsupportedError);
    expect(() => partial.fallbackOutputs.clear(), throwsUnsupportedError);
    expect(() => model.outputs.clear(), throwsUnsupportedError);
    expect(() => model.outputs['heater']!.consequents.clear(),
        throwsUnsupportedError);
  });

  for (final family in sources.keys) {
    final source = sources[family]!;
    test(
        '$family round-trip preserves decisions per output including null and duplicates',
        () {
      final text = family == 'mamdani'
          ? exporter.encodeMamdani(importer().decode(source).engine,
              name: 'multi', acknowledgeRuntimeSettings: true)
          : exporter.encodeSugeno(importer().decodeSugeno(source),
              acknowledgeRuntimeSettings: true);
      expect(text, contains('NumOutputs=2'));
      expect(text, contains('NumRules=4'));
      expect(text, contains('1 1, 1 0 (0.8) : 1'));
      expect(text, contains('1 1, 0 2 (0.8) : 1'));
      final twice = family == 'mamdani'
          ? exporter.encodeMamdani(importer().decode(text).engine,
              name: 'multi', acknowledgeRuntimeSettings: true)
          : exporter.encodeSugeno(importer().decodeSugeno(text),
              acknowledgeRuntimeSettings: true);
      expect(twice, text);
      for (final x in [0.0, .25, .5, 1.0]) {
        for (final y in [0.0, .75, 1.0]) {
          final inputs = {'temperature': x, 'humidity': y};
          final a = family == 'mamdani'
              ? importer().decode(source).evaluate(inputs).values
              : importer().decodeSugeno(source).evaluate(inputs).values;
          final b = family == 'mamdani'
              ? importer().decode(text).evaluate(inputs).values
              : importer().decodeSugeno(text).evaluate(inputs).values;
          expect(b, a);
        }
      }
    });
    test('$family throws if any output has no decision', () {
      expect(
          () => family == 'mamdani'
              ? importer(FisNoDecisionPolicy.throwError)
                  .decode(source)
                  .evaluate({'temperature': 1, 'humidity': 1})
              : importer(FisNoDecisionPolicy.throwError)
                  .decodeSugeno(source)
                  .evaluate({'temperature': 1, 'humidity': 1}),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'output', contains('fan'))));
    });
    final invalid = {
      'missing output section': source.replaceFirst('[Output2]', '[Output3]'),
      'undeclared section': source.replaceFirst('NumOutputs=2', 'NumOutputs=1'),
      'wrong vector length': source.replaceFirst('1 1, 1 2', '1 1, 1'),
      'too many output indices': source.replaceFirst('1 1, 1 2', '1 1, 1 2 0'),
      'all ignored outputs': source.replaceFirst('1 1, 1 2', '1 1, 0 0'),
      'negative output index': source.replaceFirst('1 1, 1 2', '1 1, 1 -2'),
      'fractional output index': source.replaceFirst('1 1, 1 2', '1 1, 1 1.5'),
      'out of range second index': source.replaceFirst('1 1, 1 2', '1 1, 1 4'),
      'duplicate output name':
          source.replaceFirst("Name='heater'", "Name='fan'"),
      'invalid second range': source.replaceFirst('[-20 40]', '[40 -20]'),
    };
    for (final entry in invalid.entries) {
      test('$family rejects ${entry.key}', () {
        expect(
            () => family == 'mamdani'
                ? importer().decode(entry.value)
                : importer().decodeSugeno(entry.value),
            throwsFormatException);
      });
    }
    test('$family limits outputs and expanded rule allocation', () {
      for (final limited in [
        FisImporter(
            noDecisionPolicy: FisNoDecisionPolicy.preserveNull, maxOutputs: 1),
        FisImporter(
            noDecisionPolicy: FisNoDecisionPolicy.preserveNull, maxRules: 3),
      ]) {
        expect(
            () => family == 'mamdani'
                ? limited.decode(source)
                : limited.decodeSugeno(source),
            throwsFormatException);
      }
    });
  }
  test(
      'Sugeno programmatic metadata must match outputs and their consequent instances',
      () {
    final model = importer().decodeSugeno(sources['sugeno']!);
    FisSugenoModel build(Map<String, FisSugenoOutput> outputs) =>
        FisSugenoModel.multiOutput(
            name: 'test',
            engine: model.engine,
            outputs: outputs,
            noDecisionPolicy: FisNoDecisionPolicy.preserveNull);
    expect(() => build({'fan': model.outputs['fan']!}), throwsArgumentError);
    expect(() => build({...model.outputs, 'extra': model.outputs['fan']!}),
        throwsArgumentError);
    expect(
        () => build(
            {'fan': model.outputs['heater']!, 'heater': model.outputs['fan']!}),
        throwsArgumentError);
    expect(
        () => build({
              ...model.outputs,
              'heater': FisSugenoOutput(
                  min: 0,
                  max: 10,
                  consequents: {'custom': ConstantConsequent(100)})
            }),
        throwsArgumentError);
    expect(
        () => build({
              ...model.outputs,
              'heater': FisSugenoOutput(min: 0, max: 10, consequents: {
                ...model.outputs['heater']!.consequents,
                'unknown':
                    LinearConsequent(intercept: 0, coefficients: {'unknown': 1})
              })
            }),
        throwsArgumentError);
    expect(
        () => FisSugenoOutput(
            min: 10, max: 0, consequents: {'z': ConstantConsequent(1)}),
        throwsArgumentError);
    expect(
        () => FisImporter(
            noDecisionPolicy: FisNoDecisionPolicy.preserveNull, maxOutputs: 0),
        throwsArgumentError);
  });
}
