import 'defuzzification.dart';
import 'engine.dart';
import 'membership.dart';
import 'model.dart';
import 'operators.dart';
import 'sugeno.dart';

/// Explicit adapter policy when the sampled output has no positive area.
enum FisNoDecisionPolicy {
  /// Preserve the engine's null output.
  preserveNull,

  /// Substitute the midpoint of the declared output universe.
  midpoint,

  /// Fail rather than substitute a numeric decision.
  throwError,
}

/// FIS adapter result; the original explanation never hides a fallback.
final class FisEvaluation {
  FisEvaluation._(this.trace, this.value, this.usedFallback);

  /// Unmodified core result, including null outputs and activation strengths.
  final FuzzyResult trace;

  /// Adapted single output.
  final double? value;

  /// Whether a null core output was replaced with the universe midpoint.
  final bool usedFallback;
}

/// Imported single-output Mamdani model and its explicit adapter policy.
final class FisModel {
  FisModel._(this.name, this.engine, this.noDecisionPolicy);

  /// System name from the file.
  final String name;

  /// Core inference configuration. Direct evaluation preserves core semantics.
  final FuzzyEngine engine;

  /// Policy supplied by the caller, not inferred from the file.
  final FisNoDecisionPolicy noDecisionPolicy;

  /// Evaluate with the selected no-decision policy and retain the original trace.
  FisEvaluation evaluate(Map<String, double> inputs) {
    final trace = engine.evaluate(inputs);
    final output = engine.outputs.single;
    final value = trace.value(output.name);
    if (value != null) return FisEvaluation._(trace, value, false);
    switch (noDecisionPolicy) {
      case FisNoDecisionPolicy.preserveNull:
        return FisEvaluation._(trace, null, false);
      case FisNoDecisionPolicy.midpoint:
        return FisEvaluation._(
            trace, output.min + (output.max - output.min) / 2, true);
      case FisNoDecisionPolicy.throwError:
        throw StateError('FIS output has no sampled area.');
    }
  }
}

/// Sugeno adapter retaining the finite FIS output range and consequent catalog.
/// The range supplies a midpoint fallback; it never clamps crisp consequents.
final class FisSugenoModel {
  /// Construct a model with an explicit range and catalog. All rules must refer
  /// to the supplied consequent instances so export preserves named FIS terms.
  FisSugenoModel(
      {required this.name,
      required this.engine,
      required this.outputMin,
      required this.outputMax,
      required Map<String, SugenoConsequent> consequents,
      required this.noDecisionPolicy})
      : consequents = Map.unmodifiable(consequents) {
    if (name.trim().isEmpty ||
        engine.outputs.length != 1 ||
        !outputMin.isFinite ||
        !outputMax.isFinite ||
        outputMin >= outputMax ||
        !(outputMax - outputMin).isFinite ||
        consequents.isEmpty ||
        consequents.keys.any((name) => name.trim().isEmpty) ||
        engine.rules
            .any((rule) => !consequents.values.contains(rule.consequent))) {
      throw ArgumentError('Invalid Sugeno FIS model.');
    }
    final inputs = engine.inputs.map((input) => input.name).toSet();
    if (consequents.values
        .any((c) => c.references.any((name) => !inputs.contains(name)))) {
      throw ArgumentError('Unknown consequent input in FIS catalog.');
    }
  }

  /// FIS system name.
  final String name;

  /// Single-output Sugeno engine.
  final SugenoEngine engine;

  /// FIS range lower bound, used for fallback only.
  final double outputMin;

  /// FIS range upper bound, used for fallback only.
  final double outputMax;

  /// Named consequents, including unused terms, in declaration order.
  final Map<String, SugenoConsequent> consequents;

  /// Explicit adapter behavior when no rule fires.
  final FisNoDecisionPolicy noDecisionPolicy;

  /// Evaluates without modifying the original Sugeno trace.
  FisSugenoEvaluation evaluate(Map<String, double> inputs) {
    final trace = engine.evaluate(inputs);
    final value = trace.value(engine.outputs.single.name);
    if (value != null) return FisSugenoEvaluation._(trace, value, false);
    switch (noDecisionPolicy) {
      case FisNoDecisionPolicy.preserveNull:
        return FisSugenoEvaluation._(trace, null, false);
      case FisNoDecisionPolicy.midpoint:
        return FisSugenoEvaluation._(
            trace, outputMin + (outputMax - outputMin) / 2, true);
      case FisNoDecisionPolicy.throwError:
        throw StateError('FIS output has no active rule.');
    }
  }
}

/// Adapted Sugeno value with its unchanged core explanation.
final class FisSugenoEvaluation {
  FisSugenoEvaluation._(this.trace, this.value, this.usedFallback);

