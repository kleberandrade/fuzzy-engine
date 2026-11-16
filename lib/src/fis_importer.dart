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

/// Adapted Mamdani outputs with an unchanged core explanation.
final class FisEvaluation {
  FisEvaluation._(
      this.trace, Map<String, double?> values, Set<String> fallbacks)
      : values = Map.unmodifiable(values),
        fallbackOutputs = Set.unmodifiable(fallbacks);

  /// Unmodified core result, including null outputs and activation strengths.
  final FuzzyResult trace;

  /// Adapted decisions in output declaration order.
  final Map<String, double?> values;

  /// Outputs whose null decision was replaced by their universe midpoint.
  final Set<String> fallbackOutputs;

  /// Single-output convenience; throws StateError for multi-output models.
  double? get value => values.values.single;

  /// Whether any output used a midpoint fallback.
  bool get usedFallback => fallbackOutputs.isNotEmpty;
}

/// Imported Mamdani model and its explicit per-output adapter policy.
final class FisModel {
  FisModel._(this.name, this.engine, this.noDecisionPolicy);

  /// System name from the file.
  final String name;

  /// Core inference configuration. Direct evaluation preserves core semantics.
  final FuzzyEngine engine;

  /// Policy supplied by the caller, applied independently to every output.
  final FisNoDecisionPolicy noDecisionPolicy;

  /// Evaluate all outputs while retaining the original trace.
  FisEvaluation evaluate(Map<String, double> inputs) {
    final trace = engine.evaluate(inputs);
    final values = <String, double?>{};
    final fallbacks = <String>{};
    for (final output in engine.outputs) {
      values[output.name] = _adapt(trace.value(output.name), output.name,
          output.min, output.max, noDecisionPolicy, fallbacks);
    }
    return FisEvaluation._(trace, values, fallbacks);
  }
}

/// Finite Sugeno FIS universe and named consequent catalog for one output.
/// Bounds supply a midpoint fallback; they never clamp crisp consequents.
final class FisSugenoOutput {
  /// Retains unused terms and their declaration order too.
  FisSugenoOutput(
      {required this.min,
      required this.max,
      required Map<String, SugenoConsequent> consequents})
      : consequents = Map.unmodifiable(consequents) {
    if (!min.isFinite ||
        !max.isFinite ||
        min >= max ||
        !(max - min).isFinite ||
        consequents.isEmpty ||
        consequents.keys.any((name) => name.trim().isEmpty)) {
      throw ArgumentError('Invalid Sugeno FIS output.');
    }
  }

  /// Lower bound used for fallback only.
  final double min;

  /// Upper bound used for fallback only.
  final double max;

  /// Named consequents, including unused terms, in declaration order.
  final Map<String, SugenoConsequent> consequents;
}

/// Sugeno adapter retaining each output's FIS universe and consequent catalog.
final class FisSugenoModel {
  /// Backward-compatible single-output constructor.
  FisSugenoModel(
      {required String name,
      required SugenoEngine engine,
      required double outputMin,
      required double outputMax,
      required Map<String, SugenoConsequent> consequents,
      required FisNoDecisionPolicy noDecisionPolicy})
      : this.multiOutput(
            name: name,
            engine: engine,
            outputs: {
              engine.outputs.single.name: FisSugenoOutput(
                  min: outputMin, max: outputMax, consequents: consequents)
            },
            noDecisionPolicy: noDecisionPolicy);

  /// Every engine output needs its own range and catalog. Rules must use
  /// consequent instances from the catalog of the output they target.
  FisSugenoModel.multiOutput(
      {required this.name,
      required this.engine,
      required Map<String, FisSugenoOutput> outputs,
      required this.noDecisionPolicy})
      : outputs = Map.unmodifiable({
          for (final output in engine.outputs)
            if (outputs.containsKey(output.name))
              output.name: outputs[output.name]!
        }) {
    if (name.trim().isEmpty ||
        outputs.length != engine.outputs.length ||
        this.outputs.length != outputs.length ||
        engine.rules.any((rule) => !this
            .outputs[rule.output]!
            .consequents
            .values
            .contains(rule.consequent))) {
      throw ArgumentError('Invalid Sugeno FIS model.');
    }
    final inputs = engine.inputs.map((input) => input.name).toSet();
    if (outputs.values.any((output) => output.consequents.values
        .any((c) => c.references.any((name) => !inputs.contains(name))))) {
      throw ArgumentError('Unknown consequent input in FIS catalog.');
    }
  }

  /// FIS system name.
  final String name;

