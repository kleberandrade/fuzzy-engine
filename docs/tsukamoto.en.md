# Tsukamoto and the Larsen preset

[Português](tsukamoto.pt-BR.md) · [Class diagrams](architecture.en.md)

## Tsukamoto inference

A Tsukamoto rule turns its weighted firing strength into a crisp output by
inverting a monotonic output membership function. The engine then takes the
normalized weighted average of those crisp inverse values. Unlike Mamdani it
neither aggregates a sampled output curve nor applies an integral defuzzifier;
unlike Sugeno it derives each crisp consequent from the firing strength, not a
constant or a crisp-input equation.

Let a_i be the complete antecedent degree and q_i the rule weight:
w_i = a_i × q_i, z_i = inverse_i(w_i), y = sum(w_i × z_i) / sum(w_i).
This package explicitly applies rule weight **before inversion and again as the
averaging strength**. Other implementations' weight conventions must be checked
before asserting cross-library equivalence. There is no unnormalized-sum option
on TsukamotoEngine.

```dart
final engine = TsukamotoEngine(
  inputs: [
    FuzzyVariable(name: 'demand', min: 0, max: 1, terms: {
      'low': Ramp(1, 0),
      'high': Ramp(0, 1),
    }),
  ],
  outputs: [
    TsukamotoOutput(name: 'power', min: 0, max: 100, terms: {
      'low': Ramp(100, 0),
      'high': Ramp(0, 100),
    }),
  ],
  rules: [
    TsukamotoRule(name: 'low', when: const Term('demand', 'low'),
      output: 'power', term: 'low'),
    TsukamotoRule(name: 'high', when: const Term('demand', 'high'),
      output: 'power', term: 'high', weight: .5),
  ],
);
final result = engine.evaluate({'demand': .25});
print(result.value('power')); // Approximately 23.2142857143
```

At demand=0.25, strengths are 0.75 and 0.125. The descending ramp inverts 0.75 to
25; the ascending ramp inverts 0.125 to 12.5. The average is
(0.75 × 25 + 0.125 × 12.5) / 0.875 = 325/14 ≈ 23.214286.
With both rule weights equal to one, the same paired ramps give 100 × demand.
These are educational power percentages, not calibrated actuator commands.

## Invertible terms

`MonotonicMembershipFunction` extends MembershipFunction with domainMin, domainMax,
isIncreasing and inverse(degree). Built-in implementations are:

| Function | Direction | Generalized inverse |
| --- | --- | --- |
| Ramp(start,end) | Either | start + (end−start) × degree |
| SShape(a,b) | Increasing | a + (b−a) × sqrt(degree/2) for degree <= 0.5; mirrored upper branch |
| ZShape(a,b) | Decreasing | SShape(a,b).inverse(1−degree) |

The finite transition domain, not the saturated tails, defines endpoint selection.
Ramp.inverse(0) is start and inverse(1) is end; S/Z use their finite transition
endpoints. Direct built-in inverse calls reject nonfinite degrees or values outside
zero to one. Forward membership behavior of these classes is unchanged.

The mathematical sigmoid inverse is infinite at degrees zero/one, so Sigmoid is
not silently accepted as a finite Tsukamoto output. Triangle, bell and other
nonmonotonic functions cannot be used as Tsukamoto output terms. All existing
membership functions remain available as input terms.

TsukamotoOutput declares a finite universe and an immutable map of monotonic terms.
Each transition domain must be a finite positive interval inside that universe;
it may occupy only a subset. The final weighted decision stays within the active
inverse-value convex hull and output universe. An output with no positive-strength
rule returns null. Inactive rules expose null inverseValue/weightedContribution.
Multiple outputs, input operators, hedges and strict input validation are supported.

## Validation and custom extensions

The constructor probes each term's forward monotonicity, endpoint coverage,
inverse monotonicity and inverse/forward consistency. Defaults: validationSamples=33
(inclusive range 2..1001), inverseTolerance=1e-9 (absolute degree error, permitted
range 0..0.001). Zero tolerance requests exact floating-point consistency and can
reject otherwise reasonable numerical inverses.

Every active inverse is also checked at runtime: it must be finite, inside its
transition domain and satisfy abs(degree(inverse(w))−w) <= inverseTolerance.
A runtime failure throws StateError and sampling diagnostics record it as a failed
evaluation. Constructor-detected invalid inverse configuration is rejected.

Built-in inverses are analytical. Finite probes do **not** prove that arbitrary
custom functions are monotonic everywhere; custom implementations must be immutable,
deterministic and fulfill the interface contract. All terms are probed at construction,
even when no active rule currently targets them. An unused term's inverse is not
called during inference. Endpoint and arithmetic rounding follow double precision.
Tiny weighted strengths can underflow to zero before inversion. The shared stable
weighted-average arithmetic is the same as [Sugeno](sugeno.en.md).

## Explanations, JSON and diagnostics

TsukamotoResult exposes immutable outputs, memberships, rules and totalWeights.
Each TsukamotoActivation records the rule, antecedent, strength and inverseValue;
weightedContribution is the raw w × z product, not a normalized share.

```dart
final codec = FuzzyModelCodec(); // Exports schema v2 by default.
final source = codec.encode(engine);
final restored = codec.decodeTsukamoto(source);
final report = const FuzzyDiagnostics().analyze(restored, samplesPerInput: 5);
```

Schema v2 supports built-in Ramp/SShape/ZShape output terms, validation settings,
metadata and all shared antecedent features. Custom monotonic classes remain
runtime extensions and cannot be serialized. v1 imports for Mamdani/Sugeno remain
supported; use FuzzyModelCodec(exportVersion: 1) for legacy export. Tsukamoto cannot
be exported as v1. Schemas: [v1](model-v1.schema.json), [v2](model-v2.schema.json).
An independent [Tsukamoto v2 fixture](../test/fixtures/tsukamoto-v2.json) checks the
hand-derived weighted decision, not just a serializer round-trip.

## Larsen convenience constructor

```dart
final larsen = FuzzyEngine.larsen(
  inputs: inputs,
  outputs: outputs,
  rules: rules,
);
```

The preset selects AlgebraicProduct implication. Default antecedent operators,
max aggregation, centroid and 1000 integration intervals remain unchanged; these
other settings can be configured explicitly. It is exactly the existing Mamdani
pipeline with product scaling instead of min clipping. JSON uses engineType=mamdani
and implication=algebraicProduct rather than inventing another schema family.
The existing FuzzyEngine constructor keeps its min-implication default.

## Executable example

```sh
dart run example/tsukamoto_example.dart
dart run benchmark/tsukamoto_benchmark.dart 1000
```

FCL/FIS import/export is **not implemented**. See the [interop profile proposal](interoperability.en.md)
for the explicit remaining work, including no-rule semantics and independent
reference fixtures before compatibility claims.

Conceptual reference: [FuzzyLite technical paper](https://fuzzylite.com/downloads/FuzzyLite-Libraries.pdf).
