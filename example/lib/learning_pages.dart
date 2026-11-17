// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'learning_content.dart';

class LearnPage extends StatelessWidget {
  const LearnPage({super.key, required this.onPreset, required this.onLink});
  final ValueChanged<LabPreset> onPreset;
  final ValueChanged<String> onLink;
  @override
  Widget build(BuildContext context) {
    final pt = AppScope.pt(context);
    String tr(String en, String br) => pt ? br : en;
    return ListView(
        key: const PageStorageKey('learn-scroll'),
        padding: const EdgeInsets.all(24),
        children: [
          Text(tr('From measurements to decisions', 'De medições a decisões'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(tr(
              'An interactive guide to the implemented fuzzy_engine $engineVersion. Read a concept, open its experiment and return here without losing your lab state.',
              'Um guia interativo do fuzzy_engine $engineVersion implementado. Leia um conceito, abra seu experimento e volte sem perder o estado do laboratório.')),
          const SizedBox(height: 16),
          for (final lesson in lessons)
            Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lesson.title.at(pt),
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          Text(lesson.explanation.at(pt)),
                          const SizedBox(height: 16),
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12)),
                              child: SelectableText(lesson.formula,
                                  semanticsLabel:
                                      '${tr('Formula', 'Fórmula')}: ${lesson.formula}',
                                  style: const TextStyle(
                                      fontFamily: 'monospace', height: 1.6))),
                          const SizedBox(height: 12),
                          Text(lesson.interpretation.at(pt)),
                          const SizedBox(height: 16),
                          Wrap(spacing: 12, runSpacing: 8, children: [
                            FilledButton.icon(
                                key: ValueKey('learn-preset-${lesson.id}'),
                                onPressed: () => onPreset(lesson.preset),
                                icon: const Icon(Icons.science_outlined),
                                label: Text(tr('Run this example',
                                    'Executar este exemplo'))),
                            TextButton.icon(
                                onPressed: () =>
                                    onLink(topicUrl(lesson.source, pt)),
                                icon: const Icon(Icons.open_in_new),
                                label: Text(tr('Read the source guide',
                                    'Ler o guia de referência'))),
                          ]),
                        ]))),
          Text(tr('References and credits', 'Referências e créditos'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(tr(
              'Adapted from this project’s guides, toolbox, strategies, Sugeno, Tsukamoto and model-interchange documentation. Kleber Andrade · MIT. The original peak/convergence mark is created for this lab. Variable IDs and user-authored model text remain unchanged when translating the interface.',
              'Adaptado dos guias deste projeto, toolbox, estratégias, Sugeno, Tsukamoto e intercâmbio de modelos. Kleber Andrade · MIT. A marca original de picos/convergência foi criada para este laboratório. Identificadores e textos de modelos escritos pelo usuário permanecem iguais ao traduzir a interface.')),
          Wrap(spacing: 12, children: [
            TextButton(
                onPressed: () => onLink(guideUrl(pt)),
                child: Text(tr('Core guide', 'Guia do núcleo'))),
            TextButton(
                onPressed: () => onLink(repositoryUrl),
                child: const Text('GitHub'))
          ]),
          const SizedBox(height: 24),
          Text(tr('Five practical exercises', 'Cinco exercícios práticos'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          for (var i = 0; i < exercises.length; i++)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('${i + 1}. ${exercises[i].at(pt)}')),
        ]);
  }
}

class ExamplesPage extends StatelessWidget {
  const ExamplesPage({super.key, required this.onPreset});
  final ValueChanged<LabPreset> onPreset;
  @override
  Widget build(BuildContext context) {
    final pt = AppScope.pt(context);
    String tr(String en, String br) => pt ? br : en;
    const titles = {
      LabPreset.mamdani: LocalText(
          'Mamdani · clipped triangles', 'Mamdani · triângulos recortados'),
      LabPreset.sugeno: LocalText(
          'Sugeno · constants 20 and 80', 'Sugeno · constantes 20 e 80'),
      LabPreset.tsukamoto:
          LocalText('Tsukamoto · inverse ramps', 'Tsukamoto · rampas inversas'),
      LabPreset.irrigation:
          LocalText('Irrigation · dry soil', 'Irrigação · solo seco'),
      LabPreset.climate: LocalText(
          'Climate · two inputs and outputs', 'Clima · duas entradas e saídas'),
      LabPreset.uncovered: LocalText('No decision · missing coverage',
          'Sem decisão · cobertura incompleta'),
    };
    return ListView(
        key: const PageStorageKey('examples-scroll'),
        padding: const EdgeInsets.all(24),
        children: [
          Text(tr('Examples you can run', 'Exemplos para executar'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(tr(
              'These are local, deterministic teaching models. Each button opens an independent workbench with the listed inputs; Back returns to your previous experiment. Displayed outputs are evaluated by the same core as the lab.',
              'Estes modelos didáticos são locais e determinísticos. Cada botão abre uma bancada independente com as entradas indicadas; Voltar retorna ao experimento anterior. As saídas exibidas são calculadas pelo mesmo núcleo do laboratório.')),
          const SizedBox(height: 24),
          for (final entry in titles.entries)
            Builder(builder: (context) {
              final launch = launchPreset(entry.key);
              final result = launch.model.evaluate(launch.values);
              return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.value.at(pt),
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 12),
                            Text(
                                '${tr('Inputs', 'Entradas')}: ${launch.values.entries.map((v) => '${v.key} = ${v.value.toStringAsFixed(0)}').join(' · ')}'),
                            const SizedBox(height: 8),
                            Text(
                                '${tr('Outputs', 'Saídas')}: ${result.outputs.entries.map((v) => '${v.key} = ${v.value?.toStringAsFixed(2) ?? tr('No decision', 'Sem decisão')}').join(' · ')}'),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                                key: ValueKey('open-example-${entry.key.name}'),
                                onPressed: () => onPreset(entry.key),
                                icon: const Icon(Icons.play_arrow),
                                label: Text(tr('Open in laboratory',
                                    'Abrir no laboratório'))),
                          ])));
            }),
        ]);
  }
}