  /// Sugeno inference engine.
  final SugenoEngine engine;

  /// Output metadata keyed by engine output name, in engine declaration order.
  final Map<String, FisSugenoOutput> outputs;

  /// Single-output lower bound; throws StateError for multi-output models.
  double get outputMin => outputs.values.single.min;

  /// Single-output upper bound; throws StateError for multi-output models.
  double get outputMax => outputs.values.single.max;

  /// Single-output catalog; throws StateError for multi-output models.
  Map<String, SugenoConsequent> get consequents =>
      outputs.values.single.consequents;

  /// Explicit adapter behavior when an output has no active rule.
  final FisNoDecisionPolicy noDecisionPolicy;

  /// Evaluate all outputs without modifying the original trace.
  FisSugenoEvaluation evaluate(Map<String, double> inputs) {
    final trace = engine.evaluate(inputs);
    final values = <String, double?>{};
    final fallbacks = <String>{};
    for (final output in outputs.entries) {
      values[output.key] = _adapt(trace.value(output.key), output.key,
          output.value.min, output.value.max, noDecisionPolicy, fallbacks);
    }
    return FisSugenoEvaluation._(trace, values, fallbacks);
  }
}

/// Adapted Sugeno outputs with their unchanged core explanation.
final class FisSugenoEvaluation {
  FisSugenoEvaluation._(
      this.trace, Map<String, double?> values, Set<String> fallbacks)
      : values = Map.unmodifiable(values),
        fallbackOutputs = Set.unmodifiable(fallbacks);

  /// Original core result.
  final SugenoResult trace;

  /// Adapted decisions in output declaration order.
  final Map<String, double?> values;

  /// Outputs whose null decision was replaced by their universe midpoint.
  final Set<String> fallbackOutputs;

  /// Single-output convenience; throws StateError for multi-output models.
  double? get value => values.values.single;

  /// Whether any output used a midpoint fallback.
  bool get usedFallback => fallbackOutputs.isNotEmpty;
}

