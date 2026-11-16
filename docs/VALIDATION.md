# Validation / Validação

Development validation on 2026-11-16 with Dart 3.11.5 and the installed Flutter SDK.

| Check | Result |
| --- | --- |
| Dart formatting | Passed |
| Core static analysis | Passed, no issues |
| Core tests | 13 passed, including analytic centroid references |
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

Os 13 testes do núcleo passaram. A análise estática passou no núcleo e no exemplo,
e a compilação web terminou com sucesso. A documentação foi gerada sem avisos.
O teste de interface está incluído, mas sua execução foi bloqueada pela permissão
de abertura de porta local. A simulação de publicação foi bloqueada pelo acesso
ao pub.dev. Não houve publicação nem inspeção visual manual em navegador.
A versão mínima Dart 3.3.0 ainda precisa de validação específica.
