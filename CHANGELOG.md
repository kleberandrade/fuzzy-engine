## Unreleased

- Add five pub.dev discovery topics and a reproducible release validation script.
- Clarify package/repository naming and the separate first-publication procedure.

- Add monotonic Tsukamoto inference with analytical Ramp/SShape/ZShape inverses.
- Validate inverse domains, endpoints, monotonic probes and active-rule consistency.
- Add the explicit FuzzyEngine.larsen product-implication preset.
- Export JSON v2 for all three engine families; retain v1 import and legacy export.
- Extend sampling diagnostics and immutable explanations to Tsukamoto.
- Share stable weighted arithmetic with Sugeno; all previous numerical tests pass.
- Add 22 tests, a reference fixture, example, benchmark and interoperability scope.

- Add strict versioned JSON codec and schema for built-in Mamdani/Sugeno models.
- Preserve names, descriptions and input/output unit metadata in model documents.
- Add typed ConditionVisitor inspection and bounded sampling/structural diagnostics.
- Reject unsupported/custom JSON components and apply source/node/depth/sample budgets.
- Add 30 tests, independent reference fixtures, an example and a microbenchmark.

- Add SugenoEngine with constant, linear and custom crisp consequents.
- Add distinct weighted-average/weighted-sum reductions and immutable explanations.
- Share input validation and fuzzification with the existing Mamdani engine.
- Add 24 analytical/edge-case tests, a Sugeno example and a microbenchmark.

- Add Ramp, Sigmoid, Bell, SShape, ZShape, PiShape, Rectangle and DiscreteSet.
- Add Bisector, SmallestOfMaximum, LargestOfMaximum and MeanOfMaximum.
- Add linguistic Very/Somewhat modifiers and the FuzzyHedge extension interface.
- Stabilize Gaussian/Sigmoid differences and Bell evaluation at extreme finite inputs.
- Add 36 tests, a two-input irrigation example and component benchmarks.

- Add configurable TNorm, SNorm, FuzzyNegation and Defuzzifier extension points.
- Add product/bounded conjunction and probabilistic/bounded disjunction strategies.
- Expose immutable aggregated SampledFuzzySet curves through result.outputSets.
- Preserve default min/max/complement/centroid inference and rule weighting.
- Add analytical strategy tests, an executable example and a microbenchmark.
- Update bilingual guides, class diagrams and roadmap progress.

## 0.1.0

- Initial Mamdani engine with min implication, max aggregation and numerical centroid.
- Triangular, trapezoidal and Gaussian membership functions.
- Composable AND, OR, NOT conditions and weighted rules.
- Immutable explanations, model validation and explicit null outputs.
- English/Portuguese guides and three interactive Flutter scenarios.

- Add multi-input inference, nested-rule, numerical convergence and input-space tests.
- Separate pure Dart and Flutter CI resolution and add a minimum Dart SDK check.
