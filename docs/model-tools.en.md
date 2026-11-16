# Versioned models and diagnostics

[Português](model-tools.pt-BR.md) · [JSON Schema v1](model-v1.schema.json) · [Class diagrams](architecture.en.md)

## Version 2 update

The default exporter now emits v2 and supports Tsukamoto as a third family.
Imports accept both v1 and v2. Use FuzzyModelCodec(exportVersion: 1) for legacy
Mamdani/Sugeno exports; Tsukamoto cannot be downgraded. The envelope and all earlier
component identifiers retain their meanings. v2 adds engineType=tsukamoto, bounded
monotonic outputs, validationSamples and inverseTolerance. See the [v2 schema](model-v2.schema.json)
and [Tsukamoto guide](tsukamoto.en.md). The v1 description below remains the legacy
profile, not the current default export version.

## Import and export

`FuzzyModelCodec` supports FuzzyEngine, SugenoEngine and TsukamotoEngine. Pass an engine directly
to encode, or wrap it in FuzzyModelDocument to retain a name, description and unit
labels. The core uses only dart:convert; it does not access files, networks or
external configuration services. File reading/writing belongs to the application.

```dart
final codec = FuzzyModelCodec();
final document = FuzzyModelDocument(
  engine: engine,
  name: 'Fan control',
  inputUnits: {'temperature': '°C'},
  outputUnits: {'fan': '%'},
);
final source = codec.encode(document);
final restored = codec.decode(source);
final restoredEngine = restored.engine as FuzzyEngine;
final report = const FuzzyDiagnostics().analyze(
  restored,
  samplesPerInput: 5,
  maxEvaluations: 10000,
);
print(restoredEngine.evaluate({'temperature': 20}).value('fan'));
print(report.nullOutputCounts);
```

The snippet assumes an existing Mamdani model with temperature/fan variables.
For complete executable code, run `dart run example/model_tools_example.dart`.
For Sugeno use the same codec, or use `decodeSugeno(source)` for a typed engine.
`decodeMamdani(source)` and `decodeSugeno(source)` return only an engine: use
`decode(source)` when metadata must be preserved. `toJson`/`fromJson` work with
maps; encode/decode work with JSON text. Imported objects are fully validated by
their model constructors. Exported maps are separate from model configuration.

## Schema version 1

The envelope requires schemaVersion, engineType, metadata, inputs, outputs, rules,
operators and settings. engineType is exactly mamdani or sugeno; version is the
integer value 1 (JSON-equivalent integral numbers such as 1.0 are accepted).
Unknown fields, versions, types and references are rejected, not ignored.
Examples: [Mamdani fixture](../test/fixtures/mamdani-v1.json) and
[Sugeno fixture](../test/fixtures/sugeno-v1.json).

| Component | v1 representation |
| --- | --- |
| Variable | name, min, max, terms keyed by linguistic name |
| Membership | type + ordered parameters array |
| DiscreteSet | type=discrete, parameters=[[x,degree], ...] |
| Condition | term(variable,term), and/or(left,right), not(operand), hedge(modifier,operand) |
| Hedges | very or somewhat |
| Operators | Named built-in conjunction, disjunction and standard negation |
| Mamdani settings | intervals, implication, aggregation, defuzzifier |
| Maxima defuzzifier | type plus explicit tolerance |
| Sugeno settings | aggregation=weightedAverage or weightedSum |
| Constant consequent | type=constant, value |
| Linear consequent | type=linear, intercept, coefficients keyed by input name |
| Metadata | Nullable name/description; inputUnits and outputUnits maps |

All eleven membership classes, three t-norms, three s-norms, five defuzzifiers,
Very/Somewhat and constant/linear consequents are supported. Parameter order
matches the public constructors in the [toolbox guide](toolbox.en.md).
Membership type identifiers are triangle, trapezoid, gaussian, ramp, sigmoid,
bell, sShape, zShape, piShape, rectangle and discrete. Operator identifiers are
minimum, algebraicProduct, boundedDifference, maximum, probabilisticSum and
boundedSum. The full field inventory lives in the checked-in schema.

