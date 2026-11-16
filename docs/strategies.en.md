# Configurable inference strategies

[Português](strategies.pt-BR.md) · [Architecture](architecture.en.md)

## Defaults and compatibility

Existing `FuzzyEngine` and `Condition.evaluate(values)` calls keep their defaults:
min AND, max OR, standard complement, min implication, max aggregation and centroid.
Rule weights still multiply the completed antecedent degree, after AND/OR/NOT.
The additional `operators` argument on `Condition.evaluate` is optional and named.

```dart
final engine = FuzzyEngine(
  inputs: inputs,
  outputs: outputs,
  rules: rules,
  operators: const FuzzyOperators(
    conjunction: AlgebraicProduct(),
    disjunction: ProbabilisticSum(),
  ),
  implication: const AlgebraicProduct(),
  aggregation: const ProbabilisticSum(),
  defuzzifier: const Centroid(),
  intervals: 1000,
);
```

`inputs`, `outputs` and `rules` above are existing model configuration lists.
For a complete executable model, run `dart run example/strategies_example.dart`.
It demonstrates product AND, product implication, probabilistic aggregation,
curve inspection and an application-defined maximum selector.

## Strategy choices

| Setting | Interface | Default | Additional built-ins |
| --- | --- | --- | --- |
| operators.conjunction | TNorm | Minimum | AlgebraicProduct, BoundedDifference |
| operators.disjunction | SNorm | Maximum | ProbabilisticSum, BoundedSum |
| operators.negation | FuzzyNegation | StandardNegation | Custom implementations |
| implication | TNorm | Minimum | AlgebraicProduct, BoundedDifference |
| aggregation | SNorm | Maximum | ProbabilisticSum, BoundedSum |
| defuzzifier | Defuzzifier | Centroid | Bisector, SmallestOfMaximum, LargestOfMaximum, MeanOfMaximum, custom |

Product implication scales the consequent instead of clipping it; this is
Larsen-style implication. It does not create Sugeno consequents. All choices
currently apply engine-wide, not per output or per rule block. Antecedent operators
and implication are independent settings: selecting product AND does not change
implication automatically.

## Formula reference

| Strategy | Formula |
| --- | --- |
| Minimum | min(a, b) |
| AlgebraicProduct | a × b |
| BoundedDifference | max(0, a + b − 1) |
| Maximum | max(a, b) |
| ProbabilisticSum | a + b − a × b |
| BoundedSum | min(1, a + b) |
| StandardNegation | 1 − a |

The probabilistic-sum implementation uses the algebraically equivalent
`a + (1 - a) * b` to reduce endpoint rounding errors. Its name does not make
membership degrees into probabilities. T-norm and s-norm laws, such as neutral
elements, monotonicity, commutativity and associativity, are the implementer's
responsibility for custom classes; runtime range validation cannot prove them.
Strategies should be deterministic and immutable.

## Defuzzifier contract and output curves

Implement `Defuzzifier.defuzzify(SampledFuzzySet output)`. Samples are uniformly
spaced with both endpoints included. `degrees` is immutable, `intervals` is
sample count minus one, and `xAt(i)` maps an index to the output universe.

Return null only when the sampled set has zero area; otherwise return a finite
value inside the universe. The engine returns null for zero area without calling
the strategy, preventing a custom strategy from inventing an implicit fallback.
For positive area, null, NaN, infinity and out-of-range results throw `StateError`.
Custom operator or membership results outside the finite interval zero to one
also throw `StateError`; invalid `SampledFuzzySet` construction throws `ArgumentError`.
Built-in operator methods assume valid degree arguments when called directly.

`result.outputSets['fan']` exposes the exact aggregated samples used during
inference. These are combined consequent curves, not separate additive rule
contributions. Sampling can miss sets narrower than the grid: zero sampled area
is still null even if the continuous curve has positive area between samples.
`Centroid` uses composite trapezoidal quadrature, retaining the previous numerical
method. The example's `RightmostMaximum` uses exact equality on sampled peaks;
it is a custom example, not a new built-in defuzzifier or an interpolated maximum.

Retaining output curves costs O(outputs × intervals) memory. The engine remains
synchronous. See [benchmark notes](performance.md) before choosing grid sizes for
large models or frame-by-frame UI evaluations.

[See all membership functions, hedges and defuzzifiers](toolbox.en.md). The custom RightmostMaximum example now has the same exact-grid selection semantics as the built-in LargestOfMaximum(tolerance: 0).
