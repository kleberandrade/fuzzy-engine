import 'defuzzification.dart';
import 'fcl.dart';
import 'hedges.dart';
import 'membership.dart';
import 'model.dart';
import 'operators.dart';

/// Exports the restricted point-term MIN/MAX/COG FCL profile, without sampling
/// arbitrary functions or discarding unsupported rule semantics.
final class FclExporter {
  /// Sets source and condition-depth budgets.
  const FclExporter({this.maxSourceLength = 1000000, this.maxDepth = 64});

  /// Maximum generated UTF-16 units.
  final int maxSourceLength;

  /// Maximum nested condition depth.
  final int maxDepth;

  /// Input universes and integration resolution are external to this profile.
  /// Caller must acknowledge and transfer them separately when importing again.
  String encode(FclModel model, {required bool acknowledgeRuntimeSettings}) {
    if (maxSourceLength < 1 || maxDepth < 1) {
      throw ArgumentError('Invalid FCL export limits.');
    }
    if (!acknowledgeRuntimeSettings) {
      throw ArgumentError(
          'FCL does not store input universes or integration resolution.');
    }
    final engine = model.engine;
    if (engine.inputs.length > 64 ||
        engine.rules.length > 4096 ||
        engine.operators.conjunction is! Minimum ||
        engine.operators.disjunction is! Maximum ||
        engine.operators.negation is! StandardNegation ||
        engine.implication is! Minimum ||
        engine.aggregation is! Maximum ||
        engine.defuzzifier is! Centroid) {
      throw UnsupportedError(
          'FCL profile requires bounded MIN/MAX/standard complement/COG.');
    }
    final output = engine.outputs.single;
    if (engine.inputs.any((input) => input.name == output.name)) {
      throw UnsupportedError('Input and output identifiers must be distinct.');
    }
    final text = StringBuffer();
    void line(String value) {
      if (text.length + value.length + 1 > maxSourceLength) {
        throw UnsupportedError('FCL source limit exceeded.');
      }
      text.writeln(value);
    }

    line('FUNCTION_BLOCK ${_identifier(model.name)}');
    line('VAR_INPUT');
    for (final input in engine.inputs) {
      line(' ${_identifier(input.name)} : REAL;');
    }
    line('END_VAR');
    line('VAR_OUTPUT');
    line(' ${_identifier(output.name)} : REAL;');
    line('END_VAR');
    void terms(FuzzyVariable variable) {
      if (variable.terms.length > 256) {
        throw UnsupportedError('FCL term limit exceeded.');
      }
      for (final entry in variable.terms.entries) {
        final function = entry.value;
        if (function is! DiscreteSet) {
          throw UnsupportedError(
              'Only explicit DiscreteSet FCL terms are exported.');
        }
        if (function.points.length > 4098) {
          throw UnsupportedError('FCL point limit exceeded.');
        }
        final points = function.points.toList();
        if (points.first.x < variable.min ||
            points.last.x > variable.max ||
            (points.first.x > variable.min && points.first.membership != 0) ||
            (points.last.x < variable.max && points.last.membership != 0)) {
          throw UnsupportedError(
              'Point support cannot be mapped to FCL saturated tails exactly.');
        }
        // Drop redundant boundary plateaus introduced by the importer. This also
        // preserves the original point budget when two tails were added.
        if (points.length > 2 &&
            points.first.x == variable.min &&
            points[0].membership == points[1].membership) {
          points.removeAt(0);
        }
        if (points.length > 2 &&
            points.last.x == variable.max &&
            points.last.membership == points[points.length - 2].membership) {
          points.removeLast();
        }
        if (points.length > 4096) {
          throw UnsupportedError('FCL point limit exceeded.');
        }
        line(
            ' TERM ${_identifier(entry.key)} := ${points.map((p) => '(${p.x},${p.membership})').join(' ')};');
      }
    }

    for (final input in engine.inputs) {
      line('FUZZIFY ${_identifier(input.name)}');
      terms(input);
      line('END_FUZZIFY');
    }
    line('DEFUZZIFY ${_identifier(output.name)}');
    terms(output);
    line(' METHOD : COG;');
    line(' DEFAULT := ${model.defaultValue};');
    line(' RANGE := (${output.min} .. ${output.max});');
    line('END_DEFUZZIFY');
    line('RULEBLOCK ${_identifier(model.ruleBlockName)}');
    line(' AND : MIN;');
    line(' OR : MAX;');
    line(' ACT : MIN;');
    line(' ACCU : MAX;');
    for (final rule in engine.rules) {
      final id = int.tryParse(rule.name);
      if (id == null ||
          id < 0 ||
          id > 2147483647 ||
          id.toString() != rule.name) {
        throw UnsupportedError(
            'FCL export preserves canonical numeric rule identifiers only.');
      }
      final condition = rule.when.accept(_ConditionText(maxDepth, 0));
      line(
          ' RULE $id : IF ${condition.text} THEN ${_identifier(rule.output)} IS ${_identifier(rule.term)} WITH ${rule.weight};');
    }
    line('END_RULEBLOCK');
    line('END_FUNCTION_BLOCK');
    return text.toString();
  }
}

