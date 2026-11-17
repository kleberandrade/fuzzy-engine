// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'package:flutter/services.dart';
import 'lab_model.dart';

class ConfigurationDialog extends StatefulWidget {
  const ConfigurationDialog({
    super.key,
    required this.model,
    required this.portuguese,
  });
  final LabModel model;
  final bool portuguese;
  @override
  State<ConfigurationDialog> createState() => _ConfigurationDialogState();
}

class _ConfigurationDialogState extends State<ConfigurationDialog> {
  late final text = TextEditingController(text: widget.model.export());
  String? error;
  String tr(String en, String pt) =>
      AppScope.pt(context, fallback: widget.portuguese) ? pt : en;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void load() {
    try {
      final candidate = LabModel.import(text.text);
      candidate.evaluate(candidate.initialValues);
      Navigator.pop(context, candidate);
    } on FormatException catch (e) {
      invalid(e.message);
    } on ArgumentError catch (e) {
      invalid('${e.message}');
    } on StateError catch (e) {
      invalid(e.message);
    }
  }

  void invalid(String message) => setState(() => error = message);
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
          tr('Model configuration · JSON v2',
              'Configuração do modelo · JSON v2'),
        ),
        content: SizedBox(
          width: 640,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(
                  'Copy JSON to export. Paste a model to import. Loading resets inputs to their midpoints.',
                  'Copie o JSON para exportar. Cole um modelo para importar. As entradas voltam ao ponto médio.',
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: TextField(
                  controller: text,
                  minLines: 4,
                  maxLines: 14,
                  decoration: InputDecoration(
                    labelText: tr('Model JSON', 'JSON do modelo'),
                    border: const OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${tr('Invalid configuration', 'Configuração inválida')}: ${localizedProblem(error!, AppScope.pt(context, fallback: widget.portuguese))}',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel', 'Cancelar')),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text.text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('JSON copied', 'JSON copiado'))),
              );
            },
            child: Text(tr('Copy JSON', 'Copiar JSON')),
          ),
          FilledButton(
            onPressed: load,
            child: Text(tr('Validate and load', 'Validar e carregar')),
          ),
        ],
      );
}
