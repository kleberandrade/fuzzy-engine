# Takagi–Sugeno inference

[Português](sugeno.pt-BR.md) · [Class diagrams](architecture.en.md)

## Two engine families

| Topic | FuzzyEngine (Mamdani defaults) | SugenoEngine |
| --- | --- | --- |
| Inputs | FuzzyVariable | Same FuzzyVariable |
| Conditions | Terms, AND/OR/NOT, hedges | Same conditions and configurable operators |
| Consequents | Named output membership sets | Crisp constants or named linear equations |
| Output model | FuzzyVariable with universe and terms | SugenoOutput with name only |
| Decision | Sampled implication, aggregation and defuzzification | Weighted average or explicit weighted sum |
| Diagnostics | Memberships, rule activations, sampled curves | Memberships, rule activations, crisp consequents, raw contributions, total weights |

Use Mamdani when linguistic output sets are useful; use Sugeno when rules should
select or blend numeric equations. The package does not learn rules or fit
coefficients. Both engines are type-1 and use deterministic double arithmetic.
They are separate APIs; a hybrid engine combining both output families in one
instance is not implemented.

## Complete model fragment

Import `package:fuzzy_engine/fuzzy_engine.dart`, then use the following in main:

```dart
final inputs = [
  FuzzyVariable(name: 'temperature', min: 0, max: 40, terms: {
    'cold': Ramp(40, 0),
    'hot': Ramp(0, 40),
  }),
];
final engine = SugenoEngine(
  inputs: inputs,
  outputs: [SugenoOutput('fan')],
  aggregation: SugenoAggregation.weightedAverage,
  rules: [
    SugenoRule(
      name: 'cold',
      when: const Term('temperature', 'cold'),
      output: 'fan',
      consequent: ConstantConsequent(20),
    ),
    SugenoRule(
      name: 'hot',
      when: const Term('temperature', 'hot'),
      output: 'fan',
      weight: .5,
      consequent: LinearConsequent(
        intercept: 20,
        coefficients: {'temperature': 2},
      ),
    ),
  ],
);
final result = engine.evaluate({'temperature': 10});
print(result.value('fan')); // Approximately 22.8571428571
```

The example mixes a constant and a linear consequent, which is supported.
A constant-only model is zero order. Linear equations provide first-order
consequents: `z = intercept + sum(coefficient[name] * crispInput[name])`.
Omitted coefficients mean no dependency on that input. An empty coefficient map
is equivalent to a constant intercept. Negative coefficients and crisp outputs
outside the membership-degree interval are valid.

## Reduction equations

Let a_i be the degree of a rule's complete antecedent and q_i its configured
weight. Its final strength is w_i = a_i × q_i. The consequent evaluates against
**original crisp inputs**, producing z_i. For each output, only its active rules
are included:

- `weightedAverage`: y = sum(w_i × z_i) / sum(w_i).
- `weightedSum`: y = sum(w_i × z_i), with no normalization.

The first is the default normalized Sugeno decision. The second is an explicit
alternative and can exceed every individual consequent value. Changing rule count
can change a weighted sum even when duplicating rules leaves the average unchanged.
Neither method uses an integration grid, Mamdani implication, output membership
sets or `Defuzzifier`. All rules and outputs in one engine use the selected method.

`SugenoOutput` deliberately has no output range. There is no application-domain
clamping, and no implicit fallback. An output with no positive-strength rule
returns **null in both modes**, even though a purely algebraic empty sum would be
zero. A positively activated zero consequent returns 0, distinguishing it from
no decision. Declared outputs without any rules are permitted and remain null.

## Explanations and validation

`SugenoResult.outputs`, `memberships`, `rules` and `totalWeights` are immutable.
Each `SugenoActivation` contains the rule, antecedent, strength, `consequentValue`
and raw `weightedContribution` (w × z). Inactive/zero-weight consequents are not
evaluated, and both consequent/contribution fields are null for them. Raw
contributions are not already normalized shares of a weighted average.

Inputs must exactly match their declared names, be finite and inside their
universes. Construction rejects empty models, duplicate input/output/rule names,
unknown antecedent terms and unknown consequent input references. Output and input
names have separate namespaces. All built-in parameters must be finite; weights
are in the closed interval from zero to one. Unknown output lookup throws
ArgumentError. Nonfinite active consequents or unrepresentable reduction results
throw StateError rather than returning NaN or infinity.

Implement `SugenoConsequent` for a custom deterministic crisp function. Declare
all used input names through `references`; the engine validates them even for
inactive rules. The callback receives an immutable crisp-input map. The engine
checks that the returned value is finite but cannot prove custom references are
complete or stop a custom callback from throwing its own error. Keep custom
configuration immutable after constructing an engine. This API executes caller-
supplied Dart code, not strings or expressions from external configuration.

## Numerical behavior

The average rescales positive strengths by their largest value before reduction,
so very small common strengths do not destroy a valid average. Products are
formed before division by the scaled denominator to avoid underflowing normalized
weights prematurely. Compensated summation reduces cancellation error, with a
scaled fallback if an intermediate sum overflows.

Averages are restricted to the mathematical minimum/maximum of active consequents
to contain endpoint rounding at extreme magnitudes. This is not an application
output-range clamp. Weighted sums have no such restriction; a genuinely
unrepresentable sum throws StateError. Linear consequent products must themselves
be representable, even if later terms might cancel them. All calculations remain
finite-precision: extreme scale differences can lose information. Antecedent ×
rule-weight formation and raw diagnostic contributions can underflow to zero;
normalization cannot recover a strength that has already become exactly zero.

## Executable comparison

```sh
dart run example/sugeno_example.dart
```

At temperature=10, cold=0.75 and hot=0.25; the hot rule weight is 0.5, so final
strengths are 0.75 and 0.125 (total 0.875).

| Consequents | Cold z | Hot z | Weighted average | Weighted sum |
| --- | ---: | ---: | ---: | ---: |
| Constants 20 and 80 | 20 | 80 | 28.5714 | 25.0000 |
| Linear 10+t and 20+2t | 20 | 40 | 22.8571 | 20.0000 |

Values illustrate an abstract fan-control score, not calibrated actuator commands.
See [benchmarks](performance.md); Sugeno and Mamdani benchmark scenarios are not
numerically equivalent controllers and should not be ranked as interchangeable.
