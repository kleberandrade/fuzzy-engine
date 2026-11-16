import 'engine.dart';
import 'membership.dart';
import 'model.dart';

/// Explicit finite input universe; FCL FUZZIFY does not supply one in this profile.
final class FclRange {
  /// Requires finite, ordered bounds and a finite span.
  FclRange(this.min, this.max) {
    if (!min.isFinite || !max.isFinite || min >= max || !(max - min).isFinite) {
      throw ArgumentError('Invalid FCL range.');
    }
  }

  /// Inclusive lower bound.
  final double min;

  /// Inclusive upper bound.
  final double max;
}

/// Adapted FCL decision retaining the original inference explanation.
final class FclResult {
  FclResult._(this.trace, this.value, this.usedDefault);

  /// Unmodified engine result, including null for zero sampled area.
  final FuzzyResult trace;

  /// Crisp output or the explicit FCL DEFAULT value.
  final double value;

  /// Whether DEFAULT replaced a null core decision.
  final bool usedDefault;
}

/// Restricted FCL controller. DEFAULT is adapter behavior, never a core mutation.
final class FclModel {
  FclModel._(this.name, this.ruleBlockName, this.engine, this.defaultValue);

  /// Wraps a Dart engine with explicit FCL names and numeric DEFAULT.
  /// Export separately validates representability of all engine components.
  factory FclModel.fromEngine(
      {required String name,
      required String ruleBlockName,
      required FuzzyEngine engine,
      required double defaultValue}) {
    if (name.trim().isEmpty ||
        ruleBlockName.trim().isEmpty ||
        engine.outputs.length != 1 ||
        !defaultValue.isFinite) {
      throw ArgumentError(
          'A named, single-output FCL model and finite DEFAULT are required.');
    }
    return FclModel._(name, ruleBlockName, engine, defaultValue);
  }

  /// FUNCTION_BLOCK identifier.
  final String name;

  /// RULEBLOCK identifier.
  final String ruleBlockName;

  /// Core single-output Mamdani engine.
  final FuzzyEngine engine;

  /// Explicit finite DEFAULT, possibly outside the output range.
  final double defaultValue;

  /// Evaluates exact in-range inputs, replacing only null sampled decisions.
  FclResult evaluate(Map<String, double> inputs) {
    final trace = engine.evaluate(inputs);
    final value = trace.value(engine.outputs.single.name);
    return FclResult._(trace, value ?? defaultValue, value == null);
  }
}

/// Experimental bounded FCL import: REAL declarations, point terms, one output
/// and one MIN/MAX/COG rule block. This is not full IEC 61131-7 conformance.
final class FclImporter {
  /// Input ranges are explicit application configuration, not guessed from terms.
  FclImporter(
      {required Map<String, FclRange> inputRanges,
      this.intervals = 1000,
      this.maxSourceLength = 1000000,
      this.maxTokens = 100000,
      this.maxRules = 4096})
      : inputRanges = Map.unmodifiable(inputRanges) {
    if (inputRanges.isEmpty ||
        inputRanges.length > 64 ||
        intervals < 2 ||
        intervals > 1000000 ||
        maxSourceLength < 1 ||
        maxTokens < 1 ||
        maxRules < 1) {
      throw ArgumentError('Invalid FCL import limits.');
    }
  }

  /// Immutable ranges; must exactly match the declared input names.
  final Map<String, FclRange> inputRanges;

  /// Trapezoidal integration intervals; not stored in FCL.
  final int intervals;

  /// Maximum UTF-16 source units before lexing.
  final int maxSourceLength;

  /// Maximum tokens before model construction.
  final int maxTokens;

  /// Maximum rules.
  final int maxRules;

  /// Parses data without executing expressions or file directives.
  FclModel decode(String source) {
    if (source.length > maxSourceLength) {
      throw const FormatException('FCL source limit exceeded.');
    }
    return _Parser(source, this).parse();
  }
}

final class _Token {
  _Token(this.text, this.offset);
  final String text;
  final int offset;
}

