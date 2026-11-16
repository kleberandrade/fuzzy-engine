# Scope and roadmap

[Português](roadmap.pt-BR.md) · [Implemented architecture](architecture.en.md)

## Progress

The extensible pipeline stage is implemented locally with 32 passing tests, public
strategy contracts and a runnable example. New remote CI validation is pending.
Additional built-in norms and aggregated output curves are also available.

## Current scope

Version 0.1.0 is an initial type-1 Mamdani engine. It is not a complete fuzzy logic
framework. Multi-input/output inference exists, but the Flutter scenarios each
use one input. The following roadmap is a proposal, not implemented functionality
or a release-date commitment.

| Area | Implemented | Missing / proposed |
| --- | --- | --- |
| Inference | Mamdani defaults, configurable product implication | Sugeno zero/first order, Tsukamoto |
| AND / OR / NOT | Configurable norms and negation; min/product/bounded AND, max/probabilistic/bounded OR | Hedges |
| Implication / aggregation | Configurable; min/product/bounded implication and max/probabilistic/bounded aggregation | Per-rule-block/per-output strategies |
| Defuzzification | Centroid and custom Defuzzifier interface | Built-in bisector, smallest/largest/mean of maxima |
| Membership | Triangle, trapezoid, Gaussian, custom interface | Ramp, sigmoid, bell, S/Z/Pi shapes, discrete sets |
| Rule base | One named consequent per weighted rule | Rule blocks, multiple consequents, activation policies |
| Configuration | Dart objects with validation | Versioned JSON schema, portable import/export, parser |
| Explanations | Input memberships, rule activations, immutable aggregated curves | Coverage/dead-rule diagnostics |
| Tooling | Three single-input demos, tests, bilingual guides | Multi-input surfaces, benchmarks, reference datasets |

## Proposed sequence

1. **Extensible inference pipeline — implemented, awaiting remote CI.** Public
   operators, implication, aggregation and defuzzification interfaces preserve
   defaults. Independent numerical tests cover the selectable strategies.
2. **Broader type-1 Mamdani toolbox.** Add product/probabilistic/bounded operators,
   common membership shapes, linguistic hedges and additional integral defuzzifiers.
   Define endpoint, plateau, tolerance and zero-area behavior for every algorithm.
3. **Sugeno.** Use constant and linear consequents with normalized weighted average;
   keep weighted sum distinct. Test analytical results and zero-total-weight behavior.
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
