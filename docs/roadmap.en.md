# Scope and roadmap

[Português](roadmap.pt-BR.md) · [Implemented architecture](architecture.en.md)

## Progress

The extensible pipeline stage is implemented locally with 92 passing tests, public
strategy contracts and a runnable example. New remote CI validation is pending.
The Mamdani toolbox stage is also implemented: eleven membership functions,
five defuzzifiers and Very/Somewhat modifiers. Sugeno with constant/linear consequents and both reductions is also implemented.
Model portability and diagnostics are the next stage.

## Current scope

The development version includes type-1 Mamdani and Sugeno engines. It is not a complete fuzzy logic
framework. Multi-input/output inference exists, but the Flutter scenarios each
use one input. Implemented items are marked below. Remaining roadmap entries are proposals,
not shipped functionality or release-date commitments.

| Area | Implemented | Missing / proposed |
| --- | --- | --- |
| Inference | Mamdani defaults, product implication, Sugeno zero/first order | Tsukamoto and hybrid engines |
| AND / OR / NOT | Configurable norms and negation; min/product/bounded AND, max/probabilistic/bounded OR; Very/Somewhat modifiers | Additional hedges |
| Implication / aggregation | Configurable; min/product/bounded implication and max/probabilistic/bounded aggregation | Per-rule-block/per-output strategies |
| Defuzzification | Centroid, Bisector, three maxima methods and custom Defuzzifier | Per-output defuzzification |
| Membership | Eleven functions including Ramp, Sigmoid, Bell, S/Z/Pi, Rectangle and DiscreteSet | Additional specialized shapes |
| Rule base | One named consequent per weighted rule | Rule blocks, multiple consequents, activation policies |
| Configuration | Dart objects with validation | Versioned JSON schema, portable import/export, parser |
| Explanations | Input memberships, rule activations, immutable aggregated curves | Coverage/dead-rule diagnostics |
| Tooling | Three single-input demos, tests, bilingual guides | Multi-input surfaces, benchmarks, reference datasets |

## Proposed sequence

1. **Extensible inference pipeline — implemented, awaiting remote CI.** Public
   operators, implication, aggregation and defuzzification interfaces preserve
   defaults. Independent numerical tests cover the selectable strategies.
2. **Broader type-1 Mamdani toolbox — implemented, awaiting remote CI.** Common
   membership shapes, Very/Somewhat modifiers, bisector and maxima defuzzifiers are
   included. Endpoint, plateau, tolerance and zero-area contracts are documented.
3. **Sugeno — implemented, awaiting remote CI.** Constant/linear consequents,
   normalized weighted average, explicit weighted sum and immutable explanations.
   Analytical, zero-strength and extreme-arithmetic tests are included.
4. **Model portability and diagnostics.** Versioned JSON with round-trip tests;
   diagnostics for coverage, inactive/contradictory rules, output curves and units.
   Do not evaluate arbitrary Dart expressions from configuration files.
5. **Advanced controllers and integrations.** Larsen and monotonic Tsukamoto with
   inverse membership validation; FCL/FIS interoperability only after specifying
   a supported subset and conformance fixtures.

## Definition of done for each feature

Public API, English and Portuguese explanations, at least one executable example,
independent numerical references, edge-case tests and benchmark impact. Changes
to numerical defaults must be documented; existing models should keep their
behavior unless a deliberate breaking change is released.

Interval type-2, fuzzy relations/composition, fuzzy arithmetic and neuro-fuzzy
learning are separate future areas. They need dedicated models and requirements;
adding them all is not a prerequisite for a useful type-1 control engine.

Reference for the breadth of established controller toolboxes:
[FuzzyLite features](https://fuzzylite.com/) and
[technical paper](https://fuzzylite.com/downloads/FuzzyLite-Libraries.pdf).
This is a conceptual comparison; it does not claim compatibility or reuse code.
