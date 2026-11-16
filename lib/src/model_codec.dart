import 'dart:convert';
import 'engine.dart';
import 'model.dart';
import 'membership.dart';
import 'operators.dart';
import 'defuzzification.dart';
import 'hedges.dart';
import 'sugeno.dart';

/// Model plus optional descriptive labels. Units are metadata, not conversions.
final class FuzzyModelDocument {
  /// Copies metadata and validates that unit names reference declared variables.
  FuzzyModelDocument(
      {required this.engine,
      this.name,
      this.description,
      Map<String, String> inputUnits = const {},
      Map<String, String> outputUnits = const {}})
      : inputUnits = Map.unmodifiable(inputUnits),
        outputUnits = Map.unmodifiable(outputUnits) {
    final model = engine;
    final List<String> inputs, outputs;
    if (model is FuzzyEngine) {
      inputs = model.inputs.map((v) => v.name).toList();
      outputs = model.outputs.map((v) => v.name).toList();
    } else if (model is SugenoEngine) {
      inputs = model.inputs.map((v) => v.name).toList();
      outputs = model.outputs.map((v) => v.name).toList();
    } else {
      throw ArgumentError('Expected a Mamdani or Sugeno engine.');
    }
    if (name != null && name!.trim().isEmpty)
      throw ArgumentError('Model name must not be blank.');
    for (final pair in [(inputUnits, inputs), (outputUnits, outputs)]) {
      if (pair.$1.entries
          .any((e) => !pair.$2.contains(e.key) || e.value.trim().isEmpty)) {
        throw ArgumentError(
            'Units must name declared variables and have nonempty labels.');
      }
    }
  }

  /// FuzzyEngine or SugenoEngine; custom engine types are not supported.
  final Object engine;

  /// Optional descriptive model name.
  final String? name;

  /// Optional free-form description; never executed.
  final String? description;

  /// Immutable input unit labels.
  final Map<String, String> inputUnits;

  /// Immutable output unit labels.
  final Map<String, String> outputUnits;
}

/// Strict, versioned JSON interchange for built-in Mamdani and Sugeno models.
/// Unknown versions, keys and component types are rejected. No code is evaluated.
final class FuzzyModelCodec {
  /// Limits apply to both imports and exports. String length uses UTF-16 units.
  FuzzyModelCodec(
      {this.maxDepth = 64,
      this.maxNodes = 10000,
      this.maxSourceLength = 1000000,
      this.maxOutputSamples = 1000000}) {
    if (maxDepth < 1 ||
        maxNodes < 1 ||
        maxSourceLength < 1 ||
        maxOutputSamples < 3)
      throw ArgumentError('Codec limits must be positive.');
  }

  /// Maximum nested JSON/condition depth.
  final int maxDepth;

  /// Maximum JSON nodes, counting values and containers.
  final int maxNodes;

  /// Maximum encoded string length in UTF-16 code units.
  final int maxSourceLength;

  /// Maximum total Mamdani output samples per evaluation, across all outputs.
  final int maxOutputSamples;

  /// Current interchange schema version.
  static const schemaVersion = 1;

  /// Encodes an engine or FuzzyModelDocument to JSON text.
  String encode(Object model) {
    final text = jsonEncode(toJson(model));
    if (text.length > maxSourceLength)
      throw const FormatException('Model exceeds source length limit.');
    return text;
  }

  /// Decodes JSON text and retains metadata.
  FuzzyModelDocument decode(String source) {
    if (source.length > maxSourceLength)
      throw const FormatException('Model exceeds source length limit.');
    final raw = jsonDecode(source);
    _guard(raw);
    return fromJson(_object(raw, r'$'));
  }

  /// Typed import; use decode when unit labels and descriptions must be retained.
  FuzzyEngine decodeMamdani(String source) {
    final model = decode(source).engine;
    if (model is! FuzzyEngine)
      throw const FormatException('Expected a Mamdani model.');
    return model;
  }

  /// Typed import; use decode when unit labels and descriptions must be retained.
  SugenoEngine decodeSugeno(String source) {
    final model = decode(source).engine;
    if (model is! SugenoEngine)
      throw const FormatException('Expected a Sugeno model.');
    return model;
  }

