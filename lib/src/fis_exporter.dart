import 'defuzzification.dart';
import 'engine.dart';
import 'hedges.dart';
import 'membership.dart';
import 'model.dart';
import 'operators.dart';
import 'sugeno.dart';
import 'fis_importer.dart';

/// Restricted text FIS exporter. Unsupported components fail without approximation.
/// FIS does not store core rule names, integration resolution or fallback policy.
/// Returned text transfers the inference configuration, not those runtime settings.
final class FisExporter {
  /// Bounds both recursion and the resulting source length.
  const FisExporter({this.maxDepth = 64, this.maxSourceLength = 1000000});

  /// Maximum condition depth accepted before visiting children.
  final int maxDepth;

  /// Maximum generated UTF-16 source length.
  final int maxSourceLength;

  /// Export a single-output Mamdani engine. Rule labels become positional labels.
  /// Caller must explicitly acknowledge settings not carried by the FIS format.
  String encodeMamdani(FuzzyEngine engine,
      {required String name, required bool acknowledgeRuntimeSettings}) {
    _acknowledge(acknowledgeRuntimeSettings);
    if (engine.outputs.length != 1 ||
        engine.aggregation is! Maximum ||
        engine.defuzzifier is! Centroid) {
      throw UnsupportedError(
          'FIS profile requires one output, max and centroid.');
    }
    final out = engine.outputs.single;
    final text = StringBuffer(_system(
        name,
        'mamdani',
        engine.inputs.length,
        engine.rules.length,
        engine.operators,
        _tnorm(engine.implication),
        'max',
        'centroid'));
    _inputs(text, engine.inputs);
    text.write(_variable('Output1', out));
    text.writeln('[Rules]');
    for (final rule in engine.rules) {
      final index = out.terms.keys.toList().indexOf(rule.term) + 1;
      text.writeln(
          '${_condition(rule.when, engine.inputs)}, $index (${rule.weight}) : ${_connector(rule.when)}');
    }
    return _finish(text);
  }

  /// Export an imported Sugeno model, preserving output bounds and named,
  /// including unused, consequents. Core Sugeno engines alone have no FIS bounds.
  String encodeSugeno(FisSugenoModel model,
      {required bool acknowledgeRuntimeSettings}) {
    _acknowledge(acknowledgeRuntimeSettings);
    final engine = model.engine;
    if (model.consequents.length > 256) {
      throw UnsupportedError(
          'FIS output catalog exceeds the supported profile.');
    }
    final text = StringBuffer(_system(
        model.name,
        'sugeno',
        engine.inputs.length,
        engine.rules.length,
        engine.operators,
        'prod',
        'sum',
        engine.aggregation == SugenoAggregation.weightedAverage
            ? 'wtaver'
            : 'wtsum'));
    _inputs(text, engine.inputs);
    text.writeln('[Output1]');
    text.writeln('Name=${_quote(engine.outputs.single.name)}');
    text.writeln('Range=[${model.outputMin} ${model.outputMax}]');
    text.writeln('NumMFs=${model.consequents.length}');
    var i = 0;
    for (final entry in model.consequents.entries) {
      final consequent = entry.value;
      final String type;
      final List<double> parameters;
      if (consequent is ConstantConsequent) {
        type = 'constant';
        parameters = [consequent.value];
      } else if (consequent is LinearConsequent) {
        type = 'linear';
        parameters = [
          for (final input in engine.inputs)
            consequent.coefficients[input.name] ?? 0,
          consequent.intercept
        ];
      } else {
        throw UnsupportedError(
            'Only constant and linear FIS consequents are supported.');
      }
      text.writeln(
          'MF${++i}=${_quote(entry.key)}:${_quote(type)},[${parameters.join(' ')}]');
    }
    text.writeln('\n[Rules]');
    final consequents = model.consequents.values.toList();
    for (final rule in engine.rules) {
      final index = consequents.indexOf(rule.consequent) + 1;
      if (index == 0)
        throw UnsupportedError(
            'Rule consequent is absent from the FIS catalog.');
      text.writeln(
          '${_condition(rule.when, engine.inputs)}, $index (${rule.weight}) : ${_connector(rule.when)}');
    }
    return _finish(text);
  }

  void _acknowledge(bool accepted) {
    if (maxDepth < 1 || maxSourceLength < 1)
      throw ArgumentError('Invalid FIS export limits.');
    if (!accepted)
      throw ArgumentError(
          'Acknowledge that FIS omits rule names, resolution and fallback policy.');
  }

  String _finish(StringBuffer text) {
    if (text.length > maxSourceLength)
      throw UnsupportedError('FIS source limit exceeded.');
    return text.toString();
  }

