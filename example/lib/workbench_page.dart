// Retain compatibility with Flutter before Material was extracted.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'configuration_dialog.dart';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'lab_model.dart';
import 'membership_plot.dart';
import 'visual_editor_page.dart';

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage(
      {super.key,
      required this.portuguese,
      this.initialModel,
      this.initialInputs});
  final Map<String, double>? initialInputs;
  final LabModel? initialModel;
  final bool portuguese;
  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  late List<LabModel> models =
      widget.initialModel == null ? comparisonModels() : [widget.initialModel!];
  late Map<String, double> values = widget.initialInputs == null
      ? models.first.initialValues
      : Map.of(widget.initialInputs!);
  int selected = 0;
  late bool imported = widget.initialModel != null;
  String tr(String en, String pt) =>
      AppScope.pt(context, fallback: widget.portuguese) ? pt : en;
  LabModel get model => models[selected];

  Future<void> configuration() async {
    final loaded = await showDialog<LabModel>(
      useRootNavigator: false,
      context: context,
      builder: (_) =>
          ConfigurationDialog(model: model, portuguese: widget.portuguese),
    );
    if (!mounted || loaded == null) return;
    setState(() {
      models = [loaded];
      selected = 0;
      imported = true;
      values = loaded.initialValues;
    });
  }

  Future<void> editVisually() async {
    final edited = await Navigator.of(context).push<LabModel>(MaterialPageRoute(
        builder: (_) =>
            VisualEditorPage(model: model, portuguese: widget.portuguese)));
    if (!mounted || edited == null) return;
    setState(() {
      models = [edited];
      selected = 0;
      imported = true;
      values = edited.initialValues;
    });
  }

  LabResult evaluate(LabModel target) {
    try {
      return target.evaluate(values);
    } on StateError catch (error) {
      return LabResult(const {}, const [], const {}, error: error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = evaluate(model);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Inference workbench', 'Bancada de inferência')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                model.document.name == null
                    ? tr('Model', 'Modelo')
                    : translatedOption(context, model.document.name!),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                imported
                    ? (model.document.description ??
                        tr(
                          'Model settings',
                          'Configurações do modelo',
                        ))
                    : tr(
                        'Same inputs. Different consequent definitions. Compare mechanisms, not accuracy.',
                        'Mesmas entradas. Conclusões distintas. Compare mecanismos, não precisão.',
                      ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                      key: const ValueKey('visual-editor'),
                      onPressed: editVisually,
                      icon: const Icon(Icons.tune),
                      label: Text(tr('Visual editor', 'Editor visual'))),
                  OutlinedButton.icon(
                    key: const ValueKey('configuration'),
                    onPressed: configuration,
                    icon: const Icon(Icons.data_object),
                    label: Text(
                      tr('Import / export JSON', 'Importar / exportar JSON'),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('reset-inputs'),
                    onPressed: () =>
                        setState(() => values = model.initialValues),
                    icon: const Icon(Icons.restart_alt),
                    label: Text(tr('Reset inputs', 'Reiniciar entradas')),
                  ),
                  if (imported)
                    OutlinedButton(
                      onPressed: () => setState(() {
                        models = comparisonModels();
                        selected = 0;
                        imported = false;
                        values = model.initialValues;
                      }),
                      child: Text(
                        tr('Restore comparison', 'Restaurar comparação'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              for (final input in model.inputs) ...[
                Text(
                  '${input.name}: ${values[input.name]!.toStringAsFixed(1)} ${model.document.inputUnits[input.name] ?? ''}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  key: ValueKey('input-${input.name}'),
                  min: input.min,
                  max: input.max,
                  value: values[input.name]!,
                  label: values[input.name]!.toStringAsFixed(1),
                  semanticFormatterCallback: (v) =>
                      '${input.name} ${v.toStringAsFixed(1)}',
                  onChanged: (v) => setState(() => values[input.name] = v),
                ),
                Semantics(
                  label:
                      '${input.name}: ${input.terms.entries.map((e) => '${e.key} ${e.value.degree(values[input.name]!).toStringAsFixed(2)}').join(', ')}',
                  child: SizedBox(
                    height: 130,
                    child: CustomPaint(
                      painter: MembershipPlot(input, values[input.name]!),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    for (final term in input.terms.entries)
                      Text(
                        '${term.key}: μ=${term.value.degree(values[input.name]!).toStringAsFixed(2)}',
                      ),
                  ],
                ),
                Text('${input.min} → ${input.max} · μ: 0 → 1'),
                const SizedBox(height: 24),
              ],
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < models.length; i++)
                    SizedBox(
                      width: 280,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                models[i].family,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(translatedOption(
                                  context, models[i].reduction)),
                              for (final output in evaluate(
                                models[i],
                              ).outputs.entries)
                                Text(
                                  '${output.key}: ${output.value?.toStringAsFixed(2) ?? tr('No decision', 'Sem decisão')} ${models[i].document.outputUnits[output.key] ?? ''}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              TextButton(
                                onPressed: () => setState(() => selected = i),
                                child: Text(
                                  i == selected
                                      ? tr(
                                          'Inspecting rules',
                                          'Inspecionando regras',
                                        )
                                      : tr(
                                          'Inspect rules',
                                          'Inspecionar regras',
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (result.error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '${tr('Cannot evaluate these inputs', 'Não foi possível avaliar as entradas')}: ${localizedProblem(result.error!, AppScope.pt(context, fallback: widget.portuguese))}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (model.document.engine is FuzzyEngine) ...[
                InputDecorator(
                  decoration: InputDecoration(
                      labelText: tr(
                          'Mamdani defuzzification', 'Defuzzificação Mamdani'),
                      border: const OutlineInputBorder()),
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                    value: model.reduction,
                    isExpanded: true,
                    items: [
                      for (final method in LabModel.methods)
                        DropdownMenuItem(
                            value: method,
                            child: Text(translatedOption(context, method)))
                    ],
                    onChanged: (method) => setState(() =>
                        models[selected] = model.withDefuzzifier(method!)),
                  )),
                ),
                const SizedBox(height: 16),
                for (final output in result.sets.entries) ...[
                  Text(
                    '${output.key} · ${tr('aggregated output', 'saída agregada')} (μ: 0–1)',
                  ),
                  Semantics(
                    label: tr(
                      'Aggregated output curve; crisp result displayed above.',
                      'Curva agregada; resultado numérico acima.',
                    ),
                    child: SizedBox(
                      height: 110,
                      child: CustomPaint(
                        painter: _OutputPlot(
                          output.value,
                          result.outputs[output.key],
                        ),
                      ),
                    ),
                  ),
                  Text('${output.value.min} → ${output.value.max}'),
                ],
              ],
              const SizedBox(height: 24),
              Text(
                '${model.family} · ${tr('Rule activations', 'Ativação das regras')}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final rule in result.rules)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${rule.name} · ${(rule.strength * 100).toStringAsFixed(1)}%',
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: rule.strength,
                        semanticsLabel: rule.name,
                        semanticsValue:
                            '${(rule.strength * 100).toStringAsFixed(1)}%',
                      ),
                      Text(AppScope.pt(context, fallback: widget.portuguese)
                          ? rule.detail.replaceAll('inverse=', 'inverso=')
                          : rule.detail),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                tr(
                  'Mamdani reduces an aggregated fuzzy set. Sugeno reduces crisp consequents. Tsukamoto inverts monotonic terms. Degrees are not probabilities. Inputs evaluate immediately; Reset restores midpoints and Cancel discards configuration edits.',
                  'Mamdani reduz um conjunto fuzzy agregado. Sugeno reduz conclusões numéricas. Tsukamoto inverte termos monotônicos. Graus não são probabilidades. Avaliação imediata; Reiniciar restaura pontos médios e Cancelar descarta edições.',
                ),
              ),
              if (imported)
                Text(
                  tr(
                    'Imported settings replace the comparison presets. JSON limits: 100000 characters, 2000 nodes, 8 inputs/outputs, 64 rules, 10000 output samples, 250000 rule/sample operations.',
                    'Configurações importadas substituem os exemplos. Limites JSON: 100000 caracteres, 2000 nós, 8 entradas/saídas, 64 regras, 10000 amostras de saída, 250000 operações regra/amostra.',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutputPlot extends CustomPainter {
  _OutputPlot(this.set, this.crisp);
  final SampledFuzzySet set;
  final double? crisp;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height);
    for (var i = 0; i <= set.intervals; i++) {
      path.lineTo(
        size.width * i / set.intervals,
        size.height * (1 - set.degrees[i]),
      );
    }
    path.lineTo(size.width, size.height);
    canvas.drawPath(
        path, Paint()..color = const Color(0xff65d7d0).withAlpha(80));
    if (crisp != null) {
      final x = (crisp! - set.min) / (set.max - set.min) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = const Color(0xff65d7d0)
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OutputPlot oldDelegate) =>
      oldDelegate.set != set || oldDelegate.crisp != crisp;
}