  /// Exports a fresh JSON-compatible map. Custom components throw UnsupportedError.
  Map<String, Object?> toJson(Object model) {
    final document =
        model is FuzzyModelDocument ? model : FuzzyModelDocument(engine: model);
    final engine = document.engine;
    final result = <String, Object?>{
      'schemaVersion': schemaVersion,
      'engineType': engine is FuzzyEngine ? 'mamdani' : 'sugeno',
      'metadata': {
        'name': document.name,
        'description': document.description,
        'inputUnits': Map<String, String>.of(document.inputUnits),
        'outputUnits': Map<String, String>.of(document.outputUnits)
      },
    };
    final FuzzyOperators operators;
    if (engine is FuzzyEngine) {
      _sampleBudget(engine.intervals, engine.outputs.length);
      operators = engine.operators;
      result.addAll({
        'inputs': engine.inputs.map(_variableJson).toList(),
        'outputs': engine.outputs.map(_variableJson).toList(),
        'rules': [
          for (final r in engine.rules)
            {
              'name': r.name,
              'when': conditionToJson(r.when),
              'output': r.output,
              'term': r.term,
              'weight': r.weight
            }
        ],
        'settings': {
          'intervals': engine.intervals,
          'implication': _tNormName(engine.implication),
          'aggregation': _sNormName(engine.aggregation),
          'defuzzifier': _defuzzifierJson(engine.defuzzifier)
        }
      });
    } else if (engine is SugenoEngine) {
      operators = engine.operators;
      result.addAll({
        'inputs': engine.inputs.map(_variableJson).toList(),
        'outputs': [
          for (final o in engine.outputs) {'name': o.name}
        ],
        'rules': [
          for (final r in engine.rules)
            {
              'name': r.name,
              'when': conditionToJson(r.when),
              'output': r.output,
              'consequent': consequentToJson(r.consequent),
              'weight': r.weight
            }
        ],
        'settings': {'aggregation': engine.aggregation.name}
      });
    } else {
      throw ArgumentError('Unsupported engine.');
    }
    if (operators.negation is! StandardNegation)
      throw UnsupportedError('Custom negation is not serializable.');
    result['operators'] = {
      'conjunction': _tNormName(operators.conjunction),
      'disjunction': _sNormName(operators.disjunction),
      'negation': 'standard'
    };
    _guard(result);
    return result;
  }

