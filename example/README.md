# Flutter Fuzzy Lab / Laboratório Fuzzy

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

With Flutter stable installed / Com Flutter stable instalado:

```sh
cd example
flutter create --platforms=web .
flutter pub get
flutter run -d chrome
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
weighted sum. Console example; the Flutter lab remains Mamdani. Compara conclusões
constantes/lineares, média normalizada e soma ponderada; exemplo de console.

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
This is a Dart console example; the Flutter lab UI still uses Mamdani.