double? _adapt(double? value, String name, double min, double max,
    FisNoDecisionPolicy policy, Set<String> fallbacks) {
  if (value != null) return value;
  switch (policy) {
    case FisNoDecisionPolicy.preserveNull:
      return null;
    case FisNoDecisionPolicy.midpoint:
      fallbacks.add(name);
      return min + (max - min) / 2;
    case FisNoDecisionPolicy.throwError:
      throw StateError('FIS output "$name" has no decision.');
  }
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
    this.maxOutputs = 64,
    this.maxMembershipsPerVariable = 256,
  }) {
    if (intervals < 2 ||
        intervals > 1000000 ||
        maxSourceLength < 1 ||
        maxRules < 1 ||
        maxInputs < 1 ||
        maxOutputs < 1 ||
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

  /// Maximum source rows and expanded core rules (one per active output).
  final int maxRules;

  /// Maximum number of inputs.
  final int maxInputs;

  /// Maximum number of output variables.
  final int maxOutputs;

  /// Maximum memberships on each input or output.
  final int maxMembershipsPerVariable;

  /// Parses System, InputN, OutputN and Rules sections. Names are single-quoted
  /// without embedded quotes; percent comments outside quoted strings are allowed.
  FisModel decode(String source) => _decode(source, false) as FisModel;

  /// Import a Sugeno FIS with constant/linear consequents.
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
      final header =
          RegExp(r'^\[(System|Input[1-9][0-9]*|Output[1-9][0-9]*|Rules)\]$')
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
          if (section.fields.containsKey(field[1])) {
            line.fail('Duplicate field.');
          }
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
    final outputCount = system.get('NumOutputs').count(maxOutputs);
    final expected = {
      'System',
      'Rules',
      for (var i = 1; i <= outputCount; i++) 'Output$i',
      for (var i = 1; i <= count; i++) 'Input$i'
    };
    if (sections.length != expected.length ||
        !expected.every(sections.containsKey)) {
      system.header.fail('Missing or undeclared sections.');
    }
    final inputs = [
      for (var i = 1; i <= count; i++) _variable(sections['Input$i']!)
    ];
    final outSections = [
      for (var i = 1; i <= outputCount; i++) sections['Output$i']!
    ];
    final outputs = sugeno
        ? <FuzzyVariable>[]
        : [for (final section in outSections) _variable(section)];
    final outputNames = [
      for (var i = 0; i < outputCount; i++)
        sugeno ? outSections[i].get('Name').quoted() : outputs[i].name
    ];
    final catalogs = [
      for (final section in outSections)
        sugeno ? _consequents(section, inputs) : <String, SugenoConsequent>{}
    ];
    final outputTerms = [
      for (var i = 0; i < outputCount; i++)
        sugeno ? catalogs[i].keys.toList() : outputs[i].terms.keys.toList()
    ];
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
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final match =
          RegExp(r'^([0-9\s-]+),\s*([0-9\s]+)\s*\(([^()]+)\)\s*:\s*([12])$')
              .firstMatch(row.text);
      if (match == null) row.fail('Unsupported rule syntax.');
      final indices = match[1]!.trim().split(RegExp(r'\s+'));
      if (indices.length != inputs.length) {
        row.fail('Input index count mismatch.');
      }
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
      if (condition == null) {
        row.fail('All-ignored antecedents are unsupported.');
      }
      final indicesOut = match[2]!.trim().split(RegExp(r'\s+'));
      if (indicesOut.length != outputCount) {
        row.fail('Output index count mismatch.');
      }
      final weight = _Line(match[3]!, row.number).numberValue();
      if (weight < 0 || weight > 1) row.fail('Rule weight must be in [0, 1].');
      var activeOutputs = 0;
      for (var o = 0; o < outputCount; o++) {
        final index = int.tryParse(indicesOut[o]);
        if (index == null || index < 0 || index > outputTerms[o].length) {
          row.fail('Output index out of range.');
        }
        if (index == 0) continue;
        activeOutputs++;
        if (rules.length + sugenoRules.length >= maxRules) {
          row.fail('Expanded core rule limit exceeded.');
        }
        // A FIS row with several consequents becomes independent core rules.
        // Keep the historic single-output label, otherwise identify row/output.
        final label = outputCount == 1
            ? 'rule${rowIndex + 1}'
            : 'rule${rowIndex + 1}:output${o + 1}';
        if (sugeno) {
          sugenoRules.add(SugenoRule(
              name: label,
              when: condition,
              output: outputNames[o],
              consequent: catalogs[o][outputTerms[o][index - 1]]!,
              weight: weight));
        } else {
          rules.add(FuzzyRule(
              name: label,
              when: condition,
              output: outputNames[o],
              term: outputTerms[o][index - 1],
              weight: weight));
        }
      }
      if (activeOutputs == 0) {
        row.fail('All-ignored consequents are unsupported.');
      }
    }
    try {
      if (sugeno) {
        final metadata = <String, FisSugenoOutput>{};
        for (var i = 0; i < outputCount; i++) {
          final range = outSections[i].get('Range').vector(2);
          if (metadata.containsKey(outputNames[i])) {
            outSections[i].header.fail('Duplicate output name.');
          }
          metadata[outputNames[i]] = FisSugenoOutput(
              min: range[0], max: range[1], consequents: catalogs[i]);
        }
        return FisSugenoModel.multiOutput(
            name: name,
            outputs: metadata,
            noDecisionPolicy: noDecisionPolicy,
            engine: SugenoEngine(
                inputs: inputs,
                outputs: [for (final name in outputNames) SugenoOutput(name)],
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
              outputs: outputs,
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
      if (match == null || match[1]!.trim().isEmpty) {
        line.fail('Invalid Sugeno consequent.');
      }
      if (catalog.containsKey(match[1])) {
        line.fail('Duplicate consequent name.');
      }
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
  if (line.quoted() != expected) {
    line.fail('Unsupported method or engine type.');
  }
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
      if (!allowed.contains(entry.key)) {
        entry.value.fail('Unknown field ${entry.key}.');
      }
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
    if (match == null || match[1]!.trim().isEmpty) {
      fail('Expected quoted nonempty string.');
    }
    return match[1]!;
  }

  double numberValue() {
    if (!RegExp(r'^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$')
        .hasMatch(text.trim())) {
      fail('Expected finite decimal number.');
    }
    final value = double.tryParse(text.trim());
    if (value == null || !value.isFinite) {
      fail('Expected finite decimal number.');
    }
    return value;
  }

  int count(int max) {
    final value = int.tryParse(text.trim());
    if (value == null || value < 1 || value > max) {
      fail('Count outside import limit.');
    }
    return value;
  }

  List<double> vector(int count) {
    final value = text.trim();
    if (!value.startsWith('[') || !value.endsWith(']')) {
      fail('Expected numeric vector.');
    }
    final parts =
        value.substring(1, value.length - 1).trim().split(RegExp(r'\s+'));
    if (parts.length != count) fail('Unexpected vector length.');
    return [for (final part in parts) _Line(part, number).numberValue()];
  }
}
