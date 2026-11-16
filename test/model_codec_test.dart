import 'dart:convert';
import 'dart:io';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

FuzzyEngine mamdani(
        {Map<String, MembershipFunction>? shapes,
        Defuzzifier defuzzifier = const Centroid(),
        FuzzyOperators operators = const FuzzyOperators(),
        TNorm implication = const Minimum(),
        SNorm aggregation = const Maximum()}) =>
    FuzzyEngine(
        inputs: [
          FuzzyVariable(
              name: 'x',
              min: 0,
              max: 10,
              terms: shapes ?? {'low': Ramp(10, 0), 'high': Ramp(0, 10)})
        ],
        outputs: [
          FuzzyVariable(
              name: 'y',
              min: 0,
              max: 10,
              terms: {'low': ZShape(0, 10), 'high': SShape(0, 10)})
        ],
        rules: [
          FuzzyRule(
              name: 'r1',
              when: const Term('x', 'low')
                  .hedge(const Very())
                  .or(const Term('x', 'high').not()),
              output: 'y',
              term: 'low',
              weight: .8),
          FuzzyRule(
              name: 'r2',
              when: const Term('x', 'high')
                  .and(const Term('x', 'low').not())
                  .hedge(const Somewhat()),
              output: 'y',
              term: 'high'),
        ],
        intervals: 20,
        defuzzifier: defuzzifier,
        operators: operators,
        implication: implication,
        aggregation: aggregation);
SugenoEngine sugeno(SugenoAggregation method) => SugenoEngine(
    inputs: mamdani().inputs,
    outputs: [SugenoOutput('y')],
    aggregation: method,
    operators: const FuzzyOperators(
        conjunction: AlgebraicProduct(), disjunction: BoundedSum()),
    rules: [
      SugenoRule(
          name: 'r1',
          when: const Term('x', 'low'),
          output: 'y',
          consequent: ConstantConsequent(-10)),
      SugenoRule(
          name: 'r2',
          when: const Term('x', 'high').hedge(const Very()),
          output: 'y',
          consequent: LinearConsequent(intercept: 2, coefficients: {'x': 3}),
          weight: .7),
    ]);
Map<String, dynamic> editable(Object model) =>
    jsonDecode(FuzzyModelCodec().encode(model)) as Map<String, dynamic>;

