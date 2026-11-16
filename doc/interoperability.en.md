# FIS/FCL interoperability: proposed profiles

[Português](interoperability.pt-BR.md)

**Status: restricted Mamdani/Sugeno FIS import/export and independent numerical
comparisons are implemented.** See the [accepted profile](fis.en.md). FCL, vendor
exported fixtures and full standard conformance remain pending.
The runtime and JSON codec support Mamdani, Sugeno and Tsukamoto. That does not
imply file-format compatibility with MATLAB, IEC 61131-7 or other toolkits.

## Proposed first FIS profile

| Area | Initial target | Reject until explicitly supported |
| --- | --- | --- |
| Families | Type-1 Mamdani; then constant/linear Sugeno | Type-2, hybrid, Tsukamoto format extensions |
| Variables | Named finite input universes and one output | Implicit/unbounded universes and multi-output rule vectors |
| Membership | trimf, trapmf, gaussmf | Arbitrary function names and unsupported parameter conventions |
| Antecedents | Flat AND or OR, explicit complement, optional ignored input indices | Mixed nested connectives not representable in the chosen file profile |
| Rules | One nonempty antecedent, one consequent; explicit weights/conventions | All-inputs-ignored rules until a true-condition representation is designed |
| Decision | Explicit min/product conjunction, max/probabilistic disjunction, min/product implication, max aggregation, centroid or normalized Sugeno average | Any unsupported method, fallback or stateful behavior |

This table describes the broader target; implemented support is listed separately
in the import guide. A parser must map parameters by
meaning, not constructor position: for example, Gaussian width/center conventions
must be checked against an authoritative format definition. Linear output
coefficients must be associated with declared input order, with an explicitly
verified intercept convention. Unknown sections, fields, functions or methods must
fail with source locations, never silently fall back to defaults.

## Proposed first FCL profile

One FUNCTION_BLOCK, REAL variables, explicit finite universes, one RULEBLOCK,
piecewise linear terms representable as DiscreteSet, min conjunction/implication,
max aggregation and center-of-gravity output. Broader function/operator grammars
come only after the first profile is independently verified.

DEFAULT and previous-value/stateful policies must be represented explicitly.
The core returns null when no rule decides an output; that must not be silently
substituted for a numeric DEFAULT or retained previous value. The jFuzzyLogic
reference example uses DEFAULT := 0; this would require an explicit adapter policy,
not an unnoticed change to core engine defaults.

## Acceptance gate for implementation

1. Write bounded lexer/parser rules for the chosen dialect; never eval file text.
2. Collect independently sourced/exported fixtures with provenance and licenses.
3. Compare crisp outputs, memberships and activation traces at endpoints,
   overlapping sets and points where no rule fires.
4. Specify sample coordinates and integration conventions. Equal method names
   do not establish equal discretization; numerical tolerances need justification.
5. Preserve supported fields on export/import; reject unsupported data rather
   than approximate it or discard it. Round-trip tests alone are insufficient.
6. Keep JSON v1/v2 fixtures passing and document each accepted external dialect.

The importer/exporter has bounded parsing, analytical fixtures and 126 numerical
comparisons using scikit-fuzzy/NumPy. Vendor-exported fixtures and direct MATLAB
validation remain pending, so stronger vendor-conformance claims are not made. Use the documented JSON schemas for
portable package models. No vendor certification or full conformance is claimed.

Primary references:
- [MathWorks readfis](https://in.mathworks.com/help/fuzzy/readfis.html)
- [MathWorks Sugeno model documentation](https://www.mathworks.com/help/fuzzy/sugfis.html)
- [jFuzzyLogic FCL documentation](https://jfuzzylogic.sourceforge.net/html/fcl.html)
- [FuzzyLite technical paper](https://fuzzylite.com/downloads/FuzzyLite-Libraries.pdf)