  /// Imports a JSON map with the same validation as a text import.
  FuzzyModelDocument fromJson(Map<String, Object?> source) {
    _guard(source);
    try {
      _keys(
          source,
          [
            'schemaVersion',
            'engineType',
            'metadata',
            'inputs',
            'outputs',
            'rules',
            'operators',
            'settings'
          ],
          r'$');
      if (source['schemaVersion'] is! num ||
          source['schemaVersion'] != schemaVersion)
        throw const FormatException(r'$.schemaVersion: unsupported version.');
      final type = _string(source['engineType'], r'$.engineType');
      if (type != 'mamdani' && type != 'sugeno')
        throw const FormatException(r'$.engineType: unsupported engine.');
      final operators = _object(source['operators'], r'$.operators');
      _keys(operators, ['conjunction', 'disjunction', 'negation'],
          r'$.operators');
      if (operators['negation'] != 'standard')
        throw const FormatException(r'$.operators.negation: unsupported type.');
      final ops = FuzzyOperators(
          conjunction: _tNorm(operators['conjunction']),
          disjunction: _sNorm(operators['disjunction']));
      final inputs =
          _list(source['inputs'], r'$.inputs').map(_variable).toList();
      final settings = _object(source['settings'], r'$.settings');
      final ruleMaps = _list(source['rules'], r'$.rules')
          .map((r) => _object(r, 'rule'))
          .toList();
      final Object engine;
      if (type == 'mamdani') {
        _keys(
            settings,
            ['intervals', 'implication', 'aggregation', 'defuzzifier'],
            r'$.settings');
        final rawIntervals = settings['intervals'];
        if (rawIntervals is! num ||
            !rawIntervals.isFinite ||
            rawIntervals < 2 ||
            rawIntervals > maxOutputSamples - 1 ||
            rawIntervals != rawIntervals.truncateToDouble()) {
          throw const FormatException(
              r'$.settings.intervals: expected integer within output sample budget.');
        }
        final intervals = rawIntervals.toInt();
        final outputVariables =
            _list(source['outputs'], r'$.outputs').map(_variable).toList();
        _sampleBudget(intervals, outputVariables.length);
        engine = FuzzyEngine(
            inputs: inputs,
            outputs: outputVariables,
            operators: ops,
            intervals: intervals,
            implication: _tNorm(settings['implication']),
            aggregation: _sNorm(settings['aggregation']),
            defuzzifier: _defuzzifier(settings['defuzzifier']),
            rules: [for (final r in ruleMaps) _mamdaniRule(r)]);
      } else {
        _keys(settings, ['aggregation'], r'$.settings');
        final method = switch (settings['aggregation']) {
          'weightedAverage' => SugenoAggregation.weightedAverage,
          'weightedSum' => SugenoAggregation.weightedSum,
          _ => throw const FormatException(
              r'$.settings.aggregation: unsupported Sugeno method.'),
        };
        engine = SugenoEngine(
            inputs: inputs,
            operators: ops,
            aggregation: method,
            outputs: [
              for (final value in _list(source['outputs'], r'$.outputs'))
                _sugenoOutput(value)
            ],
            rules: [
              for (final r in ruleMaps) _sugenoRule(r)
            ]);
      }
      final metadata = _object(source['metadata'], r'$.metadata');
      _keys(metadata, ['name', 'description', 'inputUnits', 'outputUnits'],
          r'$.metadata');
      return FuzzyModelDocument(
          engine: engine,
          name: _optionalString(metadata['name'], 'metadata.name'),
          description:
              _optionalString(metadata['description'], 'metadata.description'),
          inputUnits: _units(metadata['inputUnits']),
          outputUnits: _units(metadata['outputUnits']));
    } on ArgumentError catch (error) {
      throw FormatException(
          'Invalid model parameters or references: ${error.message}');
    }
  }

  /// Exports an inspectable condition tree; also used for structural diagnostics.
  Map<String, Object?> conditionToJson(Condition condition) {
    final visitor = _ConditionWriter(maxDepth, maxNodes);
    final result = visitor.write(condition);
    _guard(result);
    return result;
  }

  /// Imports a standalone condition tree without evaluating code.
  Condition conditionFromJson(Map<String, Object?> source) {
    _guard(source);
    return _condition(source);
  }

  /// Exports a built-in crisp consequent; custom Dart callbacks are not exported.
  Map<String, Object?> consequentToJson(SugenoConsequent consequent) {
    if (consequent is ConstantConsequent)
      return {'type': 'constant', 'value': consequent.value};
    if (consequent is LinearConsequent)
      return {
        'type': 'linear',
        'intercept': consequent.intercept,
        'coefficients': Map<String, double>.of(consequent.coefficients)
      };
    throw UnsupportedError('Custom Sugeno consequent is not serializable.');
  }

  void _sampleBudget(int intervals, int outputs) {
    if (outputs > 0 && intervals + 1 > maxOutputSamples ~/ outputs) {
      throw const FormatException(
          'Model exceeds Mamdani output sample budget.');
    }
  }

  void _guard(Object? value) {
    final stack = <(Object?, int)>[(value, 0)];
    var count = 0;
    while (stack.isNotEmpty) {
      final (current, depth) = stack.removeLast();
      if (++count > maxNodes || depth > maxDepth)
        throw const FormatException('Model exceeds JSON node/depth limit.');
      if (current is Map) {
        if (count + stack.length + current.length > maxNodes)
          throw const FormatException('Model exceeds JSON node limit.');
        for (final entry in current.entries) {
          if (entry.key is! String)
            throw const FormatException('JSON object keys must be strings.');
          stack.add((entry.value, depth + 1));
        }
      } else if (current is List) {
        if (count + stack.length + current.length > maxNodes)
          throw const FormatException('Model exceeds JSON node limit.');
        for (final element in current) {
          stack.add((element, depth + 1));
        }
      } else if (current is num) {
        if (!current.isFinite)
          throw const FormatException('JSON numbers must be finite.');
      } else if (current != null && current is! String && current is! bool) {
        throw const FormatException('Unsupported JSON value.');
      }
    }
  }
}