final class _Parser {
  _Parser(this.source, this.options) {
    _lex();
  }
  final String source;
  final FclImporter options;
  final tokens = <_Token>[];
  int cursor = 0;
  static final lexical = RegExp(
      r'[A-Za-z_][A-Za-z0-9_]*|[+-]?(?:[0-9]+(?:\.(?!\.)[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?|:=|\.\.|[():;,]');
  void _lex() {
    var offset = 0;
    while (offset < source.length) {
      if (RegExp(r'\s').hasMatch(source[offset])) {
        offset++;
        continue;
      }
      if (source.startsWith('(*', offset)) {
        final end = source.indexOf('*)', offset + 2);
        if (end < 0 || source.substring(offset + 2, end).contains('(*')) {
          _fail('Unterminated or nested comment.', offset);
        }
        offset = end + 2;
        continue;
      }
      final match = lexical.matchAsPrefix(source, offset);
      if (match == null) {
        _fail('Unsupported token.', offset);
      }
      tokens.add(_Token(match[0]!, offset));
      if (tokens.length > options.maxTokens) {
        _fail('Token limit exceeded.', offset);
      }
      offset = match.end;
    }
    tokens.add(_Token('<EOF>', source.length));
  }

  Never _fail(String message, [int? offset]) {
    final position = offset ??
        (cursor < tokens.length ? tokens[cursor].offset : source.length);
    final line = '\n'.allMatches(source.substring(0, position)).length + 1;
    throw FormatException('FCL line $line: $message');
  }

  bool isToken(String value) => tokens[cursor].text.toUpperCase() == value;
  bool take(String value) {
    if (isToken(value)) {
      cursor++;
      return true;
    }
    return false;
  }

  void expect(String value) {
    if (!take(value)) {
      _fail('Expected $value.');
    }
  }

