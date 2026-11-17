// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'editor_fields.dart';
import 'visual_draft.dart';

class ConditionEditor extends StatelessWidget {
  const ConditionEditor(
      {super.key,
      required this.node,
      required this.draft,
      required this.path,
      required this.onChanged,
      required this.portuguese});
  final Map<String, dynamic> node;
  final VisualDraft draft;
  final String path;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool portuguese;
  String tr(String en, String pt) => portuguese ? pt : en;

  void changeType(String type) {
    final next = switch (type) {
      'term' => draft.defaultCondition(),
      'and' || 'or' => {
          'type': type,
          'left': node['left'] ?? Map<String, dynamic>.of(node),
          'right': node['right'] ?? draft.defaultCondition(),
        },
      'not' => {
          'type': 'not',
          'operand': node['operand'] ?? Map<String, dynamic>.of(node)
        },
      _ => {
          'type': 'hedge',
          'modifier': type,
          'operand': node['operand'] ?? Map<String, dynamic>.of(node)
        },
    };
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final type = node['type'] == 'hedge'
        ? node['modifier'] as String
        : node['type'] as String;
    final variable =
        draft.inputs.where((v) => v['name'] == node['variable']).firstOrNull;
    Widget child(String name) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ConditionEditor(
              node: node[name] as Map<String, dynamic>,
              draft: draft,
              path: '$path-$name',
              portuguese: portuguese,
              onChanged: (value) {
                node[name] = value;
                onChanged(node);
              }),
        );
    final typeChoice = editorChoice(
        'condition-$path-type',
        tr('Condition', 'Condição'),
        type,
        const ['term', 'and', 'or', 'not', 'very', 'somewhat'],
        changeType);
    if (type == 'term')
      return LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fieldWidth = width >= 700 ? (width - 24) / 3 : width;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final field in [
            typeChoice,
            editorChoice(
                'condition-$path-variable',
                tr('Input', 'Entrada'),
                node['variable'] as String?,
                draft.inputs.map((v) => v['name'] as String), (value) {
              node['variable'] = value;
              node['term'] =
                  (draft.inputs.firstWhere((v) => v['name'] == value)['terms']
                              as Map)
                          .keys
                          .firstOrNull ??
                      '';
              onChanged(node);
            }),
            editorChoice(
                'condition-$path-term',
                tr('Is', 'É'),
                node['term'] as String?,
                (variable?['terms'] as Map?)?.keys.cast<String>() ??
                    const <String>[], (value) {
              node['term'] = value;
              onChanged(node);
            }),
          ])
            SizedBox(width: fieldWidth, child: field),
        ]);
      });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      typeChoice,
      ExpansionTile(
        key: ValueKey('$path-$type'),
        initiallyExpanded: path.split('-').length < 4,
        tilePadding: EdgeInsets.zero,
        title: Text(tr('Operands · $type', 'Operandos · $type')),
        children: [
          if (type == 'and' || type == 'or') ...[
            Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('Left condition', 'Condição esquerda'))),
            child('left'),
            const SizedBox(height: 16),
            Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('Right condition', 'Condição direita'))),
            child('right'),
          ] else
            child('operand'),
        ],
      ),
    ]);
  }
}
