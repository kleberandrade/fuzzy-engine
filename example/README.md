# Flutter Fuzzy Lab / Laboratório Fuzzy

**[Open online / Abrir online](https://kleberandrade.github.io/fuzzy-engine/)**

[Scenario guide and limitations](../doc/lab-guide.md) ·
[Validation and real captures](../doc/lab-validation.md)

The existing scenarios and climate surface are joined by an inference workbench:
compare Mamdani, Sugeno and Tsukamoto, choose five Mamdani defuzzifiers, inspect
membership/output curves and active rules, and import/export validated model JSON.
The visual editor configures curves, ranges, terms and IF–THEN rules without
manual JSON edits, including constant/linear Sugeno consequents. Dark mode is the
default; the home theme button switches to light mode. The scenario guide explains
Apply, Cancel and which advanced settings remain JSON-only.
No Flutter dependency is added to the Dart core.

A bancada compara as três inferências, mostra curvas e regras e permite trocar
configurações JSON validadas. Os cenários e a superfície anteriores são preservados. O editor visual permite
alterar curvas e regras sem JSON; o tema escuro pode ser alternado para claro.

Three independent educational models: climate → fan speed, soil moisture →
watering intensity, player performance → game difficulty. Sliders change crisp
inputs; curves show membership; bars show weighted rule activations. The language
button switches the interface between English and Portuguese. Technical variable
and term identifiers stay in English.

Três modelos didáticos independentes: temperatura → ventilação, umidade do solo →
intensidade da irrigação e desempenho → dificuldade do jogo. Os controles alteram
entradas, curvas mostram pertinência e barras mostram ativação das regras.
O botão de idioma alterna português e inglês; identificadores técnicos ficam em inglês.

## Run / Executar

Validated with Flutter 3.50.0 / Dart 3.14.0; the core retains Dart >=3.3.
Validado com Flutter 3.50.0 / Dart 3.14.0; o núcleo mantém Dart >=3.3.

With Flutter installed / Com Flutter instalado:

```sh
cd example
flutter pub get
flutter run -d chrome
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub --no-web-resources-cdn --base-href /fuzzy-engine/
```

A web runner is included. Generate additional platform runners locally as needed.
For Android/iOS/macOS, include the desired platform in `flutter create`.
Um projeto web está incluído. Outras plataformas podem ser geradas localmente. Para Android/iOS/macOS,
inclua a plataforma desejada no comando `flutter create`.

Core-only examples / Exemplos sem Flutter, a partir da raiz:

```sh
dart run example/quick_start.dart
dart run example/fuzzy_engine_example.dart
```

These are illustrative thresholds, not calibrated controllers. The soil model
inverts low/high consequents: dry soil increases irrigation. Outputs are percentages
of an abstract intensity, not minutes, hardware commands or probability.
São limites ilustrativos. No modelo do solo, menor umidade aumenta a irrigação.
As saídas são percentuais de intensidade abstrata, não minutos nem comandos físicos.

## Toolbox / Funções e métodos

Run from the package root / Execute a partir da raiz:

```sh
dart run example/toolbox_example.dart
```

Two-input educational irrigation with smooth membership curves, a Somewhat hedge
and five defuzzification methods. This is a Dart console example, separate from
the Flutter lab UI. Modelo didático com duas entradas, curvas suaves, modificador
Somewhat e cinco métodos de defuzzificação; exemplo de console Dart.

## Sugeno

From the package root / A partir da raiz:

```sh
dart run example/sugeno_example.dart
```

Compares constant/linear consequents and normalized weighted average versus raw
weighted sum. The workbench also compares a constant Sugeno preset; JSON imports retain
constant/linear consequents and reduction settings. Compara conclusões
constantes/lineares, média normalizada e soma ponderada; a bancada inclui Sugeno.

## Model JSON and diagnostics / JSON e diagnósticos

```sh
dart run example/model_tools_example.dart
```

From the package root. Demonstrates model/metadata round-trip and deliberately
imperfect rules. Exemplo de console, a partir da raiz, com intercâmbio do modelo,
unidades e regras deliberadamente duplicadas/concorrentes para explicar os achados.

## Tsukamoto

```sh
dart run example/tsukamoto_example.dart
```

Shows weighted inverse values, JSON v2 round-trip and sampling diagnostics.
Exibe valores inversos ponderados, ida e volta JSON v2 e diagnósticos amostrados.
The workbench also includes a monotonic-ramp Tsukamoto preset and JSON v2 import.
A bancada também inclui Tsukamoto com rampas monotônicas e importação JSON v2.

## Two-input decision surface / Superfície com duas entradas

Choose **Explore two inputs and outputs** (PT: **Explorar duas entradas e saídas**) to open climate control.
Independent temperature (0–40 °C) and humidity (0–100%) sliders drive eighteen Mamdani
rules for fan/heater demand. The heatmap is a top view of a 21 × 21 sampled decision surface; blue means
low demand and red high demand. The marker follows the exact slider inputs, not a
rounded heatmap cell. The numeric output and activation bars provide a non-color
explanation. Grid computation is cached; sliders only re-evaluate the current point.

Escolha **Explorar duas entradas e saídas** para controlar temperatura e umidade. A malha
mostra 441 decisões; o marcador e o resultado numérico usam as entradas exatas.
As dezoito regras cobrem o universo didático. Os limites e as regras precisam de
calibração antes de qualquer uso com equipamentos reais.

## Multi-output climate / Climatização com múltiplas saídas

Open **Explore two inputs and outputs**. Temperature and humidity drive independent
fan and heater demand percentages through 18 rules. `climateFisModel()` exports
and reimports the Mamdani configuration, explicitly restoring the 200-interval
resolution and preserve-null policy. Both decisions update immediately; select
Fan or Heating to inspect its cached 21 × 21 surface and scroll to see rule
activations labeled by output. This is an educational model requiring calibration.

Abra **Explorar duas entradas e saídas**. Temperatura e umidade determinam demandas
de ventilação e aquecimento em porcentagem, por 18 regras. `climateFisModel()` faz
a exportação/importação FIS e restaura resolução e política sem decisão. As duas
saídas se atualizam juntas; selecione a saída para trocar o gráfico e role a tela
para ver as regras ativadas por saída. O modelo é didático e precisa de calibração.