  String identifier() {
    final value = tokens[cursor].text;
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(value)) {
      _fail('Expected identifier.');
    }
    cursor++;
    return value;
  }

  double number() {
    final value = double.tryParse(tokens[cursor].text);
    if (value == null || !value.isFinite) {
      _fail('Expected finite number.');
    }
    cursor++;
    return value;
  }

  List<String> declarations(String kind) {
    expect(kind);
    final names = <String>[];
    while (!take('END_VAR')) {
      final name = identifier();
      expect(':');
      expect('REAL');
      expect(';');
      if (names.contains(name)) {
        _fail('Duplicate variable.');
      }
      names.add(name);
      if (names.length > 64) {
        _fail('Variable count limit exceeded.');
      }
    }
    if (names.isEmpty) {
      _fail('Empty declarations.');
    }
    return names;
  }

  FclModel parse() {
    expect('FUNCTION_BLOCK');
    final name = identifier();
    final inputs = declarations('VAR_INPUT');
    final outputs = declarations('VAR_OUTPUT');
    if (outputs.length != 1) {
      _fail('Exactly one output is supported.');
    }
    if (inputs.contains(outputs.single)) {
      _fail('Input and output identifiers must be distinct.');
    }
    if (inputs.length != options.inputRanges.length ||
        !inputs.every(options.inputRanges.containsKey)) {
      _fail('Input ranges must exactly match declarations.');
    }
    final variables = <String, FuzzyVariable>{};
    while (take('FUZZIFY')) {
      final name = identifier();
      if (!inputs.contains(name) || variables.containsKey(name)) {
        _fail('Unknown or duplicate FUZZIFY.');
      }
      final terms = readTerms();
      expect('END_FUZZIFY');
      variables[name] = variable(name, options.inputRanges[name]!, terms);
    }
    if (variables.length != inputs.length) {
      _fail('Missing FUZZIFY.');
    }
    expect('DEFUZZIFY');
    final outputName = identifier();
    if (outputName != outputs.single) {
      _fail('Unknown output.');
    }
    final terms = readTerms();
    // Canonical order is intentionally narrow; unknown fields never disappear.
    expect('METHOD');
    expect(':');
    expect('COG');
    expect(';');
    expect('DEFAULT');
    expect(':=');
    final fallback = number();
    expect(';');
    expect('RANGE');
    expect(':=');
    expect('(');
    final min = number();
    expect('..');
    final max = number();
    expect(')');
    expect(';');
    expect('END_DEFUZZIFY');
    late FclRange outputRange;
    try {
      outputRange = FclRange(min, max);
    } on ArgumentError {
      _fail('Invalid output range.');
    }
    final output = variable(outputName, outputRange, terms);
    expect('RULEBLOCK');
    final block = identifier();
    expect('AND');
    expect(':');
    expect('MIN');
    expect(';');
    if (take('OR')) {
      expect(':');
      expect('MAX');
      expect(';');
    }
    expect('ACT');
    expect(':');
    expect('MIN');
    expect(';');
    expect('ACCU');
    expect(':');
    expect('MAX');
    expect(';');
    final rules = <FuzzyRule>[];
    while (take('RULE')) {
      final label = tokens[cursor].text;
      final ruleId = int.tryParse(label);
      if (!RegExp(r'^[0-9]+$').hasMatch(label) ||
          ruleId == null ||
          ruleId > 2147483647) {
        _fail('Expected numeric rule identifier.');
      }
      cursor++;
      expect(':');
      expect('IF');
      Condition atom() {
        final variable = identifier();
        expect('IS');
        final negate = take('NOT');
        Condition term = Term(variable, identifier());
        return negate ? term.not() : term;
      }

      Condition condition = atom();
      String? connector;
      var count = 1;
      while (isToken('AND') || isToken('OR')) {
        final op = tokens[cursor++].text.toUpperCase();
        if (connector != null && connector != op) {
          _fail('Mixed connectives are unsupported.');
        }
        connector = op;
        final next = atom();
        condition = op == 'AND' ? condition.and(next) : condition.or(next);
        if (++count > 64) {
          _fail('Antecedent limit exceeded.');
        }
      }
      expect('THEN');
      final target = identifier();
      expect('IS');
      final term = identifier();
      final weight = take('WITH') ? number() : 1.0;
      expect(';');
      if (weight < 0 || weight > 1) {
        _fail('Weight must be in [0,1].');
      }
      rules.add(FuzzyRule(
          name: ruleId.toString(),
          when: condition,
          output: target,
          term: term,
          weight: weight));
      if (rules.length > options.maxRules) {
        _fail('Rule count limit exceeded.');
      }
    }
    expect('END_RULEBLOCK');
    expect('END_FUNCTION_BLOCK');
    expect('<EOF>');
    try {
      return FclModel._(
          name,
          block,
          FuzzyEngine(
              inputs: [for (final input in inputs) variables[input]!],
              outputs: [output],
              rules: rules,
              intervals: options.intervals),
          fallback);
    } on ArgumentError {
      _fail('Invalid rule references or duplicate identifiers.');
    }
  }

  Map<String, List<MembershipPoint>> readTerms() {
    final terms = <String, List<MembershipPoint>>{};
    while (take('TERM')) {
      final name = identifier();
      expect(':=');
      final points = <MembershipPoint>[];
      while (take('(')) {
        final x = number();
        expect(',');
        final y = number();
        expect(')');
        if (y < 0 || y > 1 || (points.isNotEmpty && x <= points.last.x)) {
          _fail('Invalid point sequence.');
        }
        points.add(MembershipPoint(x, y));
        if (points.length > 4096) {
          _fail('Point count limit exceeded.');
        }
      }
      expect(';');
      if (points.length < 2 || terms.containsKey(name)) {
        _fail('Duplicate term or fewer than two points.');
      }
      terms[name] = points;
      if (terms.length > 256) {
        _fail('Term count limit exceeded.');
      }
    }
    if (terms.isEmpty) {
      _fail('At least one point term is required.');
    }
    return terms;
  }

  FuzzyVariable variable(
      String name, FclRange range, Map<String, List<MembershipPoint>> terms) {
    final mapped = <String, MembershipFunction>{};
    for (final entry in terms.entries) {
      final points = entry.value;
      if (points.first.x < range.min || points.last.x > range.max) {
        _fail('Term points outside explicit universe.');
      }
      // Saturating FCL tails are represented explicitly inside the finite universe.
      mapped[entry.key] = DiscreteSet([
        if (points.first.x > range.min)
          MembershipPoint(range.min, points.first.membership),
        ...points,
        if (points.last.x < range.max)
          MembershipPoint(range.max, points.last.membership),
      ]);
    }
    try {
      return FuzzyVariable(
          name: name, min: range.min, max: range.max, terms: mapped);
    } on ArgumentError {
      _fail('Invalid variable.');
    }
  }
}