Map<String, Object?> _object(Object? raw, String path) {
  if (raw is! Map || raw.keys.any((key) => key is! String))
    throw FormatException('$path: expected object.');
  return Map<String, Object?>.from(raw);
}

List<Object?> _list(Object? raw, String path) {
  if (raw is! List) throw FormatException('$path: expected array.');
  return List<Object?>.from(raw);
}

String _string(Object? raw, String path) {
  if (raw is! String || raw.trim().isEmpty)
    throw FormatException('$path: expected nonempty string.');
  return raw;
}

String? _optionalString(Object? raw, String path) {
  if (raw != null && raw is! String)
    throw FormatException('$path: expected string or null.');
  return raw as String?;
}

double _number(Object? raw, String path) {
  if (raw is! num || !raw.isFinite)
    throw FormatException('$path: expected finite number.');
  return raw.toDouble();
}

void _keys(Map<String, Object?> map, List<String> keys, String path) {
  if (map.length != keys.length || keys.any((key) => !map.containsKey(key)))
    throw FormatException('$path: missing or unknown fields.');
}

Map<String, String> _units(Object? raw) => _object(raw, 'units')
    .map((key, value) => MapEntry(key, _string(value, 'units.$key')));

Map<String, Object?> _variableJson(FuzzyVariable variable) => {
      'name': variable.name,
      'min': variable.min,
      'max': variable.max,
      'terms': variable.terms
          .map((name, function) => MapEntry(name, _membershipJson(function)))
    };
FuzzyVariable _variable(Object? raw) {
  final map = _object(raw, 'variable');
  _keys(map, ['name', 'min', 'max', 'terms'], 'variable');
  return FuzzyVariable(
      name: _string(map['name'], 'variable.name'),
      min: _number(map['min'], 'variable.min'),
      max: _number(map['max'], 'variable.max'),
      terms: _object(map['terms'], 'variable.terms')
          .map((name, value) => MapEntry(name, _membership(value))));
}

Map<String, Object?> _membershipJson(MembershipFunction f) {
  final String type;
  final List<Object?> parameters;
  if (f is Triangle) {
    type = 'triangle';
    parameters = [f.a, f.b, f.c];
  } else if (f is Trapezoid) {
    type = 'trapezoid';
    parameters = [f.a, f.b, f.c, f.d];
  } else if (f is Gaussian) {
    type = 'gaussian';
    parameters = [f.mean, f.sigma];
  } else if (f is Ramp) {
    type = 'ramp';
    parameters = [f.start, f.end];
  } else if (f is Sigmoid) {
    type = 'sigmoid';
    parameters = [f.midpoint, f.slope];
  } else if (f is Bell) {
    type = 'bell';
    parameters = [f.center, f.width, f.slope];
  } else if (f is SShape) {
    type = 'sShape';
    parameters = [f.a, f.b];
  } else if (f is ZShape) {
    type = 'zShape';
    parameters = [f.a, f.b];
  } else if (f is PiShape) {
    type = 'piShape';
    parameters = [f.a, f.b, f.c, f.d];
  } else if (f is Rectangle) {
    type = 'rectangle';
    parameters = [f.a, f.b];
  } else if (f is DiscreteSet) {
    type = 'discrete';
    parameters = [
      for (final point in f.points) [point.x, point.membership]
    ];
  } else {
    throw UnsupportedError('Custom membership function is not serializable.');
  }
  return {'type': type, 'parameters': parameters};
}

