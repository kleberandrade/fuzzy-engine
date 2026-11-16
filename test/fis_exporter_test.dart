import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

void main() {
  final importer = FisImporter(
      noDecisionPolicy: FisNoDecisionPolicy.preserveNull, intervals: 100);
  const exporter = FisExporter();
  final source = File('test/fixtures/fis/ventilation.fis').readAsStringSync();
  final sugeno = File('test/fixtures/fis/sugeno.fis').readAsStringSync();
  final engine = importer.decode(source).engine;
  FuzzyEngine build(
      {Condition? condition,
      MembershipFunction? mf,
      TNorm? and,
      SNorm? or,
      TNorm? implication,
      SNorm? aggregation,
      Defuzzifier? defuzzifier,
      String name = 'temperature',
      bool twoOutputs = false}) {
    return FuzzyEngine(
        inputs: [
          FuzzyVariable(name: name, min: 0, max: 1, terms: {
            'low': mf ?? Triangle(0, 0, 1),
            'high': Triangle(0, 1, 1)
          }),
          engine.inputs[1]
        ],
        outputs: [
          engine.outputs.single,
          if (twoOutputs)
            FuzzyVariable(
                name: 'other',
                min: 0,
                max: 1,
                terms: {'low': Triangle(0, 0, 1)})
        ],
        rules: [
          FuzzyRule(
              name: 'custom label',
              when: condition ?? Term(name, 'low'),
              output: 'fan',
              term: 'low')
        ],
        operators: FuzzyOperators(
            conjunction: and ?? const Minimum(),
            disjunction: or ?? const Maximum()),
        implication: implication ?? const Minimum(),
        aggregation: aggregation ?? const Maximum(),
        defuzzifier: defuzzifier ?? const Centroid());
  }

  String export(FuzzyEngine e, {String name = 'test'}) =>
      exporter.encodeMamdani(e, name: name, acknowledgeRuntimeSettings: true);

  test('Mamdani exports canonical fields, MF parameter order and rule indices',
      () {
    final text = export(engine);
    expect(text, contains('1 1, 1 (0.8) : 1'));
    expect(text, contains('-1 2, 2 (0.4) : 2'));
    expect(text, contains('0 1, 1 (0.0) : 1'));
    final copy = importer.decode(text).engine;
    for (final x in [0.0, .25, .5, 1.0]) {
      for (final y in [0.0, .75, 1.0]) {
        final values = {'temperature': x, 'humidity': y};
        expect(copy.evaluate(values).value('fan'),
            closeTo(engine.evaluate(values).value('fan')!, 1e-12));
      }
    }
    final gaussian = export(build(mf: Gaussian(.4, .2)));
    expect(gaussian, contains("'gaussmf',[0.2 0.4]"));
  });
  test('runtime settings must be acknowledged and invalid export budgets fail',
      () {
    expect(
        () => exporter.encodeMamdani(engine,
            name: 'test', acknowledgeRuntimeSettings: false),
        throwsArgumentError);
    expect(
        () => const FisExporter(maxDepth: 0).encodeMamdani(engine,
            name: 'test', acknowledgeRuntimeSettings: true),
        throwsArgumentError);
    expect(
        () => const FisExporter(maxSourceLength: 10).encodeMamdani(engine,
            name: 'test', acknowledgeRuntimeSettings: true),
        throwsUnsupportedError);
  });
  final unsupported = <String, FuzzyEngine>{
    'mixed connectors': build(
        condition: const Term('temperature', 'low').and(
            const Term('humidity', 'low')
                .or(const Term('temperature', 'high')))),
    'repeated input': build(
        condition: const Term('temperature', 'low')
            .and(const Term('temperature', 'high'))),
    'negated group': build(
        condition: const Term('temperature', 'low')
            .and(const Term('humidity', 'low'))
            .not()),
    'hedge':
        build(condition: const Term('temperature', 'low').hedge(const Very())),
    'function': build(mf: Ramp(0, 1)),
    'AND': build(and: const BoundedDifference()),
    'OR': build(or: const BoundedSum()),
    'implication': build(implication: const BoundedDifference()),
    'aggregation': build(aggregation: const ProbabilisticSum()),
    'defuzzifier': build(defuzzifier: const Bisector()),
    'quoted name': build(name: "temp'bad"),
    'multiline name': build(name: 'temp\nbad'),
  };
  for (final entry in unsupported.entries) {
    test('rejects unrepresentable ${entry.key}',
        () => expect(() => export(entry.value), throwsUnsupportedError));
  }
  test('depth budget rejects a flat but excessively deep condition', () {
    final condition =
        const Term('temperature', 'low').and(const Term('humidity', 'low'));
    expect(
        () => const FisExporter(maxDepth: 1).encodeMamdani(
            build(condition: condition),
            name: 'test',
            acknowledgeRuntimeSettings: true),
        returnsNormally);
    expect(
        () => const FisExporter(maxDepth: 1).encodeMamdani(
            build(condition: condition.and(const Term('temperature', 'high'))),
            name: 'test',
            acknowledgeRuntimeSettings: true),
        throwsUnsupportedError);
  });
  test(
      'Sugeno mixed constant/linear results follow declared input order and intercept-last',
      () {
    final model = importer.decodeSugeno(sugeno);
    final result = model.evaluate({'temperature': .5, 'humidity': .75});
    // z1=10, z2=2*.5-4*.75+7=5; w1=.2,w2=.3.
    expect(result.value, closeTo(7, 1e-12));
    expect(result.trace.rules[1].consequentValue, 5);
    expect(model.outputMin, -10);
    expect(model.outputMax, 100);
    final sum =
        importer.decodeSugeno(sugeno.replaceFirst("'wtaver'", "'wtsum'"));
    expect(sum.evaluate({'temperature': .5, 'humidity': .75}).value,
        closeTo(3.5, 1e-12));
  });
  test('Sugeno export preserves unused named consequents, range and operators',
      () {
    final model = importer.decodeSugeno(sugeno);
    final text = exporter.encodeSugeno(model, acknowledgeRuntimeSettings: true);
    expect(text, contains("MF3='unused':'constant',[123.0]"));
    expect(text, contains("'linear',[2.0 -4.0 7.0]"));
    final copy = importer.decodeSugeno(text);
    expect(copy.consequents.keys, model.consequents.keys);
    for (final x in [0.0, .5, 1.0]) {
      for (final y in [0.0, .75, 1.0]) {
        final a = model.evaluate({'temperature': x, 'humidity': y}).value;
        final b = copy.evaluate({'temperature': x, 'humidity': y}).value;
        if (a == null) {
          expect(b, isNull);
        } else {
          expect(b, closeTo(a, 1e-12));
        }
      }
    }
  });
  test('Sugeno no-rule policies and unclamped output range', () {
    final inactive =
        sugeno.replaceAll('(0.8)', '(0)').replaceAll('(0.4)', '(0)');
    final model = FisImporter(noDecisionPolicy: FisNoDecisionPolicy.midpoint)
        .decodeSugeno(inactive);
    final result = model.evaluate({'temperature': .5, 'humidity': .75});
    expect(result.value, 45);
    expect(result.usedFallback, true);
    expect(result.trace.value('fan'), isNull);
    expect(
        () => FisImporter(noDecisionPolicy: FisNoDecisionPolicy.throwError)
            .decodeSugeno(inactive)
            .evaluate({'temperature': .5, 'humidity': .75}),
        throwsStateError);
    final outside =
        importer.decodeSugeno(sugeno.replaceFirst('[10]', '[1000]'));
    expect(outside.evaluate({'temperature': 0, 'humidity': 0}).value, 1000);
  });
  final invalid = <String, String>{
    'linear arity': sugeno.replaceFirst('[2 -4 7]', '[2 7]'),
    'constant arity': sugeno.replaceFirst('[10]', '[1 2]'),
    'nonfinite': sugeno.replaceFirst('[10]', '[1e999]'),
    'custom function': sugeno.replaceFirst("'constant',[10]", "'custom',[10]"),
    'unknown reduction': sugeno.replaceFirst("'wtaver'", "'centroid'"),
    'unknown implication':
        sugeno.replaceFirst("ImpMethod='prod'", "ImpMethod='min'"),
    'unknown aggregation':
        sugeno.replaceFirst("AggMethod='sum'", "AggMethod='max'"),
    'bad range': sugeno.replaceFirst('[-10 100]', '[100 -10]'),
    'duplicate consequent':
        sugeno.replaceFirst("MF3='unused'", "MF3='constant'"),
  };
  for (final entry in invalid.entries) {
    test(
        'Sugeno rejects ${entry.key}',
        () => expect(
            () => importer.decodeSugeno(entry.value), throwsFormatException));
  }
  test('typed decoders reject the other family', () {
    expect(() => importer.decode(sugeno), throwsFormatException);
    expect(() => importer.decodeSugeno(source), throwsFormatException);
  });
}
