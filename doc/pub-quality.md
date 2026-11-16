# Pub quality / Qualidade no pub.dev

The published score reviewed on 2026-11-16 was 150/160. Static analysis had 40/50;
file conventions (30/30), documentation (20/20) and platform support (20/20) already
passed in the supplied report. Registry tags also confirmed native/JIT/AOT, web,
Wasm readiness, all six platforms, Dart and Flutter. Popularity/likes are separate.

The local analyzer previously did not enable lints/core.yaml. The published report
found 78 issues; the stricter local analysis found 87 across package/tests/tools.
86 missing-block findings were corrected and one relative lib import was removed
by moving the example model tests into the example package. These edits preserve rules
and numerical behavior; no diagnostic was suppressed to obtain a score.

| Category | Prevention / evidence |
| --- | --- |
| File conventions | doc/ layout, MIT license, repository/issue URLs, versioned changelog |
| Documentation | Bilingual guides, illustrative examples, public API comments, dart doc |
| Platforms / Wasm | Pure Dart exports, no runtime platform imports; Flutter web build |
| Static analysis | lints/core.yaml; fatal infos; format verification; unit tests |
| Current SDK/dependencies | Minimum/stable Dart, stable Flutter, live pana dependency checks |
| Complete score | CI pana 0.23.19 on an isolated copy, exit-code-threshold=0 |

The full reusable CI now runs pana before publication; any missing points fail the
job. The JSON-lines report is retained as the pub-score-report workflow artifact.
The pinned pana version should be reviewed when pub.dev changes its scoring tool.
A local clean analysis is not proof of a published 160/160 score. That can only be
confirmed after the registry analyzes the new version. Network-dependent local
checks may remain incomplete in the restricted terminal.

A pontuação publicada era 150/160. Habilitamos as regras oficiais, corrigimos os
avisos e adicionamos uma verificação pana no CI para todas as categorias, com
relatório salvo como artefato. Não há promessa de 160/160 antes da execução desse
CI e da análise da nova versão no pub.dev. Curtidas e downloads não são qualidade
técnica e não fazem parte dessa verificação.

Official reference: https://pub.dev/help/scoring

## Local pana evidence

A local pana 0.23.19 run on an isolated copy confirmed convention 30/30, platform
20/20, static analysis 50/50 and dependencies 40/40. Documentation was 10/20
because `--dartdoc-version sdk` called a Dart SDK command that did not accept
pana's `--sanitize-html` option, not because missing comments were reported.
The CI command uses pana's default compatible standalone dartdoc installation
instead. The incomplete local total is not presented as a full-score pass.
The standalone SDK documentation generation is checked separately.