MembershipFunction _membership(Object? raw) {
  final map = _object(raw, 'membership');
  _keys(map, ['type', 'parameters'], 'membership');
  final type = _string(map['type'], 'membership.type');
  final parameters = _list(map['parameters'], 'membership.parameters');
  if (type == 'discrete')
    return DiscreteSet([for (final rawPoint in parameters) _point(rawPoint)]);
  final lengths = {
    'triangle': 3,
    'trapezoid': 4,
    'gaussian': 2,
    'ramp': 2,
    'sigmoid': 2,
    'bell': 3,
    'sShape': 2,
    'zShape': 2,
    'piShape': 4,
    'rectangle': 2
  };
  if (!lengths.containsKey(type) || parameters.length != lengths[type])
    throw const FormatException(
        'Unknown membership type or wrong parameter count.');
  final v = parameters
      .map((value) => _number(value, 'membership.parameter'))
      .toList();
  return switch (type) {
    'triangle' => Triangle(v[0], v[1], v[2]),
    'trapezoid' => Trapezoid(v[0], v[1], v[2], v[3]),
    'gaussian' => Gaussian(v[0], v[1]),
    'ramp' => Ramp(v[0], v[1]),
    'sigmoid' => Sigmoid(v[0], v[1]),
    'bell' => Bell(v[0], v[1], v[2]),
    'sShape' => SShape(v[0], v[1]),
    'zShape' => ZShape(v[0], v[1]),
    'piShape' => PiShape(v[0], v[1], v[2], v[3]),
    'rectangle' => Rectangle(v[0], v[1]),
    _ => throw const FormatException('Unsupported membership function.'),
  };
}

MembershipPoint _point(Object? raw) {
  final point = _list(raw, 'point');
  if (point.length != 2)
    throw const FormatException('Points require exactly x and membership.');
  return MembershipPoint(
      _number(point[0], 'point.x'), _number(point[1], 'point.membership'));
}

String _tNormName(TNorm norm) {
  if (norm is Minimum) return 'minimum';
  if (norm is AlgebraicProduct) return 'algebraicProduct';
  if (norm is BoundedDifference) return 'boundedDifference';
  throw UnsupportedError('Custom t-norm is not serializable.');
}

String _sNormName(SNorm norm) {
  if (norm is Maximum) return 'maximum';
  if (norm is ProbabilisticSum) return 'probabilisticSum';
  if (norm is BoundedSum) return 'boundedSum';
  throw UnsupportedError('Custom s-norm is not serializable.');
}

TNorm _tNorm(Object? name) => switch (name) {
      'minimum' => const Minimum(),
      'algebraicProduct' => const AlgebraicProduct(),
      'boundedDifference' => const BoundedDifference(),
      _ => throw const FormatException('Unsupported t-norm.'),
    };
SNorm _sNorm(Object? name) => switch (name) {
      'maximum' => const Maximum(),
      'probabilisticSum' => const ProbabilisticSum(),
      'boundedSum' => const BoundedSum(),
      _ => throw const FormatException('Unsupported s-norm.'),
    };
Map<String, Object?> _defuzzifierJson(Defuzzifier value) {
  if (value is Centroid) return {'type': 'centroid'};
  if (value is Bisector) return {'type': 'bisector'};
  if (value is SmallestOfMaximum)
    return {'type': 'smallestOfMaximum', 'tolerance': value.tolerance};
  if (value is LargestOfMaximum)
    return {'type': 'largestOfMaximum', 'tolerance': value.tolerance};
  if (value is MeanOfMaximum)
    return {'type': 'meanOfMaximum', 'tolerance': value.tolerance};
  throw UnsupportedError('Custom defuzzifier is not serializable.');
}

Defuzzifier _defuzzifier(Object? raw) {
  final map = _object(raw, 'defuzzifier');
  final type = map['type'];
  if (type == 'centroid' || type == 'bisector') {
    _keys(map, ['type'], 'defuzzifier');
    return type == 'centroid' ? const Centroid() : const Bisector();
  }
  _keys(map, ['type', 'tolerance'], 'defuzzifier');
  final tolerance = _number(map['tolerance'], 'defuzzifier.tolerance');
  return switch (type) {
    'smallestOfMaximum' => SmallestOfMaximum(tolerance: tolerance),
    'largestOfMaximum' => LargestOfMaximum(tolerance: tolerance),
    'meanOfMaximum' => MeanOfMaximum(tolerance: tolerance),
    _ => throw const FormatException('Unsupported defuzzifier.'),
  };
}