Custom membership functions, operators, negation, hedges, defuzzifiers and crisp
callbacks are usable at runtime but throw UnsupportedError on export. v1 has no
plugin registry, eval, Dart source loading or textual expression execution.
Unsupported JSON types throw FormatException. Unit labels must reference declared
variables; they are preserved labels, not dimensional validation or conversions.
Metadata descriptions can contain arbitrary text and are never executed.

## Bounds and parsing behavior

Default codec limits:

| Option | Default | Meaning |
| --- | ---: | --- |
| maxSourceLength | 1000000 | UTF-16 code units in encode/decode text |
| maxNodes | 10000 | JSON values/containers, including metadata |
| maxDepth | 64 | Nested JSON depth and condition traversal |
| maxOutputSamples | 1000000 | Sum of intervals+1 across all Mamdani outputs |

Text size is checked before jsonDecode. Node/depth validation follows parsing and
precedes engine construction; direct map imports also get these checks, including
cycles and nonfinite values. Export applies the same structural/sample budgets.
Integral numeric intervals such as 1000.0 are accepted. These limits are not a CPU
sandbox for arbitrary custom runtime callbacks or arbitrary diagnostic grids.
Dart's JSON parser handles syntax and duplicate property names; the codec is not
a canonicalization/signature protocol. Reject duplicate-key input upstream if your
application requires that policy. The JSON Schema describes structure; runtime
validation additionally checks parameter order, references, units and configured
resource limits. No source file is rewritten automatically. Re-encoding with the default codec emits v2; select exportVersion: 1 to preserve the legacy envelope.

## Sampling diagnostics

FuzzyDiagnostics analyzes any of the three engines or a document and never changes its rules.
It samples the full Cartesian product of uniform input grids, including endpoints.
With k inputs and n samples per input, there are n^k evaluations; the default is
11 samples per input with a cap of 10000 evaluations. A grid exceeding the cap is
rejected before callbacks execute; it is not silently truncated. Membership
functions, conditions and consequents run locally during analysis, so custom
components must be deterministic and side-effect free.

| Finding code | Interpretation |
| --- | --- |
| inputCoverageGap | No input term above threshold at a sampled coordinate |
| inputMembershipFailure | Invalid/throwing membership evaluation at sampled coordinates |
| zeroWeightRule | Explicitly disabled rule (informational) |
| ruleNotObserved | No activation above threshold on successful sampled evaluations |
| outputWithoutDecision | Null output on successful sampled evaluations |
| duplicateRules | Structurally equal antecedent/output/consequent/weight |
| competingConsequents | Same structural antecedent/output, different active consequent definitions |
| structuralAnalysisSkipped | Custom or overly deep components cannot be compared structurally |
| evaluationFailure | A sampled engine evaluation threw |

The default threshold is zero and activation means strength > threshold. Changing
it changes the report, not engine inference. Input coverage compares membership
degrees to that same threshold. Rule/output counters exclude failed evaluations.
UncoveredEvaluations counts successful points where no rule exceeded the threshold,
which is distinct from a null output. A rule can activate while a Mamdani output
grid still misses a narrow consequent.

These are **observations, not continuous coverage proofs or automatic conflict
resolution**. A rule missed on the grid may activate between samples. A structurally
different antecedent is not simplified into logical equivalence; AND/OR operands
are not reordered. Linear coefficient key order is canonicalized for comparison.
Duplicate rules and competing consequents may be deliberate, especially with
weighted sums; they are never removed. A competing-consequent finding is not proof
of mathematical contradiction. Unit consistency is not inferred.

Reports expose immutable grids, gaps, activation counts, maxima, null-output counts,
failure counts/examples and findings. toJson returns portable report data. Raw
callback error messages and stack traces are omitted. Up to three failed input
examples are retained by default; set maxFailureExamples=0 to retain none. Reports
can contain application input values, so sharing/export is the caller's decision.
Runtime sampling still works for custom components even when structural checks
are skipped. All-failed grids do not falsely label rules as unobserved.

## Reproduce the example

The example intentionally includes a duplicate hot/high rule, a competing hot/low
rule and a disabled cold rule. Five temperature samples yield one null fan output,
a duplicate finding and a competing-consequent warning. These findings explain
the model without claiming the model is wrong or modifying it.

See [benchmark notes](performance.md) for the measured serialization/diagnostic cost.