  /// Original core result.
  final SugenoResult trace;

  /// Adapted single output.
  final double? value;

  /// Whether the midpoint replaced a null decision.
  final bool usedFallback;
}

/// Experimental bounded importer for restricted Mamdani and Sugeno text FIS.
/// No code is executed. Unsupported fields and methods cause FormatException.
/// This is not a vendor-conformance or numerical-equivalence guarantee.
final class FisImporter {
  /// Resolution is adapter configuration: FIS does not carry this interval count.
  /// The no-decision policy is deliberately required, without a default.
  FisImporter({
    required this.noDecisionPolicy,
    this.intervals = 1000,
    this.maxSourceLength = 1000000,
    this.maxRules = 4096,
    this.maxInputs = 64,
    this.maxMembershipsPerVariable = 256,
  }) {
    if (intervals < 2 ||
        intervals > 1000000 ||
        maxSourceLength < 1 ||
        maxRules < 1 ||
        maxInputs < 1 ||
        maxMembershipsPerVariable < 1) {
      throw ArgumentError('Invalid FIS import limits.');
    }
  }

  /// Explicit adapter behavior for a zero-area sampled output.
  final FisNoDecisionPolicy noDecisionPolicy;

  /// Number of integration intervals (sample count is intervals + 1).
  final int intervals;

  /// Maximum UTF-16 source length, checked before tokenization.
  final int maxSourceLength;

  /// Maximum number of rules.
  final int maxRules;

  /// Maximum number of inputs.
  final int maxInputs;

  /// Maximum memberships on each input or output.
  final int maxMembershipsPerVariable;

  /// Parses System, InputN, Output1 and Rules sections. Names are single-quoted
  /// without embedded quotes; percent comments outside quoted strings are allowed.
  FisModel decode(String source) => _decode(source, false) as FisModel;

  /// Import a single-output Sugeno FIS with constant/linear consequents.
  /// ImpMethod=prod and AggMethod=sum are required, not silently ignored.
  FisSugenoModel decodeSugeno(String source) =>
      _decode(source, true) as FisSugenoModel;

