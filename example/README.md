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