final class _ConditionWriter implements ConditionVisitor<Map<String, Object?>> {
  _ConditionWriter(this.maxDepth, this.maxNodes);
  final int maxDepth;
  final int maxNodes;
  int _nodes = 0;
  int _depth = 0;
  Map<String, Object?> write(Condition condition) {
    if (++_nodes > maxNodes || ++_depth > maxDepth)
      throw const FormatException('Condition exceeds depth limit.');
    try {
      return condition.accept(this);
    } finally {
      _depth--;
    }
  }

  @override
  Map<String, Object?> visitTerm(Term term) =>
      {'type': 'term', 'variable': term.variable, 'term': term.term};
  @override
  Map<String, Object?> visitAnd(Condition left, Condition right) =>
      {'type': 'and', 'left': write(left), 'right': write(right)};
  @override
  Map<String, Object?> visitOr(Condition left, Condition right) =>
      {'type': 'or', 'left': write(left), 'right': write(right)};
  @override
  Map<String, Object?> visitNot(Condition child) =>
      {'type': 'not', 'operand': write(child)};
  @override
  Map<String, Object?> visitHedge(Condition child, FuzzyHedge modifier) {
    final String name;
    if (modifier is Very) {
      name = 'very';
    } else if (modifier is Somewhat) {
      name = 'somewhat';
    } else {
      throw UnsupportedError('Custom hedge is not serializable.');
    }
    return {'type': 'hedge', 'modifier': name, 'operand': write(child)};
  }
}

Condition _condition(Object? raw) {
  final map = _object(raw, 'condition');
  final type = map['type'];
  if (type == 'term') {
    _keys(map, ['type', 'variable', 'term'], 'condition');
    return Term(_string(map['variable'], 'condition.variable'),
        _string(map['term'], 'condition.term'));
  }
  if (type == 'and' || type == 'or') {
    _keys(map, ['type', 'left', 'right'], 'condition');
    final left = _condition(map['left']), right = _condition(map['right']);
    return type == 'and' ? left.and(right) : left.or(right);
  }
  if (type == 'not') {
    _keys(map, ['type', 'operand'], 'condition');
    return _condition(map['operand']).not();
  }
  if (type == 'hedge') {
    _keys(map, ['type', 'modifier', 'operand'], 'condition');
    final modifier = switch (map['modifier']) {
      'very' => const Very(),
      'somewhat' => const Somewhat(),
      _ => throw const FormatException('Unsupported hedge.')
    };
    return _condition(map['operand']).hedge(modifier);
  }
  throw const FormatException('Unsupported condition type.');
}

FuzzyRule _mamdaniRule(Map<String, Object?> r) {
  _keys(r, ['name', 'when', 'output', 'term', 'weight'], 'rule');
  return FuzzyRule(
      name: _string(r['name'], 'rule.name'),
      when: _condition(r['when']),
      output: _string(r['output'], 'rule.output'),
      term: _string(r['term'], 'rule.term'),
      weight: _number(r['weight'], 'rule.weight'));
}

SugenoOutput _sugenoOutput(Object? raw) {
  final map = _object(raw, 'output');
  _keys(map, ['name'], 'output');
  return SugenoOutput(_string(map['name'], 'output.name'));
}

SugenoRule _sugenoRule(Map<String, Object?> r) {
  _keys(r, ['name', 'when', 'output', 'consequent', 'weight'], 'rule');
  final c = _object(r['consequent'], 'consequent');
  final SugenoConsequent consequent;
  if (c['type'] == 'constant') {
    _keys(c, ['type', 'value'], 'consequent');
    consequent = ConstantConsequent(_number(c['value'], 'consequent.value'));
  } else if (c['type'] == 'linear') {
    _keys(c, ['type', 'intercept', 'coefficients'], 'consequent');
    consequent = LinearConsequent(
        intercept: _number(c['intercept'], 'consequent.intercept'),
        coefficients: _object(c['coefficients'], 'consequent.coefficients').map(
            (name, value) => MapEntry(name, _number(value, 'coefficient'))));
  } else {
    throw const FormatException('Unsupported consequent.');
  }
  return SugenoRule(
      name: _string(r['name'], 'rule.name'),
      when: _condition(r['when']),
      output: _string(r['output'], 'rule.output'),
      consequent: consequent,
      weight: _number(r['weight'], 'rule.weight'));
}