  Object _decode(String source, bool sugeno) {
    if (source.length > maxSourceLength) {
      throw const FormatException('FIS source length limit exceeded.');
    }
    final sections = <String, _Section>{};
    _Section? section;
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = _Line(_uncomment(lines[i]).trim(), i + 1);
      if (line.text.isEmpty) continue;
      final header = RegExp(r'^\[(System|Input[1-9][0-9]*|Output1|Rules)\]$')
          .firstMatch(line.text);
      if (header != null) {
        final name = header[1]!;
        if (sections.containsKey(name)) line.fail('Duplicate section.');
        section = _Section(line);
        sections[name] = section;
      } else {
        if (section == null) line.fail('Expected supported section header.');
        if (identical(section, sections['Rules'])) {
          section.rows.add(line);
          if (section.rows.length > maxRules) line.fail('Rule limit exceeded.');
        } else {
          final field = RegExp(r'^([A-Za-z][A-Za-z0-9]*)\s*=\s*(.+)$')
              .firstMatch(line.text);
          if (field == null) line.fail('Expected field assignment.');
          if (section.fields.containsKey(field[1]))
            line.fail('Duplicate field.');
          section.fields[field[1]!] = _Line(field[2]!, line.number);
        }
      }
    }
    final system = sections['System'];
    if (system == null) throw const FormatException('Missing System section.');
    system.only({
      'Name',
      'Type',
      'Version',
      'NumInputs',
      'NumOutputs',
      'NumRules',
      'AndMethod',
      'OrMethod',
      'ImpMethod',
      'AggMethod',
      'DefuzzMethod'
    });
    final name = system.get('Name').quoted();
    _expect(system.get('Type'), sugeno ? 'sugeno' : 'mamdani');
    final version = system.fields['Version'];
    if (version != null && version.numberValue() != 2) {
      version.fail('Only FIS version 2 is supported.');
    }
    final count = system.get('NumInputs').count(maxInputs);
    final ruleCount = system.get('NumRules').count(maxRules);
    if (system.get('NumOutputs').count(1) != 1) {
      system.header.fail('Exactly one output is required.');
    }
    final expected = {
      'System',
      'Rules',
      'Output1',
      for (var i = 1; i <= count; i++) 'Input$i'
    };
    if (sections.length != expected.length ||
        !expected.every(sections.containsKey)) {
      system.header.fail('Missing or undeclared sections.');
    }
    final inputs = [
      for (var i = 1; i <= count; i++) _variable(sections['Input$i']!)
    ];
    final outSection = sections['Output1']!;
    final output = sugeno ? null : _variable(outSection);
    final outputName = output?.name ?? outSection.get('Name').quoted();
    final consequentCatalog = sugeno
        ? _consequents(outSection, inputs)
        : <String, SugenoConsequent>{};
    final outputTerms =
        output?.terms.keys.toList() ?? consequentCatalog.keys.toList();
    final and = _tnorm(system.get('AndMethod'));
    final or = switch (system.get('OrMethod').quoted()) {
      'max' => const Maximum(),
      'probor' => const ProbabilisticSum(),
      _ => system.get('OrMethod').fail('Unsupported OR method.'),
    };
    final implication = _tnorm(system.get('ImpMethod'));
    _expect(system.get('AggMethod'), sugeno ? 'sum' : 'max');
    if (sugeno) _expect(system.get('ImpMethod'), 'prod');
    final defuzz = system.get('DefuzzMethod').quoted();
    if (sugeno ? !{'wtaver', 'wtsum'}.contains(defuzz) : defuzz != 'centroid') {
      system.get('DefuzzMethod').fail('Unsupported defuzzification method.');
    }
    final rows = sections['Rules']!.rows;
    if (rows.length != ruleCount) system.header.fail('Rule count mismatch.');
    final rules = <FuzzyRule>[];
    final sugenoRules = <SugenoRule>[];
    for (final row in rows) {
      final match =
          RegExp(r'^([0-9\s-]+),\s*([0-9]+)\s*\(([^()]+)\)\s*:\s*([12])$')
              .firstMatch(row.text);
      if (match == null) row.fail('Unsupported rule syntax.');
      final indices = match[1]!.trim().split(RegExp(r'\s+'));
      if (indices.length != inputs.length)
        row.fail('Input index count mismatch.');
      Condition? condition;
      for (var i = 0; i < indices.length; i++) {
        final index = int.tryParse(indices[i]);
        if (index == null) row.fail('Invalid input index.');
        if (index == 0) continue;
        final terms = inputs[i].terms.keys.toList();
        if (index < -terms.length || index > terms.length) {
          row.fail('Input index out of range.');
        }
        Condition next = Term(inputs[i].name, terms[index.abs() - 1]);
        if (index < 0) next = next.not();
        condition = condition == null
            ? next
            : match[4] == '1'
                ? condition.and(next)
                : condition.or(next);
      }
      if (condition == null)
        row.fail('All-ignored antecedents are unsupported.');
      final index = int.tryParse(match[2]!);
      if (index == null || index < 1 || index > outputTerms.length) {
        row.fail('Output index out of range.');
      }
      final weight = _Line(match[3]!, row.number).numberValue();
      if (weight < 0 || weight > 1) row.fail('Rule weight must be in [0, 1].');
      if (sugeno) {
        sugenoRules.add(SugenoRule(
            name: 'rule${sugenoRules.length + 1}',
            when: condition,
            output: outputName,
            consequent: consequentCatalog[outputTerms[index - 1]]!,
            weight: weight));
      } else {
        rules.add(FuzzyRule(
            name: 'rule${rules.length + 1}',
            when: condition,
            output: outputName,
            term: outputTerms[index - 1],
            weight: weight));
      }
    }
    try {
      if (sugeno) {
        final range = outSection.get('Range').vector(2);
        return FisSugenoModel(
            name: name,
            outputMin: range[0],
            outputMax: range[1],
            consequents: consequentCatalog,
            noDecisionPolicy: noDecisionPolicy,
            engine: SugenoEngine(
                inputs: inputs,
                outputs: [SugenoOutput(outputName)],
                rules: sugenoRules,
                operators: FuzzyOperators(conjunction: and, disjunction: or),
                aggregation: defuzz == 'wtaver'
                    ? SugenoAggregation.weightedAverage
                    : SugenoAggregation.weightedSum));
      }
      return FisModel._(
          name,
          FuzzyEngine(
              inputs: inputs,
              outputs: [output!],
              rules: rules,
              intervals: intervals,
              operators: FuzzyOperators(conjunction: and, disjunction: or),
              implication: implication,
              defuzzifier: const Centroid()),
          noDecisionPolicy);
    } on ArgumentError {
      system.header
          .fail('Invalid model configuration or duplicate variable names.');
    }
  }

  Map<String, SugenoConsequent> _consequents(
      _Section section, List<FuzzyVariable> inputs) {
    final count = section.get('NumMFs').count(maxMembershipsPerVariable);
    section.only(
        {'Name', 'Range', 'NumMFs', for (var i = 1; i <= count; i++) 'MF$i'});
    final catalog = <String, SugenoConsequent>{};
    for (var i = 1; i <= count; i++) {
      final line = section.get('MF$i');
      final match = RegExp(r"^'([^']+)'\s*:\s*'([^']+)'\s*,\s*(\[.*\])$")
          .firstMatch(line.text);
      if (match == null || match[1]!.trim().isEmpty)
        line.fail('Invalid Sugeno consequent.');
      if (catalog.containsKey(match[1]))
        line.fail('Duplicate consequent name.');
      final params = _Line(match[3]!, line.number);
      switch (match[2]) {
        case 'constant':
          catalog[match[1]!] = ConstantConsequent(params.vector(1).single);
        case 'linear':
          final values = params.vector(inputs.length + 1);
          catalog[match[1]!] =
              LinearConsequent(intercept: values.last, coefficients: {
            for (var j = 0; j < inputs.length; j++) inputs[j].name: values[j]
          });
        default:
          line.fail('Only constant/linear Sugeno consequents are supported.');
      }
    }
    return catalog;
  }

  FuzzyVariable _variable(_Section section) {
    final count = section.get('NumMFs').count(maxMembershipsPerVariable);
    section.only(
        {'Name', 'Range', 'NumMFs', for (var i = 1; i <= count; i++) 'MF$i'});
    final range = section.get('Range').vector(2);
    final terms = <String, MembershipFunction>{};
    for (var i = 1; i <= count; i++) {
      final line = section.get('MF$i');
      final match = RegExp(r"^'([^']+)'\s*:\s*'([^']+)'\s*,\s*(\[.*\])$")
          .firstMatch(line.text);
      if (match == null) line.fail('Unsupported membership syntax.');
      final name = match[1]!;
      if (terms.containsKey(name)) line.fail('Duplicate membership name.');
      final parameters = _Line(match[3]!, line.number);
      try {
        terms[name] = switch (match[2]) {
          'trimf' => (() {
              final p = parameters.vector(3);
              return Triangle(p[0], p[1], p[2]);
            })(),
          'trapmf' => (() {
              final p = parameters.vector(4);
              return Trapezoid(p[0], p[1], p[2], p[3]);
            })(),
          'gaussmf' => (() {
              final p = parameters.vector(2);
              return Gaussian(p[1], p[0]);
            })(),
          _ => line.fail('Unsupported membership function.'),
        };
      } on ArgumentError {
        line.fail('Invalid membership parameters.');
      }
    }
    try {
      return FuzzyVariable(
          name: section.get('Name').quoted(),
          min: range[0],
          max: range[1],
          terms: terms);
    } on ArgumentError {
      section.header.fail('Invalid variable universe or name.');
    }
  }
}

