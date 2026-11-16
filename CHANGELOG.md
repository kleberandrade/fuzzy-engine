## 0.1.0

First release candidate; publication status is tracked in doc/PUBLISHING.md.

- Add dependency-free, explainable type-1 Mamdani/Larsen, Sugeno and Tsukamoto engines.
- Include eleven membership functions, configurable norms/negation, five
  defuzzifiers, Very/Somewhat modifiers and validated monotonic inverses.
- Support constant/linear Sugeno consequents and distinct weighted average/sum.
- Preserve immutable membership, activation and output explanations, with explicit
  null decisions and eager model/input validation.
- Add strict JSON v1/v2 interchange, metadata, unit labels and bounded diagnostics.
- Import/export a restricted single-output Mamdani/Sugeno FIS profile; reject
  unrepresentable rules, methods and custom functions without approximation.
- Require explicit no-decision policy on import and acknowledgement of runtime
  settings absent from FIS on export. Preserve unused Sugeno consequent terms.
- Validate 126 original/exported numerical comparisons with scikit-fuzzy/NumPy;
  retain 63 external reference cases as standalone Dart regression tests.
- Add Flutter climate, irrigation and game examples, plus a two-input ventilation
  controller with a cached 21 × 21 decision surface and visible rule activations.
- Provide English/Portuguese guides, class diagrams, console examples, benchmarks,
  JSON schemas, five pub.dev topics and a release validation script.
- Include 281 core tests and CI for minimum/stable Dart, Flutter and live external
  comparison. Use the standard doc/ directory to avoid Pub layout warnings.
- Keep FCL, multi-output FIS, type-2 and full vendor conformance outside this release.