void main() {
  test('independent Mamdani v1 fixture agrees with an analytic ramp centroid',
      () {
    final e = FuzzyModelCodec().decodeMamdani(
        File('test/fixtures/mamdani-v1.json').readAsStringSync());
    expect(e.evaluate({'x': .5}).value('y'), closeTo(10 / 3, 1e-5));
  });
  test('independent Sugeno v1 fixture agrees with weighted arithmetic', () {
    final text = File('test/fixtures/sugeno-v1.json').readAsStringSync();
    final e = FuzzyModelCodec().decodeSugeno(text);
    expect(
        e.evaluate({'temperature': 10}).value('fan'), closeTo(200 / 7, 1e-12));
    expect(FuzzyModelCodec().decode(text).inputUnits['temperature'], '°C');
  });
  test(
      'Mamdani round-trip preserves configuration, condition trees, curves and decisions',
      () {
    final original = mamdani();
    final codec = FuzzyModelCodec();
    final copy = codec.decodeMamdani(codec.encode(original));
    expect(codec.toJson(copy), codec.toJson(original));
    for (var i = 0; i <= 10; i++) {
      final a = original.evaluate({'x': i.toDouble()}),
          b = copy.evaluate({'x': i.toDouble()});
      expect(b.outputs, a.outputs);
      expect(b.memberships, a.memberships);
      expect(b.outputSets['y']!.degrees, a.outputSets['y']!.degrees);
      expect(b.rules.map((r) => r.strength), a.rules.map((r) => r.strength));
    }
  });
  for (final method in SugenoAggregation.values) {
    test(
        '$method round-trip preserves constants, coefficients and numeric decisions',
        () {
      final original = sugeno(method);
      final codec = FuzzyModelCodec();
      final copy = codec.decodeSugeno(codec.encode(original));
      expect(codec.toJson(copy), codec.toJson(original));
      for (var i = 0; i <= 10; i++) {
        final a = original.evaluate({'x': i.toDouble()}),
            b = copy.evaluate({'x': i.toDouble()});
        expect(b.outputs, a.outputs);
        expect(b.totalWeights, a.totalWeights);
        expect(b.rules.map((r) => r.consequentValue),
            a.rules.map((r) => r.consequentValue));
      }
    });
  }
  test('all eleven membership functions preserve degrees through interchange',
      () {
    final shapes = <String, MembershipFunction>{
      'low': Ramp(10, 0),
      'high': Ramp(0, 10),
      'triangle': Triangle(0, 5, 10),
      'trapezoid': Trapezoid(0, 2, 8, 10),
      'gaussian': Gaussian(5, 2),
      'sigmoid': Sigmoid(5, -.3),
      'bell': Bell(5, 2, 3),
      's': SShape(1, 9),
      'z': ZShape(1, 9),
      'pi': PiShape(0, 3, 7, 10),
      'rectangle': Rectangle(2, 8),
      'discrete': DiscreteSet([
        MembershipPoint(0, 0),
        MembershipPoint(3, 1),
        MembershipPoint(10, .2)
      ])
    };
    final original = mamdani(shapes: shapes);
    final codec = FuzzyModelCodec();
    final copy = codec.decodeMamdani(codec.encode(original));
    for (final name in shapes.keys) {
      for (var i = 0; i <= 100; i++)
        expect(copy.inputs.single.terms[name]!.degree(i / 10),
            shapes[name]!.degree(i / 10));
    }
  });
  for (final defuzzifier in <Defuzzifier>[
    const Centroid(),
    const Bisector(),
    SmallestOfMaximum(tolerance: .01),
    LargestOfMaximum(tolerance: .02),
    MeanOfMaximum(tolerance: .03)
  ]) {
    test('${defuzzifier.runtimeType} round-trip preserves parameters', () {
      final codec = FuzzyModelCodec(),
          original = mamdani(defuzzifier: defuzzifier);
      final copy = codec.decodeMamdani(codec.encode(original));
      expect(codec.toJson(copy), codec.toJson(original));
      expect(
          copy.evaluate({'x': 3}).outputs, original.evaluate({'x': 3}).outputs);
    });
  }
  test('all norm choices preserve inference settings', () {
    final codec = FuzzyModelCodec();
    for (final t in <TNorm>[
      const Minimum(),
      const AlgebraicProduct(),
      const BoundedDifference()
    ]) {
      for (final s in <SNorm>[
        const Maximum(),
        const ProbabilisticSum(),
        const BoundedSum()
      ]) {
        final original = mamdani(
            operators: FuzzyOperators(conjunction: t, disjunction: s),
            implication: t,
            aggregation: s);
        final copy = codec.decodeMamdani(codec.encode(original));
        expect(codec.toJson(copy), codec.toJson(original));
        expect(copy.evaluate({'x': 3}).outputs,
            original.evaluate({'x': 3}).outputs);
      }
    }
  });
  test('metadata, unit labels and model names survive document round-trips',
      () {
    final units = {'x': '°C'};
    final document = FuzzyModelDocument(
        engine: mamdani(),
        name: 'Example',
        description: 'Descrição bilíngue',
        inputUnits: units,
        outputUnits: {'y': '%'});
    units['x'] = 'changed';
    final codec = FuzzyModelCodec(),
        copy = FuzzyModelCodec().decode(FuzzyModelCodec().encode(document));
    expect(copy.name, 'Example');
    expect(copy.description, 'Descrição bilíngue');
    expect(copy.inputUnits, {'x': '°C'});
    expect(copy.outputUnits, {'y': '%'});
    expect(() => copy.inputUnits.clear(), throwsUnsupportedError);
    final exported = codec.toJson(document);
    ((exported['metadata'] as Map)['inputUnits'] as Map)['x'] = 'K';
    expect(document.inputUnits['x'], '°C');
    expect(
        () =>
            FuzzyModelDocument(engine: mamdani(), inputUnits: {'missing': 'm'}),
        throwsArgumentError);
    expect(() => FuzzyModelDocument(engine: mamdani(), outputUnits: {'y': ' '}),
        throwsArgumentError);
    expect(() => FuzzyModelDocument(engine: Object()), throwsArgumentError);
  });
  test('wrong engine family and unsupported version are rejected', () {
    final codec = FuzzyModelCodec();
    expect(() => codec.decodeSugeno(codec.encode(mamdani())),
        throwsFormatException);
    expect(
        () => codec.decodeMamdani(
            codec.encode(sugeno(SugenoAggregation.weightedAverage))),
        throwsFormatException);
    for (final version in [null, 0, 3, 1.1, '1', true]) {
      final raw = editable(mamdani())..['schemaVersion'] = version;
      expect(() => codec.decode(jsonEncode(raw)), throwsFormatException);
    }
  });
  test(
      'unknown fields, discriminator values and malformed payloads are rejected',
      () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (m) => m['typo'] = 1,
      (m) => m.remove('rules'),
      (m) => m['engineType'] = 'dart.execute',
      (m) => (m['settings'] as Map)['intervals'] = 20.5,
      (m) => (m['settings'] as Map)['intervals'] = true,
      (m) => (m['operators'] as Map)['conjunction'] = 'eval(1)',
      (m) => (m['operators'] as Map)['negation'] = 'unknown',
      (m) => (m['inputs'][0] as Map)['terms']['low']['type'] = 'custom',
      (m) => (m['inputs'][0] as Map)['terms']['low']['parameters'] = [0],
      (m) => (m['inputs'][0] as Map)['terms']['low']['parameters'] = [0, 'ten'],
      (m) => (m['rules'][0] as Map)['when']['type'] = 'execute',
      (m) => (m['rules'][0] as Map)['weight'] = -1,
      (m) => (m['rules'][0] as Map)['output'] = 'missing',
      (m) => (m['inputs'][0] as Map)['min'] = 100,
      (m) => (m['metadata'] as Map)['inputUnits'] = {'missing': 'm'},
    ];
    for (final mutate in mutations) {
      final raw = editable(mamdani());
      mutate(raw);
      expect(() => FuzzyModelCodec().decode(jsonEncode(raw)),
          throwsFormatException);
    }
    for (final text in ['null', '[]', '{', '42', '"code"']) {
      expect(() => FuzzyModelCodec().decode(text), throwsFormatException);
    }
  });
  test('nonfinite direct JSON values and cyclic structures are rejected', () {
    final raw = editable(mamdani());
    raw['inputs'][0]['min'] = double.nan;
    expect(() => FuzzyModelCodec().fromJson(raw), throwsFormatException);
    final cycle = <String, Object?>{};
    cycle['self'] = cycle;
    expect(() => FuzzyModelCodec(maxDepth: 5).fromJson(cycle),
        throwsFormatException);
    expect(() => FuzzyModelCodec().decode('{"schemaVersion":1e999}'),
        throwsFormatException);
  });
  test('resource limits apply before model construction', () {
    final codec = FuzzyModelCodec(), json = FuzzyModelCodec().encode(mamdani());
    expect(() => FuzzyModelCodec(maxSourceLength: json.length - 1).decode(json),
        throwsFormatException);
    expect(() => FuzzyModelCodec(maxSourceLength: 5).encode(mamdani()),
        throwsFormatException);
    expect(() => FuzzyModelCodec(maxNodes: 10).decode(json),
        throwsFormatException);
    expect(
        () => FuzzyModelCodec(maxDepth: 2).decode(json), throwsFormatException);
    expect(() => FuzzyModelCodec(maxNodes: 10).toJson(mamdani()),
        throwsFormatException);
    expect(() => FuzzyModelCodec(maxDepth: 0), throwsArgumentError);
    expect(() => FuzzyModelCodec(maxOutputSamples: 2), throwsArgumentError);
    expect(() => FuzzyModelCodec(maxOutputSamples: 10).decode(json),
        throwsFormatException);
    expect(() => FuzzyModelCodec(maxOutputSamples: 10).encode(mamdani()),
        throwsFormatException);
    final integralNumbers = editable(mamdani())..['schemaVersion'] = 1.0;
    (integralNumbers['settings'] as Map)['intervals'] = 20.0;
    expect(codec.decodeMamdani(jsonEncode(integralNumbers)).intervals, 20);
    var condition = const Term('x', 'low') as Condition;
    for (var i = 0; i < 10; i++) {
      condition = condition.not();
    }
    expect(() => FuzzyModelCodec(maxDepth: 5).conditionToJson(condition),
        throwsFormatException);
    expect(codec.decode(json).engine, isA<FuzzyEngine>());
  });
  test('custom callbacks never silently degrade into serialized built-ins', () {
    expect(
        () => FuzzyModelCodec().encode(
            mamdani(shapes: {'low': CustomMembership(), 'high': Ramp(0, 10)})),
        throwsUnsupportedError);
    expect(
        () =>
            FuzzyModelCodec().encode(mamdani(defuzzifier: CustomDefuzzifier())),
        throwsUnsupportedError);
    expect(() => FuzzyModelCodec().encode(mamdani(implication: CustomNorm())),
        throwsUnsupportedError);
    expect(() => FuzzyModelCodec().encode(mamdani(aggregation: CustomNorm())),
        throwsUnsupportedError);
    expect(
        () => FuzzyModelCodec().encode(
            mamdani(operators: FuzzyOperators(negation: CustomNegation()))),
        throwsUnsupportedError);
    expect(
        () => FuzzyModelCodec()
            .conditionToJson(const Term('x', 'low').hedge(CustomHedge())),
        throwsUnsupportedError);
    expect(() => FuzzyModelCodec().consequentToJson(CustomConsequent()),
        throwsUnsupportedError);
  });
  test(
      'standalone condition interchange preserves nested references and evaluation',
      () {
    final codec = FuzzyModelCodec();
    final c = const Term('x', 'a')
        .and(const Term('x', 'b').not())
        .or(const Term('x', 'c').hedge(const Very()));
    final restored = codec.conditionFromJson(codec.conditionToJson(c));
    final values = {
      'x': {'a': .7, 'b': .2, 'c': .3}
    };
    expect(restored.evaluate(values), c.evaluate(values));
    expect(restored.references.map((t) => t.term), ['a', 'b', 'c']);
  });
}

class CustomMembership implements MembershipFunction {
  @override
  double degree(double x) => .5;
}

class CustomDefuzzifier implements Defuzzifier {
  @override
  double? defuzzify(SampledFuzzySet output) => output.min;
}

class CustomNorm implements TNorm, SNorm {
  @override
  double combine(double a, double b) => a * b;
}

class CustomNegation implements FuzzyNegation {
  @override
  double complement(double value) => 1 - value;
}

class CustomHedge implements FuzzyHedge {
  @override
  double transform(double degree) => degree;
}

class CustomConsequent implements SugenoConsequent {
  @override
  Iterable<String> get references => const [];
  @override
  double evaluate(Map<String, double> inputs) => 1;
}
