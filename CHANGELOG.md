## Unreleased

- Add a responsive branded navbar and integrated bilingual Learn/Examples areas
  grounded in the implemented 0.3.0 guides, formulas, six runnable presets and five
  practical exercises; keep the current experiment and editor draft alive across sections.
- Add original vector branding, an SVG favicon and circular Brazil/United Kingdom
  language buttons with selected states, keyboard focus and 48 px touch targets.
- Translate navigation, forms, strategies, feedback and educational content in
  English/PT-BR; persist language/theme in browser storage without saving model data.
- Adiciona navbar responsiva, marca vetorial original, bandeiras circulares e área
  Aprender/Exemplos bilíngue com fórmulas e presets reais. A troca de idioma mantém
  o experimento e rascunhos; idioma/tema ficam salvos no navegador quando permitido.

- Add a transactional visual editor for membership shapes, ranges, terms, rule
  conditions/weights and Mamdani, Sugeno or Tsukamoto consequents, with live
  validated previews and application/cancellation from every lab scenario.
- Default the Flutter lab to a dark navy/teal theme with a light-theme toggle;
  keep the editor scrollable above mobile keyboards and preserve edited ranges.
- Adiciona editor visual de curvas e regras com prévia validada, aplicação e
  cancelamento; o laboratório inicia no tema escuro e permite alternar para claro.

- Complete the Flutter lab with Mamdani/Sugeno/Tsukamoto comparison, five Mamdani
  defuzzifiers, membership/output curves, rule explanations, reset and validated
  JSON import/export; preserve the original scenarios and climate surface.
- Validate the lab on narrow screens, document scenarios and limits, and deploy
  its static Web build through GitHub Pages only after all CI checks succeed.
- Completa o laboratório Flutter com comparação de três inferências, cinco
  defuzzificadores Mamdani, curvas, regras, reinício e JSON validado; preserva
  os cenários existentes. Publicação Web condicionada à aprovação de toda a CI.

## 0.3.0

### English

- Support multi-output Mamdani/Sugeno FIS import/export, zero consequent indices, independent fallback and immutable output maps; retain single-output conveniences.
- Retain per-output Sugeno ranges and named catalogs, including unused terms; bound expanded rules and output count.
- Add multi-output parser, numerical, round-trip and metadata validation tests plus 108 new independent original/exported comparisons (234 total).
- Extend the bilingual Flutter climate demo with fan/heater decisions, selectable heatmaps and an explicit FIS round-trip.
- Update bilingual guides, class diagrams, scope and fixture provenance.

### Português

- Adiciona FIS Mamdani/Sugeno com múltiplas saídas, consequentes ignorados e fallback independente, preservando os atalhos de saída única.
- Conserva intervalos e catálogos Sugeno por saída e limita a expansão de regras.
- Amplia testes e comparações externas para 234; o exemplo Flutter mostra ventilação/aquecimento, gráficos selecionáveis e intercâmbio FIS.
- Atualiza guias, diagramas de classes e limitações em português e inglês.

## 0.2.0

### Português

- Adiciona importação e exportação experimental de um perfil FCL restrito, com validação explícita e guias nos dois idiomas.
- Compara 72 casos FCL originais/exportados com jFuzzyLogic, documentando diferenças de amostragem e DEFAULT.
- Ativa os lints oficiais, corrige os avisos de análise estática e exige pontuação máxima do pana no CI.
- Corrige os testes Flutter em duas alturas de tela e mantém o checkout limpo durante a validação da publicação.
- Prepara publicação automática por tags, com verificações completas e credenciais OIDC temporárias.
- Usa o publisher verificado `kleberandrade.dev`.

### English

- Fix Flutter widget tests to reveal lazy list results and cover two viewport heights.
- Keep Flutter analyzer exclusions checked in so SDK migrations do not dirty release validation.
- Publish under the verified `kleberandrade.dev` publisher.

- Add bounded FCL export, explicit runtime-setting acknowledgement and rejection of unrepresentable models.
- Validate 72 original/exported FCL cases against pinned jFuzzyLogic; record native and quadrature-mapped outputs, including sampling-induced DEFAULT differences.
- Add 21 exporter tests, 36 external reference tests and a live Java comparison CI job.

- Enable official core lints, fix all findings and gate full Pub points with pana in CI.
- Add restricted experimental FCL import, explicit ranges/defaults, 32 tests and bilingual guides.

- Add tag-triggered OIDC publishing gated by the full CI and version checks.
- Add tested release bump tooling and persistent contributor versioning rules.

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
