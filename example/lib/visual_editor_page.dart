// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'lab_model.dart';
import 'visual_draft.dart';
import 'editor_fields.dart';
import 'condition_editor.dart';
import 'membership_plot.dart';

class VisualEditorPage extends StatefulWidget {
  const VisualEditorPage(
      {super.key, required this.model, required this.portuguese});
  final LabModel model;
  final bool portuguese;
  @override
  State<VisualEditorPage> createState() => _VisualEditorPageState();
}

class _VisualEditorPageState extends State<VisualEditorPage> {
  late final draft = VisualDraft(widget.model);
  int inputIndex = 0, outputIndex = 0, ruleIndex = 0;
  String tr(String en, String pt) =>
      AppScope.pt(context, fallback: widget.portuguese) ? pt : en;
  void change(VoidCallback edit) => setState(edit);

  Future<void> rename(bool input, int index, String old) async {
    var name = old;
    String? error;
    await showDialog<void>(
        useRootNavigator: false,
        context: context,
        builder: (context) => StatefulBuilder(
              builder: (context, update) => AlertDialog(
                title: Text(tr('Rename term', 'Renomear termo')),
                content: TextFormField(
                    initialValue: old,
                    autofocus: true,
                    decoration: InputDecoration(
                        labelText: tr('Term name', 'Nome do termo'),
                        errorText: error == null
                            ? null
                            : localizedProblem(
                                error!,
                                AppScope.pt(context,
                                    fallback: widget.portuguese))),
                    onChanged: (v) => name = v),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('Cancel', 'Cancelar'))),
                  FilledButton(
                      onPressed: () {
                        try {
                          draft.renameTerm(input, index, old, name.trim());
                          Navigator.pop(context);
                          setState(() {});
                        } on FormatException catch (e) {
                          update(() => error = e.message);
                        }
                      },
                      child: Text(tr('Rename', 'Renomear'))),
                ],
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    LabModel? candidate;
    String? error;
    try {
      candidate = draft.validate();
    } on FormatException catch (e) {
      error = e.message;
    }
    final valid = candidate;
    return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr('Visual model editor', 'Editor visual do modelo')),
            actions: [
              Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    key: const ValueKey('apply-visual'),
                    onPressed: valid == null
                        ? null
                        : () => Navigator.pop(context, valid),
                    icon: const Icon(Icons.check),
                    label: Text(tr('Apply', 'Aplicar')),
                  ))
            ],
            bottom: TabBar(tabs: [
              Tab(text: tr('Inputs', 'Entradas')),
              Tab(text: tr('Outputs', 'Saídas')),
              Tab(text: tr('Rules', 'Regras')),
            ]),
          ),
          body: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: TabBarView(children: [
              variables(true, valid, error),
              variables(false, valid, error),
              rules(valid, error),
            ]),
          )),
        ));
  }

  Widget header(LabModel? valid, String? error) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${widget.model.family} · ${tr('Draft configuration', 'Configuração em edição')}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(tr(
              'Edit curves and IF–THEN rules. Apply saves this model; Back cancels all draft changes.',
              'Edite curvas e regras SE–ENTÃO. Aplicar salva o modelo; Voltar cancela todas as alterações.')),
          const SizedBox(height: 8),
          Semantics(
              liveRegion: true,
              child: Text(
                  error == null
                      ? tr('✓ Valid model · preview uses input midpoints',
                          '✓ Modelo válido · prévia usa pontos médios das entradas')
                      : '${tr('Fix before applying', 'Corrija antes de aplicar')}: ${localizedProblem(error, AppScope.pt(context, fallback: widget.portuguese))}',
                  key: const ValueKey('draft-status'),
                  style: TextStyle(
                      color: error == null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error))),
          if (valid != null)
            Wrap(spacing: 16, children: [
              for (final entry
                  in valid.evaluate(valid.initialValues).outputs.entries)
                Text(
                    '${entry.key}: ${entry.value?.toStringAsFixed(2) ?? tr('No decision', 'Sem decisão')}',
                    key: ValueKey('preview-${entry.key}')),
            ]),
          const SizedBox(height: 20),
        ],
      );

  Widget variables(bool input, LabModel? candidate, String? error) {
    final variables = input ? draft.inputs : draft.outputs;
    final index = input ? inputIndex : outputIndex;
    final variable = variables[index];
    final names = variables.map((v) => v['name'] as String).toList();
    if (!input && draft.family == 'sugeno') {
      return ListView(
          key: ValueKey('variables-$input'),
          padding: const EdgeInsets.all(20),
          children: [
            header(candidate, error),
            Text(tr(
                'Sugeno uses crisp consequents, not output membership curves. Edit constants and linear coefficients in Rules.',
                'Sugeno usa conclusões numéricas, sem curvas de saída. Edite constantes e coeficientes lineares em Regras.')),
            for (final name in names)
              ListTile(leading: const Icon(Icons.output), title: Text(name)),
          ]);
    }
    FuzzyVariable? preview;
    if (candidate != null) {
      if (input) {
        preview = candidate.inputs[index];
      } else {
        final e = candidate.document.engine;
        if (e is FuzzyEngine) preview = e.outputs[index];
        if (e is TsukamotoEngine) {
          final o = e.outputs[index];
          preview = FuzzyVariable(
              name: o.name, min: o.min, max: o.max, terms: o.terms);
        }
      }
    }
    return ListView(
        key: ValueKey('variables-$input'),
        padding: const EdgeInsets.all(20),
        children: [
          header(candidate, error),
          editorChoice(
              '${input ? 'input' : 'output'}-variable',
              tr('Variable', 'Variável'),
              variable['name'],
              names,
              (name) => change(() {
                    if (input) {
                      inputIndex = names.indexOf(name);
                    } else {
                      outputIndex = names.indexOf(name);
                    }
                  })),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final bound in ['min', 'max'])
              editorNumber('$input-$index-$bound', bound, variable[bound],
                  (v) => change(() => variable[bound] = v)),
          ]),
          if (preview != null) ...[
            const SizedBox(height: 20),
            Semantics(
                label: tr('Membership curve preview, degree zero to one',
                    'Prévia das curvas de pertinência, grau de zero a um'),
                child: Container(
                    height: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12)),
                    child: CustomPaint(
                        painter: MembershipPlot(preview,
                            preview.min + (preview.max - preview.min) / 2)))),
            const SizedBox(height: 8),
            Text(
                '${preview.min} → ${preview.max} · μ: 0 → 1 · ${preview.terms.keys.join(' / ')}'),
          ],
          const SizedBox(height: 16),
          for (final term in draft.terms(input, index).entries)
            termCard(
                input, index, term.key, term.value as Map<String, dynamic>),
          const SizedBox(height: 8),
          OutlinedButton.icon(
              key: ValueKey('add-term-$input'),
              onPressed: () => change(() => draft.addTerm(input, index)),
              icon: const Icon(Icons.add),
              label: Text(
                  tr('Add membership term', 'Adicionar termo de pertinência'))),
          const SizedBox(height: 20),
          Text(tr(
              'Names of variables stay unchanged. Term renames update references. Deleting a referenced term requires repairing its rules before Apply.',
              'Os nomes das variáveis são preservados. Renomear termos atualiza referências. Ao excluir um termo usado, corrija suas regras antes de Aplicar.')),
        ]);
  }

  Widget termCard(
      bool input, int index, String name, Map<String, dynamic> membership) {
    final type = membership['type'] as String;
    final parameters = membership['parameters'] as List;
    final variable = (input ? draft.inputs : draft.outputs)[index];
    final id = '$input-$index-$name';
    return Card(
        key: ObjectKey(membership),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(name,
                      style: Theme.of(context).textTheme.titleMedium)),
              IconButton(
                  tooltip: tr('Rename $name', 'Renomear $name'),
                  onPressed: () => rename(input, index, name),
                  icon: const Icon(Icons.edit_outlined)),
              IconButton(
                  key: ValueKey('delete-term-$id'),
                  tooltip: tr('Delete $name', 'Excluir $name'),
                  onPressed: () =>
                      change(() => draft.terms(input, index).remove(name)),
                  icon: const Icon(Icons.delete_outline)),
            ]),
            const SizedBox(height: 8),
            editorChoice(
                'shape-$id',
                tr('Function shape', 'Formato da função'),
                type,
                !input && draft.family == 'tsukamoto'
                    ? VisualDraft.monotonicShapes
                    : VisualDraft.shapes.keys,
                (shape) => change(() {
                      final min = variable['min'], max = variable['max'];
                      draft.terms(input, index)[name] = VisualDraft.membership(
                          shape,
                          min is num ? min.toDouble() : 0,
                          max is num && min is num && max > min
                              ? max.toDouble()
                              : 100);
                    })),
            const SizedBox(height: 16),
            if (type == 'discrete') ...[
              for (var i = 0; i < parameters.length; i++)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          editorNumber(
                              '$id-point-${identityHashCode(parameters[i])}-x',
                              'x ${i + 1}',
                              parameters[i][0],
                              (v) => change(() => parameters[i][0] = v)),
                          editorNumber(
                              '$id-point-${identityHashCode(parameters[i])}-y',
                              'μ ${i + 1}',
                              parameters[i][1],
                              (v) => change(() => parameters[i][1] = v)),
                          IconButton(
                              tooltip: tr('Remove point ${i + 1}',
                                  'Remover ponto ${i + 1}'),
                              onPressed: () =>
                                  change(() => parameters.removeAt(i)),
                              icon: const Icon(Icons.remove_circle_outline)),
                        ])),
              TextButton.icon(
                  onPressed: () => change(() {
                        final last =
                            parameters.isEmpty ? null : parameters.last[0];
                        parameters.add([last is num ? last + 1 : 0.0, 0.0]);
                      }),
                  icon: const Icon(Icons.add),
                  label: Text(tr('Add point', 'Adicionar ponto'))),
            ] else
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (var i = 0; i < parameters.length; i++)
                  editorNumber(
                      'parameter-$id-$type-$i',
                      '$name · ${VisualDraft.shapes[type]![i]}',
                      parameters[i],
                      (v) => change(() => parameters[i] = v)),
              ]),
          ]),
        ));
  }

  Widget rules(LabModel? candidate, String? error) {
    final all = draft.rules;
    final labels = [
      for (var i = 0; i < all.length; i++) '${i + 1} · ${all[i]['name']}'
    ];
    final rule = all.isEmpty ? null : all[ruleIndex.clamp(0, all.length - 1)];
    return ListView(
        key: const ValueKey('visual-rules'),
        padding: const EdgeInsets.all(20),
        children: [
          header(candidate, error),
          if (rule != null) ...[
            editorChoice(
                'selected-rule',
                tr('Rule', 'Regra'),
                labels[ruleIndex.clamp(0, all.length - 1)],
                labels,
                (label) => change(() => ruleIndex = labels.indexOf(label))),
            const SizedBox(height: 16),
            TextFormField(
                key: ValueKey('rule-name-${identityHashCode(rule)}'),
                initialValue: rule['name'],
                decoration: InputDecoration(
                    labelText: tr('Rule name', 'Nome da regra'),
                    border: const OutlineInputBorder()),
                onChanged: (v) => change(() => rule['name'] = v)),
            const SizedBox(height: 16),
            editorNumber(
                'rule-weight-${identityHashCode(rule)}',
                tr('Weight · 0 to 1', 'Peso · 0 a 1'),
                rule['weight'],
                (v) => change(() => rule['weight'] = v)),
            const SizedBox(height: 24),
            Text(tr('IF', 'SE'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ConditionEditor(
                node: rule['when'] as Map<String, dynamic>,
                draft: draft,
                path: 'rule$ruleIndex',
                portuguese: widget.portuguese,
                onChanged: (v) => change(() => rule['when'] = v)),
            const SizedBox(height: 24),
            Text(tr('THEN', 'ENTÃO'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            editorChoice(
                'rule-output',
                tr('Output', 'Saída'),
                rule['output'],
                draft.outputs.map((o) => o['name'] as String),
                (v) => change(() {
                      rule['output'] = v;
                      if (draft.family != 'sugeno')
                        rule['term'] = (draft.outputs.firstWhere(
                                    (o) => o['name'] == v)['terms'] as Map)
                                .keys
                                .firstOrNull ??
                            '';
                    })),
            const SizedBox(height: 12),
            if (draft.family == 'sugeno')
              sugeno(rule)
            else
              editorChoice(
                  'rule-consequent',
                  tr('Is', 'É'),
                  rule['term'],
                  (draft.outputs.firstWhere(
                          (o) => o['name'] == rule['output'])['terms'] as Map)
                      .keys
                      .cast<String>(),
                  (v) => change(() => rule['term'] = v)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
                key: const ValueKey('delete-rule'),
                onPressed: () => change(() {
                      (draft.json['rules'] as List).removeAt(ruleIndex);
                      ruleIndex = 0;
                    }),
                icon: const Icon(Icons.delete_outline),
                label: Text(tr('Delete this rule', 'Excluir esta regra'))),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
              key: const ValueKey('add-rule'),
              onPressed: () => change(() {
                    draft.addRule();
                    ruleIndex = draft.rules.length - 1;
                  }),
              icon: const Icon(Icons.add),
              label: Text(tr('Add rule', 'Adicionar regra'))),
        ]);
  }

  Widget sugeno(Map<String, dynamic> rule) {
    final c = rule['consequent'] as Map<String, dynamic>;
    final linear = c['type'] == 'linear';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      editorChoice(
          'consequent-type',
          tr('Consequent', 'Conclusão'),
          c['type'],
          const ['constant', 'linear'],
          (v) => change(() => rule['consequent'] = v == 'constant'
              ? {'type': v, 'value': c['intercept'] ?? 50.0}
              : {
                  'type': v,
                  'intercept': c['value'] ?? 0.0,
                  'coefficients': <String, dynamic>{}
                })),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        if (!linear)
          editorNumber(
              'constant-${identityHashCode(rule)}',
              tr('Value', 'Valor'),
              c['value'],
              (v) => change(() => c['value'] = v))
        else ...[
          editorNumber(
              'intercept-${identityHashCode(rule)}',
              tr('Intercept', 'Intercepto'),
              c['intercept'],
              (v) => change(() => c['intercept'] = v)),
          for (final input in draft.inputs)
            editorNumber(
                'coefficient-${identityHashCode(rule)}-${input['name']}',
                '${input['name']} ×',
                (c['coefficients'] as Map)[input['name']] ?? 0,
                (v) => change(
                    () => (c['coefficients'] as Map)[input['name']] = v)),
        ],
      ]),
    ]);
  }
}
