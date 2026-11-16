# Validation / Validação

Development validation on 2026-11-16 with Dart 3.11.5 and the installed Flutter SDK.

| Check | Result |
| --- | --- |
| Dart formatting | Passed |
| Core static analysis | Passed, no issues |
| Core tests | 122 passed, including interchange, reference fixtures, diagnostics and numerical compatibility |
| Flutter example static analysis | Passed, no issues |
| Flutter web build | Passed (JS build and Wasm compatibility dry run) |
| API documentation | Generated, zero warnings and errors |
| Flutter widget test | Included; execution blocked by local socket permissions |
| Publication dry run | Blocked by pub.dev network access during dependency resolution |
| Actual publication | Not performed |

The web build emitted a missing optional Cupertino icon font warning; the demo
uses Material icons and its declared Material font was bundled successfully.
No manual browser visual inspection was performed. Minimum supported Dart 3.3.0
has not been tested locally. Re-run CI and the release checklist before publishing.

Os 122 testes do núcleo passaram. A análise estática passou no núcleo e no exemplo,
e a compilação web terminou com sucesso. A documentação foi gerada sem avisos.
O teste de interface está incluído, mas sua execução foi bloqueada pela permissão
de abertura de porta local. A simulação de publicação foi bloqueada pelo acesso
ao pub.dev. Não houve publicação nem inspeção visual manual em navegador.
A versão mínima Dart 3.3.0 ainda precisa de validação específica.

## CI review after the initial push

The initial [GitHub Actions run](https://github.com/kleberandrade/fuzzy-engine/actions/runs/43810381837)
failed before testing: Dart pub attempted to resolve the Flutter example without a
Flutter SDK; Flutter analysis reported the deprecated Material re-export import.

Corrections prepared:
- Use `dart pub get --no-example` for the standalone Dart core.
- Test both Dart 3.3.4 and stable; formatting and docs run on stable.
- Preserve older Flutter compatibility with a targeted suppression on the Material
  import only. All other analyzer diagnostics remain fatal.
- Run publication validation in the Flutter job, which can resolve the example.
- Use the included web runner directly rather than regenerating it during CI.

These CI changes need a new successful remote run. The local Flutter SDK is
3.41.9; latest Flutter and minimum Dart validation are delegated to CI and must
not be reported as passed until that run completes.

The public package URL https://pub.dev/packages/fuzzy_engine returned 404 during
review. No published package was found at that exact URL; this does not reserve
the name or guarantee that the publication service will accept it.

## Configurable pipeline stage

All 20 pre-existing tests and 12 new strategy tests pass locally. Numeric checks
cover weighted min clipping, product implication, probabilistic aggregation,
nested custom antecedent operators and custom defuzzification. Output curves and
extension results are validated. Flutter analysis and the web build passed with
the new pipeline; API docs generated with no warnings. A reproducible benchmark compares the previous
commit with the new default pipeline; see performance.md. Remote CI, minimum SDK
and latest Flutter validation remain pending for this change.

## Mamdani toolbox stage

68 local tests pass, including 36 new checks for membership boundaries, numerical
stability, invalid parameters, grid bounds, ordered interpolation, hedges, maxima
tolerance/disconnected peaks, zero area and exact piecewise-linear bisector
references. The two-input irrigation example executes all five defuzzifiers. Static analysis
passed for the core and Flutter example; the web build succeeded and API docs
generated without warnings.
Remote CI, minimum Dart and latest Flutter checks remain pending for this stage.

## Sugeno stage

All 68 previous tests plus 24 Sugeno tests pass locally. Checks cover constant and
linear equations, weighted average versus sum, rule weights, custom consequents,
multiple outputs, inactive rules, immutable explanations, input/reference errors,
tiny common strengths, compensated cancellation and genuine arithmetic overflow.
Mamdani and Sugeno now share internal input validation/fuzzification; all existing
Mamdani tests remain unchanged and passing. The example and benchmark execute.
Static analysis passed for the core and Flutter example; the web build succeeded.
API documentation generated without warnings.
Remote CI, minimum Dart and latest Flutter checks are pending for this stage.

## Model portability and diagnostics stage

30 new local tests cover Mamdani/Sugeno round-trips, every membership/norm/defuzzifier,
condition trees, metadata, malformed input, resource bounds, custom callbacks,
independent v1 fixtures, deterministic grids, conservative structural findings and
failure accounting. All 92 previous tests remain passing (122 total). Schema syntax
and local references are checked; an external JSON Schema validator is not installed
and was not run. Decoder validation and independent fixture arithmetic are tested.
The runnable model-tools example and benchmark execute. Static analysis passes
for the core and Flutter example; the web build succeeds and API docs generate
without warnings. Remote/minimum-SDK checks
remain pending for these changes.