String _uncomment(String text) {
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    if (text[i] == "'") quoted = !quoted;
    if (!quoted && text[i] == '%') return text.substring(0, i);
  }
  return text;
}

void _expect(_Line line, String expected) {
  if (line.quoted() != expected)
    line.fail('Unsupported method or engine type.');
}

TNorm _tnorm(_Line line) => switch (line.quoted()) {
      'min' => const Minimum(),
      'prod' => const AlgebraicProduct(),
      _ => line.fail('Unsupported conjunction or implication.'),
    };

final class _Section {
  _Section(this.header);
  final _Line header;
  final fields = <String, _Line>{};
  final rows = <_Line>[];
  _Line get(String name) => fields[name] ?? header.fail('Missing field $name.');
  void only(Set<String> allowed) {
    for (final entry in fields.entries) {
      if (!allowed.contains(entry.key))
        entry.value.fail('Unknown field ${entry.key}.');
    }
  }
}

final class _Line {
  _Line(this.text, this.number);
  final String text;
  final int number;
  Never fail(String message) =>
      throw FormatException('FIS line $number: $message');
  String quoted() {
    final match = RegExp(r"^'([^']+)'$").firstMatch(text.trim());
    if (match == null || match[1]!.trim().isEmpty)
      fail('Expected quoted nonempty string.');
    return match[1]!;
  }

  double numberValue() {
    if (!RegExp(r'^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$')
        .hasMatch(text.trim())) fail('Expected finite decimal number.');
    final value = double.tryParse(text.trim());
    if (value == null || !value.isFinite)
      fail('Expected finite decimal number.');
    return value;
  }

  int count(int max) {
    final value = int.tryParse(text.trim());
    if (value == null || value < 1 || value > max)
      fail('Count outside import limit.');
    return value;
  }

  List<double> vector(int count) {
    final value = text.trim();
    if (!value.startsWith('[') || !value.endsWith(']'))
      fail('Expected numeric vector.');
    final parts =
        value.substring(1, value.length - 1).trim().split(RegExp(r'\s+'));
    if (parts.length != count) fail('Unexpected vector length.');
    return [for (final part in parts) _Line(part, number).numberValue()];
  }
}