  String _system(
      String name,
      String type,
      int inputs,
      int rules,
      FuzzyOperators operators,
      String implication,
      String aggregation,
      String defuzzifier) {
    if (inputs > 64 || rules > 4096) {
      throw UnsupportedError(
          'FIS input or rule count exceeds the supported profile.');
    }
    if (operators.negation is! StandardNegation)
      throw UnsupportedError('FIS requires standard complement.');
    final or = switch (operators.disjunction) {
      Maximum() => 'max',
      ProbabilisticSum() => 'probor',
      _ => throw UnsupportedError('Unsupported FIS OR operator.'),
    };
    return '[System]\nName=${_quote(name)}\nType=${_quote(type)}\nVersion=2.0\nNumInputs=$inputs\nNumOutputs=1\nNumRules=$rules\nAndMethod=${_quote(_tnorm(operators.conjunction))}\nOrMethod=${_quote(or)}\nImpMethod=${_quote(implication)}\nAggMethod=${_quote(aggregation)}\nDefuzzMethod=${_quote(defuzzifier)}\n\n';
  }

  void _inputs(StringBuffer text, List<FuzzyVariable> inputs) {
    for (var i = 0; i < inputs.length; i++) {
      text.write(_variable('Input${i + 1}', inputs[i]));
    }
  }

  String _variable(String section, FuzzyVariable variable) {
    if (variable.terms.length > 256) {
      throw UnsupportedError(
          'FIS membership count exceeds the supported profile.');
    }
    final text = StringBuffer(
        '[$section]\nName=${_quote(variable.name)}\nRange=[${variable.min} ${variable.max}]\nNumMFs=${variable.terms.length}\n');
    var i = 0;
    for (final entry in variable.terms.entries) {
      final (type, parameters) = switch (entry.value) {
        Triangle(:final a, :final b, :final c) => ('trimf', [a, b, c]),
        Trapezoid(:final a, :final b, :final c, :final d) => (
            'trapmf',
            [a, b, c, d]
          ),
        Gaussian(:final mean, :final sigma) => ('gaussmf', [sigma, mean]),
        _ => throw UnsupportedError('Unsupported FIS membership function.'),
      };
      text.writeln(
          'MF${++i}=${_quote(entry.key)}:${_quote(type)},[${parameters.join(' ')}]');
    }
    text.writeln();
    return text.toString();
  }

  _FlatCondition _flat(Condition condition) =>
      condition.accept(_Flatten(maxDepth, 0));
  int _connector(Condition condition) => _flat(condition).connector ?? 1;
  String _condition(Condition condition, List<FuzzyVariable> inputs) {
    final flat = _flat(condition);
    final indices = List<int>.filled(inputs.length, 0);
    for (final entry in flat.terms) {
      final i = inputs.indexWhere((input) => input.name == entry.$1.variable);
      if (i < 0 || indices[i] != 0)
        throw UnsupportedError(
            'FIS permits at most one term per input in a rule.');
      final term = inputs[i].terms.keys.toList().indexOf(entry.$1.term) + 1;
      if (term == 0) throw UnsupportedError('Unknown FIS term.');
      indices[i] = entry.$2 ? -term : term;
    }
    return indices.join(' ');
  }
}

String _quote(String value) {
  if (value.trim().isEmpty ||
      value.contains("'") ||
      value.contains('\n') ||
      value.contains('\r')) {
    throw UnsupportedError(
        'FIS names must be nonempty single-line strings without quotes.');
  }
  return "'$value'";
}

String _tnorm(TNorm norm) => switch (norm) {
      Minimum() => 'min',
      AlgebraicProduct() => 'prod',
      _ => throw UnsupportedError('Unsupported FIS t-norm.'),
    };

final class _FlatCondition {
  _FlatCondition(this.terms, this.connector);
  final List<(Term, bool)> terms;
  final int? connector;
}

final class _Flatten implements ConditionVisitor<_FlatCondition> {
  _Flatten(this.limit, this.depth);
  final int limit, depth;
  _FlatCondition child(Condition value) {
    if (depth >= limit)
      throw UnsupportedError('FIS condition depth limit exceeded.');
    return value.accept(_Flatten(limit, depth + 1));
  }

  _FlatCondition binary(Condition left, Condition right, int connector) {
    final a = child(left), b = child(right);
    if (a.terms.length + b.terms.length > 64) {
      throw UnsupportedError('FIS rule exceeds the supported input count.');
    }
    if ((a.connector != null && a.connector != connector) ||
        (b.connector != null && b.connector != connector)) {
      throw UnsupportedError(
          'Mixed nested connectives cannot be represented by this FIS profile.');
    }
    return _FlatCondition([...a.terms, ...b.terms], connector);
  }

  @override
  _FlatCondition visitTerm(Term term) => _FlatCondition([(term, false)], null);
  @override
  _FlatCondition visitAnd(Condition left, Condition right) =>
      binary(left, right, 1);
  @override
  _FlatCondition visitOr(Condition left, Condition right) =>
      binary(left, right, 2);
  @override
  _FlatCondition visitNot(Condition condition) {
    if (condition is! Term)
      throw UnsupportedError('Only individual FIS terms can be complemented.');
    return _FlatCondition([(condition, true)], null);
  }

  @override
  _FlatCondition visitHedge(Condition child, FuzzyHedge modifier) =>
      throw UnsupportedError('FIS hedges are unsupported.');
}
