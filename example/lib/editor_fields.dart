// ignore: deprecated_member_use
import 'package:flutter/material.dart';

Widget editorNumber(String id, String label, Object? value,
        ValueChanged<Object> onChanged) =>
    SizedBox(
        width: 160,
        child: TextFormField(
          key: ValueKey(id),
          initialValue: '$value',
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(
              signed: true, decimal: true),
          onChanged: (text) {
            final number = double.tryParse(text);
            onChanged(number != null && number.isFinite ? number : text);
          },
        ));

Widget editorChoice(String id, String label, String? value,
    Iterable<String> choices, ValueChanged<String> onChanged) {
  final options = choices.toList();
  return InputDecorator(
    decoration:
        InputDecoration(labelText: label, border: const OutlineInputBorder()),
    child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
      key: ValueKey(id),
      isExpanded: true,
      value: options.contains(value) ? value : null,
      hint: const Text('—'),
      items: [
        for (final option in options)
          DropdownMenuItem(
              value: option,
              child: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis))
      ],
      onChanged: options.isEmpty ? null : (v) => onChanged(v!),
    )),
  );
}
