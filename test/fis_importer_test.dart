import 'dart:io';
import 'dart:math' as math;

import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

void main() {
  final source = File('test/fixtures/fis/ventilation.fis').readAsStringSync();
  FisModel decode(String text,
          {FisNoDecisionPolicy policy = FisNoDecisionPolicy.preserveNull,
          int intervals = 4}) =>
      FisImporter(noDecisionPolicy: policy, intervals: intervals).decode(text);

  test('independent five-point quadrature and weighted activation reference',
      () {
    final model = decode(source);
    final result = model.evaluate({'temperature': .5, 'humidity': .75});
    expect(model.name, 'ventilation');
    expect(result.trace.memberships['temperature']!['low'], .5);
    expect(result.trace.memberships['humidity']!['low'], .25);
    expect(result.trace.rules.map((r) => r.antecedent), [.25, .75, .25]);
    expect(result.trace.rules.map((r) => r.strength),
        [closeTo(.2, 1e-14), closeTo(.3, 1e-14), 0]);
    final degrees = result.trace.outputSets['fan']!.degrees;
    // min implication, max aggregation: [.2,.25,.3,.3,.3].
    for (var i = 0; i < degrees.length; i++) {
      expect(degrees[i], closeTo([.2, .25, .3, .3, .3][i], 1e-14));
    }
    // Trapezoidal area = 2.75, first moment = 14.6875.
    expect(result.value, closeTo(235 / 44, 1e-12));
    expect(result.usedFallback, isFalse);
  });

  test('product AND, probabilistic OR and product implication', () {
    final model = decode(source
        .replaceFirst("AndMethod='min'", "AndMethod='prod'")
        .replaceFirst("OrMethod='max'", "OrMethod='probor'")
        .replaceFirst("ImpMethod='min'", "ImpMethod='prod'"));
    final result = model.evaluate({'temperature': .5, 'humidity': .75});
    expect(result.trace.rules[0].antecedent, .125);
    expect(result.trace.rules[1].antecedent, .875);
    expect(result.trace.rules[0].strength, .1);
    expect(result.trace.rules[1].strength, closeTo(.35, 1e-15));
    expect(result.trace.outputSets['fan']!.degrees[2], closeTo(.175, 1e-15));
  });

  test(
      'Gaussian FIS [sigma center] maps to mean/sigma without swapping meaning',
      () {
    final model =
        decode(source.replaceFirst("'trimf',[0 0 1]", "'gaussmf',[0.2 0.5]"));
    final mf = model.engine.inputs.first.terms['low']! as Gaussian;
    expect(mf.mean, .5);
    expect(mf.sigma, .2);
    expect(mf.degree(.5), 1);
    expect(mf.degree(.7), closeTo(math.exp(-.5), 1e-14));
  });

  test('ignored input stays absent from condition; weight zero skips decision',
      () {
    final model = decode(source);
    expect(model.engine.rules[2].when.references.map((t) => t.variable),
        ['humidity']);
    expect(
        model
            .evaluate({'temperature': 0, 'humidity': 0})
            .trace
            .rules[2]
            .strength,
        0);
  });

  test('both input endpoints retain exact shoulder memberships', () {
    for (final value in [0.0, 1.0]) {
      final result =
          decode(source).evaluate({'temperature': value, 'humidity': value});
      for (final name in ['temperature', 'humidity']) {
        expect(result.trace.memberships[name]!['low'], 1 - value);
        expect(result.trace.memberships[name]!['high'], value);
      }
    }
  });

  final inactive = source.replaceAll('(0.8)', '(0)').replaceAll('(0.4)', '(0)');
  test('null policy and midpoint policy keep the raw null explanation', () {
    final raw = decode(inactive).evaluate({'temperature': .5, 'humidity': .5});
    expect(raw.value, isNull);
    expect(raw.usedFallback, isFalse);
    final adapted = decode(inactive, policy: FisNoDecisionPolicy.midpoint)
        .evaluate({'temperature': .5, 'humidity': .5});
    expect(adapted.value, 5);
    expect(adapted.usedFallback, isTrue);
    expect(adapted.trace.value('fan'), isNull);
  });

  test('throw policy fails on zero sampled area', () {
    expect(
        () => decode(inactive, policy: FisNoDecisionPolicy.throwError)
            .evaluate({'temperature': .5, 'humidity': .5}),
        throwsStateError);
  });

  test('active rule with unsampled narrow output uses explicit fallback too',
      () {
    final text = source
        .replaceFirst("'trimf',[0 0 10]", "'trimf',[1 1.1 1.2]")
        .replaceFirst('(0.4)', '(0)');
    final result = decode(text, policy: FisNoDecisionPolicy.midpoint)
        .evaluate({'temperature': 0, 'humidity': 0});
    expect(result.trace.rules.first.strength, .8);
    expect(result.value, 5);
    expect(result.usedFallback, isTrue);
  });

  test('comments outside quotes, CRLF and optional Version', () {
    final text = source
        .replaceFirst("Name='ventilation'", "Name='fan%controller' % note")
        .replaceFirst('Version=2.0\n', '')
        .replaceAll('\n', '\r\n');
    expect(decode(text).name, 'fan%controller');
  });

  final invalid = <String, String>{
    'unknown field': source.replaceFirst('NumInputs=2', 'Extra=1\nNumInputs=2'),
    'duplicate field':
        source.replaceFirst('NumInputs=2', 'NumInputs=2\nNumInputs=2'),
    'duplicate section': '$source\n[System]\n',
    'missing section': source.replaceFirst('[Input2]', '[Input3]'),
    'unknown section': '$source\n[Unexpected]\n',
    'Sugeno': source.replaceFirst("Type='mamdani'", "Type='sugeno'"),
    'wrong version': source.replaceFirst('Version=2.0', 'Version=3'),
    'missing declared second output':
        source.replaceFirst('NumOutputs=1', 'NumOutputs=2'),
    'unknown membership': source
        .replaceFirst("'gaussmf'", "'unsupported'")
        .replaceFirst("'trimf'", "'unsupported'"),
    'wrong parameter count': source.replaceFirst('[0 0 1]', '[0 1]'),
    'nonfinite parameter': source.replaceFirst('[0 0 1]', '[0 0 1e999]'),
    'invalid triangle': source.replaceFirst('[0 0 1]', '[1 0 0]'),
    'invalid Gaussian':
        source.replaceFirst("'trimf',[0 0 1]", "'gaussmf',[0 0.5]"),
    'unknown conjunction':
        source.replaceFirst("AndMethod='min'", "AndMethod='custom'"),
    'unsupported aggregation':
        source.replaceFirst("AggMethod='max'", "AggMethod='sum'"),
    'unsupported defuzzifier':
        source.replaceFirst("DefuzzMethod='centroid'", "DefuzzMethod='mom'"),
    'all ignored inputs': source.replaceFirst('1 1,', '0 0,'),
    'unknown input index': source.replaceFirst('1 1,', '3 1,'),
    'minimum signed input index':
        source.replaceFirst('1 1,', '-9223372036854775808 1,'),
    'fractional input index': source.replaceFirst('1 1,', '1.5 1,'),
    'unknown output index': source.replaceFirst('1 1, 1', '1 1, 3'),
    'negated output': source.replaceFirst('1 1, 1', '1 1, -1'),
    'missing output': source.replaceFirst('1 1, 1', '1 1, 0'),
    'weight outside range': source.replaceFirst('(0.8)', '(1.1)'),
    'invalid connector': source.replaceFirst(': 1\n', ': 3\n'),
    'rule count mismatch': source.replaceFirst('NumRules=3', 'NumRules=2'),
    'duplicate variable':
        source.replaceFirst("Name='humidity'", "Name='temperature'"),
    'duplicate membership': source.replaceFirst("MF2='high'", "MF2='low'"),
    'unknown MF field': source.replaceFirst('MF2=', 'MF3='),
    'invalid range': source.replaceFirst('Range=[0 1]', 'Range=[1 0]'),
    'empty quoted name': source.replaceFirst("Name='temperature'", "Name=''"),
    'expression execution': source.replaceFirst('[0 0 1]', '[0 0 system(1)]'),
  };
  for (final entry in invalid.entries) {
    test('rejects ${entry.key} with a source line', () {
      expect(
          () => decode(entry.value),
          throwsA(isA<FormatException>()
              .having((e) => e.message, 'location', contains('line '))));
    });
  }

  test(
      'source and allocation budgets are checked before constructing the engine',
      () {
    for (final importer in [
      FisImporter(
          noDecisionPolicy: FisNoDecisionPolicy.preserveNull,
          maxSourceLength: 10),
      FisImporter(
          noDecisionPolicy: FisNoDecisionPolicy.preserveNull, maxInputs: 1),
      FisImporter(
          noDecisionPolicy: FisNoDecisionPolicy.preserveNull, maxRules: 2),
      FisImporter(
          noDecisionPolicy: FisNoDecisionPolicy.preserveNull,
          maxMembershipsPerVariable: 1),
    ]) {
      expect(() => importer.decode(source), throwsFormatException);
    }
    expect(
        () => FisImporter(
            noDecisionPolicy: FisNoDecisionPolicy.preserveNull,
            intervals: 1000001),
        throwsArgumentError);
  });

  test('imported models retain normal runtime input validation', () {
    final model = decode(source);
    expect(() => model.evaluate({'temperature': 2, 'humidity': .5}),
        throwsArgumentError);
    expect(() => model.evaluate({'temperature': .5}), throwsArgumentError);
  });
}
