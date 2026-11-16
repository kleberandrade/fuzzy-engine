import 'dart:io';
import 'dart:convert';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

void main() {
  final source = File('test/fixtures/fcl/ventilation.fcl').readAsStringSync();
  FclImporter importer({int intervals = 4}) => FclImporter(
      inputRanges: {'temperature': FclRange(0, 1), 'humidity': FclRange(0, 1)},
      intervals: intervals);
  test('independent quadrature, activation, default and original null trace',
      () {
    final model = importer().decode(source);
    final result = model.evaluate({'temperature': .5, 'humidity': .75});
    expect(result.value, closeTo(235 / 44, 1e-12));
    expect(result.trace.rules[0].strength, closeTo(.2, 1e-14));
    expect(result.trace.rules[1].strength, closeTo(.3, 1e-14));
    expect(result.usedDefault, false);
    final inactive = source
        .replaceAll('WITH 0.8', 'WITH 0')
        .replaceAll('WITH 0.4', 'WITH 0');
    final fallback = importer()
        .decode(inactive)
        .evaluate({'temperature': .5, 'humidity': .75});
    expect(fallback.value, -1);
    expect(fallback.usedDefault, true);
    expect(fallback.trace.value('fan'), isNull);
  });
  test('endpoints and overlap match recorded scikit-fuzzy numerical references',
      () {
    final model = importer(intervals: 1000).decode(source);
    final reference = jsonDecode(
        File('test/fixtures/fis/external-reference.json').readAsStringSync());
    for (final fixture in reference['cases'] as List) {
      if (fixture['family'] != 'mamdani' || fixture['variant'] != 'default') {
        continue;
      }
      final inputs = (fixture['inputs'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
      final result = model.evaluate(inputs);
      expect(
          result.value,
          closeTo(fixture['externalValue'] as num,
              fixture['crispTolerance'] as num));
      for (var i = 0; i < 2; i++) {
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
  test('tails are saturated inside explicit universe, not dropped to zero', () {
    final model = importer()
        .decode(source.replaceFirst('(0,1) (1,0)', '(0.2,0.8) (0.8,0.2)'));
    final term = model.engine.inputs.first.terms['low']!;
    expect(term.degree(0), .8);
    expect(term.degree(1), .2);
    expect(term.degree(.5), closeTo(.5, 1e-12));
  });
  test('case-insensitive keywords, multiline terms and comments', () {
    final text = source
        .replaceFirst('FUNCTION_BLOCK', 'function_block')
        .replaceFirst('IS NOT', 'is not')
        .replaceFirst('(0,1) (1,0)', '(0,1)\n(* point comment *) (1,0)');
    expect(importer().decode(text).name, 'ventilation');
  });
  final bad = <String, String>{
    'custom method': source.replaceFirst('COG', 'COGS'),
    'custom conjunction': source.replaceFirst('AND : MIN', 'AND : PROD'),
    'stateful default': source.replaceFirst('DEFAULT := -1', 'DEFAULT := NC'),
    'no range': source.replaceFirst('RANGE := (0 .. 10);', ''),
    'unknown field': source.replaceFirst('METHOD :', 'EXTRA :'),
    'invalid range': source.replaceFirst('(0 .. 10)', '(10 .. 0)'),
    'duplicate variable':
        source.replaceFirst('humidity : REAL', 'temperature : REAL'),
    'missing fuzzify':
        source.replaceFirst('FUZZIFY humidity', 'FUZZIFY missing'),
    'invalid points': source.replaceFirst('(0,1) (1,0)', '(1,1) (0,0)'),
    'duplicate points': source.replaceFirst('(0,1) (1,0)', '(0,1) (0,0)'),
    'invalid degree': source.replaceFirst('(0,1)', '(0,1.1)'),
    'outside points': source.replaceFirst('(0,1)', '(-1,1)'),
    'duplicate term': source.replaceFirst('TERM high', 'TERM low'),
    'singleton': source.replaceFirst('(0,1) (1,0)', '1'),
    'unknown term':
        source.replaceFirst('THEN fan IS low', 'THEN fan IS unknown'),
    'duplicate rule': source.replaceFirst('RULE 2', 'RULE 1'),
    'duplicate padded rule': source.replaceFirst('RULE 2', 'RULE 01'),
    'oversized rule identifier':
        source.replaceFirst('RULE 2', 'RULE 2147483648'),
    'shared input/output identifier': source.replaceAll('fan', 'temperature'),
    'weight': source.replaceFirst('WITH 0.8', 'WITH 2'),
    'empty rules': source.replaceAll(RegExp(r' RULE [^;]+;'), ''),
    'mixed connectors': source.replaceFirst(
        'THEN fan IS low', 'OR temperature IS high THEN fan IS low'),
    'trailing block': '$source FUNCTION_BLOCK second',
    'unterminated comment': '$source (*',
    'nested comment': '(* outer (* inner *) *) $source',
    'nonfinite': source.replaceFirst('WITH 0.8', 'WITH 1e999'),
    'expression': source.replaceFirst('WITH 0.8', 'WITH run(1)'),
  };
  for (final entry in bad.entries) {
    test(
        'rejects ${entry.key} with location',
        () => expect(
            () => importer().decode(entry.value),
            throwsA(isA<FormatException>()
                .having((e) => e.message, 'location', contains('line')))));
  }
  test('ranges and parser budgets are bounded explicitly', () {
    expect(() => FclRange(1, 0), throwsArgumentError);
    expect(() => FclImporter(inputRanges: {}), throwsArgumentError);
    expect(
        () =>
            FclImporter(inputRanges: {'wrong': FclRange(0, 1)}).decode(source),
        throwsFormatException);
    for (final parser in [
      FclImporter(inputRanges: {
        'temperature': FclRange(0, 1),
        'humidity': FclRange(0, 1)
      }, maxTokens: 10),
      FclImporter(inputRanges: {
        'temperature': FclRange(0, 1),
        'humidity': FclRange(0, 1)
      }, maxSourceLength: 10),
      FclImporter(inputRanges: {
        'temperature': FclRange(0, 1),
        'humidity': FclRange(0, 1)
      }, maxRules: 1),
    ]) {
      expect(() => parser.decode(source), throwsFormatException);
    }
  });
}
