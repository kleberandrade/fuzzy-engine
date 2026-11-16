# Validation / Validação

Publication update: version 0.1.0 is public, confirmed on 2026-11-16. The blocked
local publication attempts described below are historical. Tag-based OIDC
automation is now prepared; its one-time Pub authorization is still required.

Evidence collected on 2026-11-16 with Dart 3.11.5 and Flutter 3.41.9.

| Check | Current local result |
| --- | --- |
| Core tests | 281 passed |
| Core static analysis | Passed, no issues |
| Flutter example static analysis | Passed, no issues |
| Flutter web build | Passed, including Wasm compatibility dry run |
| API documentation | Generated with zero warnings/errors |
| External numerical comparison | 126 passed with scikit-fuzzy 0.5.0 and NumPy 2.2.6 |
| Recorded external references | 63 cases, replayed by Dart tests |
| Flutter widget tests | Execution blocked by local server-socket permission |
| Publication dry run | Packaging reached validation; terminal cannot connect to pub.dev |
| Actual publication | 0.1.0 published by the maintainer; confirmed through the public Pub API |

The two-input example's 441-point grid and independent slider effects are tested
as pure Dart models. Navigation/slider widget tests are included for CI. No manual
browser inspection of this new surface has been completed. The web build emitted
a missing optional Cupertino icon-font warning; the example uses Material icons
and the Material font was bundled successfully. A temporary SDK copy suppressed
analytics in compiler subprocesses to avoid writes outside the writable workspace;
no user SDK or application inference behavior was changed.

## Independent numerical evidence

The original Mamdani and Sugeno FIS fixtures were authored for this project under
MIT. They were not exported by MATLAB. A separate Python parser/evaluator uses
unmodified scikit-fuzzy membership and centroid functions and NumPy Sugeno arithmetic.
Official wheels were downloaded from PyPI, checked against registry SHA-256 values
and installed into a temporary directory. There is no Python runtime dependency
in the Dart package. Exact test versions are pinned in tool/external-requirements.txt.

126 comparisons cover original and exported files, 63 model/input combinations,
endpoints, overlap, no activation, Gaussian parameters, product/probor methods,
constant/linear consequents and weighted average/sum. Degrees, activations and
Mamdani sampled curves agree within absolute 1e-12. Maximum observed crisp
difference: 3.3333333480101146e-6. It satisfies the derived moment-quadrature bound
in [the FIS guide](fis.en.md), rather than an arbitrary loose tolerance.

Recorded references include sources, hashes, memberships, strengths and outputs.
The live comparison is configured in CI; a local pass is not a remote CI result.
No MATLAB parser certification or full external standard conformance is claimed.

## Remote CI and release gates

The last inspected [run for ce2f56e](https://github.com/kleberandrade/fuzzy-engine/actions/runs/43878356602)
passed Dart 3.3.4, stable Dart, and Flutter analysis/tests/build. Its Flutter job
failed at the final publication dry-run with exit 65. Full logs require GitHub
authentication; the API exposed only that exit code. This is evidence for the
previous commit, not the changes now prepared.

One concrete Pub validator warning was identified: the former docs/ directory
violates the singular doc/ package-layout convention. Guides were moved to doc/
and local links updated. The changelog was consolidated under version 0.1.0;
Python release tools are excluded from the package archive. These changes require
a fresh successful CI/dry-run before release. Do not bypass warnings or validation.

Reproduction:

```sh
bash tool/check_release.sh
python -m pip install -r tool/external-requirements.txt
dart run tool/export_external_cases.dart > /tmp/fis-cases.json
python tool/compare_external.py /tmp/fis-cases.json
```

## Resumo em português

281 testes Dart e 126 comparações numéricas externas passaram. A análise estática,
a documentação da API e a compilação web passaram. Os 63 casos externos também
são testes de regressão Dart. O teste Flutter de interface está incluído, mas este
ambiente bloqueia a porta local necessária para executá-lo. Não houve inspeção
visual manual da nova superfície.

O CI do commit anterior passou nos SDKs Dart mínimo/estável e nas etapas Flutter,
mas falhou no dry-run de publicação. A convenção da pasta doc/ foi corrigida;
não se afirma que o CI novo passou antes de executá-lo. A rede do terminal e a
autenticação Pub impedem concluir a publicação neste ambiente. A página pública
retornou 404 na consulta via API; isso não garante reserva/disponibilidade do nome.

## Core lints and initial FCL profile

Official lints/core.yaml is enabled explicitly, with a development-only constraint
compatible with minimum/stable SDK resolution. Missing control-flow blocks were
fixed; the example model tests were moved to their own package to remove a
relative lib import. No scoring diagnostic was suppressed. Pure Dart inference
behavior remains covered by the numerical regression suite.

Initial FCL import adds 32 tests including analytical references, nine equivalent
recorded scikit-fuzzy cases, DEFAULT behavior, saturated tails and parser budgets.
Direct external FCL-runtime validation and FCL export remain pending. The original
FCL fixture is MIT project data. New guides explain the exact accepted grammar.

See [Pub quality evidence and CI gate](pub-quality.md). The published package score
is still 150/160 until a new version is analyzed. Local pana confirmed static
analysis 50/50; its total was incomplete because SDK dartdoc rejected a tool flag.
The CI uses the compatible standalone dartdoc path, not a scoring suppression.

Final checks for this stage: 315 Dart/tool tests passed (including 32 FCL tests),
126 existing live numerical comparisons passed, strict core analysis and Flutter
example analysis passed, API documentation had zero warnings/errors, and the web
build succeeded. Two existing ventilation model tests now live in the Flutter
example package instead of importing its lib relatively from the core tests.
Flutter test execution remains subject to the previously documented local socket
restriction; no new remote CI success or published score is claimed.