const _reserved = {
  'ABS',
  'ASUM',
  'BDIF',
  'BSUM',
  'COA',
  'COSINE',
  'COGS',
  'COGF',
  'COS',
  'DMAX',
  'DMIN',
  'DSIGM',
  'EINSTEIN',
  'EXP',
  'HAMACHER',
  'FUNCTION',
  'GAUSS',
  'GAUSS2',
  'GBELL',
  'LM',
  'LN',
  'LOG',
  'NIPMIN',
  'NIPMAX',
  'MM',
  'NSUM',
  'PROBOR',
  'PROD',
  'RM',
  'SIGM',
  'SIN',
  'SINGLETONS',
  'SUM',
  'TAN',
  'TRAPE',
  'TRIAN',
  'FUNCTION_BLOCK',
  'END_FUNCTION_BLOCK',
  'VAR_INPUT',
  'VAR_OUTPUT',
  'END_VAR',
  'REAL',
  'FUZZIFY',
  'END_FUZZIFY',
  'DEFUZZIFY',
  'END_DEFUZZIFY',
  'TERM',
  'METHOD',
  'COG',
  'DEFAULT',
  'RANGE',
  'RULEBLOCK',
  'END_RULEBLOCK',
  'AND',
  'OR',
  'NOT',
  'IS',
  'IF',
  'THEN',
  'WITH',
  'ACT',
  'ACCU',
  'MIN',
  'MAX',
  'RULE',
  'NC'
};
String _identifier(String name) {
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(name) ||
      _reserved.contains(name.toUpperCase())) {
    throw UnsupportedError(
        'FCL identifiers must be non-reserved ASCII identifiers.');
  }
  return name;
}

final class _Expression {
  _Expression(this.text, this.connector, this.terms);
  final String text;
  final String? connector;
  final int terms;
}

final class _ConditionText implements ConditionVisitor<_Expression> {
  _ConditionText(this.limit, this.depth);
  final int limit, depth;
  _Expression child(Condition condition) {
    if (depth >= limit) {
      throw UnsupportedError('FCL condition depth limit exceeded.');
    }
    return condition.accept(_ConditionText(limit, depth + 1));
  }

  _Expression binary(Condition a, Condition b, String op) {
    final left = child(a), right = child(b);
    if ((left.connector != null && left.connector != op) ||
        (right.connector != null && right.connector != op)) {
      throw UnsupportedError('Mixed FCL connectives are unsupported.');
    }
    if (left.terms + right.terms > 64) {
      throw UnsupportedError('FCL antecedent limit exceeded.');
    }
    return _Expression(
        '${left.text} $op ${right.text}', op, left.terms + right.terms);
  }

  @override
  _Expression visitTerm(Term term) => _Expression(
      '${_identifier(term.variable)} IS ${_identifier(term.term)}', null, 1);
  @override
  _Expression visitAnd(Condition left, Condition right) =>
      binary(left, right, 'AND');
  @override
  _Expression visitOr(Condition left, Condition right) =>
      binary(left, right, 'OR');
  @override
  _Expression visitNot(Condition condition) {
    if (condition is! Term) {
      throw UnsupportedError('Only individual FCL terms can be negated.');
    }
    return _Expression(
        '${_identifier(condition.variable)} IS NOT ${_identifier(condition.term)}',
        null,
        1);
  }

  @override
  _Expression visitHedge(Condition child, FuzzyHedge modifier) =>
      throw UnsupportedError('FCL hedges are unsupported.');
}
