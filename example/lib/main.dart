// Retain compatibility with Flutter SDKs predating the Material UI extraction.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_settings.dart';
import 'lab_shell.dart';
import 'scenarios.dart';
import 'surface_page.dart';
import 'workbench_page.dart';
import 'membership_plot.dart';
import 'lab_model.dart';
import 'visual_editor_page.dart';
import 'package:fuzzy_engine/fuzzy_engine.dart';

void main() => runApp(const FuzzyApp());

class FuzzyApp extends StatefulWidget {
  const FuzzyApp({super.key, this.preferences, this.onOpenLink});
  final PreferenceStore? preferences;
  final ValueChanged<String>? onOpenLink;
  @override
  State<FuzzyApp> createState() => _FuzzyAppState();
}

class _FuzzyAppState extends State<FuzzyApp> {
  late final settings =
      AppSettings(widget.preferences ?? const BrowserPreferences());
  final navigatorKey = GlobalKey<NavigatorState>();
  @override
  void dispose() {
    settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: settings,
      builder: (_, __) => MaterialApp(
            title: settings.portuguese
                ? 'Fuzzy Engine · Laboratório'
                : 'Fuzzy Engine · Laboratory',
            debugShowCheckedModeBanner: false,
            locale: settings.portuguese
                ? const Locale('pt', 'BR')
                : const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('pt', 'BR')],
            // Retain compatibility with Flutter before Material extraction.
            // ignore: deprecated_member_use
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            themeMode: settings.dark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
                colorSchemeSeed: const Color(0xff147d77), useMaterial3: true),
            darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xff0b1220),
                colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xff65d7d0),
                    brightness: Brightness.dark,
                    surface: const Color(0xff121d31))),
            builder: (context, child) =>
                AppScope(settings: settings, child: child!),
            home: LabShell(
                settings: settings,
                navigatorKey: navigatorKey,
                onOpenLink: widget.onOpenLink,
                child: Navigator(
                    key: navigatorKey,
                    onGenerateRoute: (_) =>
                        MaterialPageRoute<void>(builder: (_) => const Lab()))),
          ));
}

class Lab extends StatefulWidget {
  const Lab({super.key});
  @override
  State<Lab> createState() => _LabState();
}

class _LabState extends State<Lab> {
  int selected = 0;
  double value = 25;
  bool get portuguese => AppScope.pt(context, fallback: true);
  final models = [
    controller('temperature', 'fanSpeed', 0, 50),
    controller('soilMoisture', 'watering', 0, 100),
    controller('performance', 'difficulty', 0, 100)
  ];
  @override
  Widget build(BuildContext context) {
    final engine = models[selected];
    final input = engine.inputs.single;
    final result = engine.evaluate({input.name: value});
    final labels = portuguese
        ? ['Climatização', 'Irrigação', 'Jogo']
        : ['Climate', 'Irrigation', 'Game'];
    return Scaffold(
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  Text(
                      portuguese
                          ? 'Decisões graduais, regras visíveis.'
                          : 'Gradual decisions. Visible rules.',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    key: const ValueKey('open-surface'),
                    icon: const Icon(Icons.grid_on),
                    label: Text(portuguese
                        ? 'Explorar duas entradas e saídas'
                        : 'Explore two inputs and outputs'),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                SurfacePage(portuguese: portuguese))),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('open-workbench'),
                    icon: const Icon(Icons.science_outlined),
                    label: Text(portuguese
                        ? 'Comparar e editar modelos'
                        : 'Compare and edit models'),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                WorkbenchPage(portuguese: portuguese))),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                      spacing: 12,
                      children: List.generate(
                          3,
                          (i) => ChoiceChip(
                              label: Text(labels[i]),
                              selected: selected == i,
                              onSelected: (_) => setState(() {
                                    selected = i;
                                    final next = models[i].inputs.single;
                                    value =
                                        next.min + (next.max - next.min) / 2;
                                  })))),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                      key: const ValueKey('edit-scenario'),
                      icon: const Icon(Icons.tune),
                      label: Text(portuguese
                          ? 'Editar curvas e regras deste cenário'
                          : 'Edit scenario curves and rules'),
                      onPressed: () async {
                        final edited = await Navigator.of(context)
                            .push<LabModel>(MaterialPageRoute(
                                builder: (_) => VisualEditorPage(
                                    model: LabModel(
                                        FuzzyModelDocument(engine: engine)),
                                    portuguese: portuguese)));
                        if (!mounted || edited == null) return;
                        setState(() {
                          models[selected] =
                              edited.document.engine as FuzzyEngine;
                          final updated = models[selected].inputs.single;
                          value = value.clamp(updated.min, updated.max);
                        });
                      }),
                  TextButton.icon(
                      key: const ValueKey('inspect-scenario'),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(portuguese
                          ? 'Inspecionar/exportar este cenário'
                          : 'Inspect/export this scenario'),
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => WorkbenchPage(
                                  portuguese: portuguese,
                                  initialModel: LabModel(
                                      FuzzyModelDocument(engine: engine)))))),
                  const SizedBox(height: 24),
                  Text('${input.name}: ${value.toStringAsFixed(1)}'),
                  Slider(
                      value: value,
                      min: input.min,
                      max: input.max,
                      label: value.toStringAsFixed(1),
                      semanticFormatterCallback: (v) =>
                          '${input.name} ${v.toStringAsFixed(1)}',
                      onChanged: (v) => setState(() => value = v)),
                  SizedBox(
                      height: 180,
                      child:
                          CustomPaint(painter: MembershipPlot(input, value))),
                  const SizedBox(height: 12),
                  Wrap(spacing: 16, children: [
                    for (final term in input.terms.entries)
                      Text(
                          '${term.key}: μ=${term.value.degree(value).toStringAsFixed(2)}')
                  ]),
                  Text('${input.min} → ${input.max} · μ: 0 → 1'),
                  const SizedBox(height: 24),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              '${engine.outputs.single.name}: ${result.outputs.values.single?.toStringAsFixed(1) ?? "—"} / ${engine.outputs.single.max.toStringAsFixed(0)}',
                              style:
                                  Theme.of(context).textTheme.headlineSmall))),
                  for (final activation in result.rules)
                    ListTile(
                        title: Text(activation.rule.name),
                        subtitle:
                            LinearProgressIndicator(value: activation.strength),
                        trailing: Text(
                            '${(activation.strength * 100).toStringAsFixed(0)}%')),
                  const SizedBox(height: 16),
                  Text(portuguese
                      ? 'Modelos didáticos. Os graus não são probabilidades. Calibre limites e regras para seu domínio.'
                      : 'Educational models. Degrees are not probabilities. Calibrate ranges and rules for your domain.'),
                ]))));
  }
}
