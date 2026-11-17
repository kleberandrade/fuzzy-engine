import 'dart:convert';
import 'lab_model.dart';

/// A private editing transaction. Only validate() produces an executable model.
class VisualDraft {
  VisualDraft(LabModel model)
      : json = jsonDecode(model.export()) as Map<String, dynamic>;
  final Map<String, dynamic> json;
  String get family => json['engineType'] as String;
  List<Map<String, dynamic>> get inputs => (json['inputs'] as List).cast();
  List<Map<String, dynamic>> get outputs => (json['outputs'] as List).cast();
  List<Map<String, dynamic>> get rules => (json['rules'] as List).cast();
  Map<String, dynamic> terms(bool input, int index) =>
      (input ? inputs : outputs)[index]['terms'] as Map<String, dynamic>;

  static const shapes = {
    'triangle': ['a', 'b · peak', 'c'],
    'trapezoid': ['a', 'b · plateau start', 'c · plateau end', 'd'],
    'gaussian': ['mean', 'sigma > 0'],
    'ramp': ['start', 'end'],
    'sigmoid': ['midpoint', 'slope'],
    'bell': ['center', 'width > 0', 'slope > 0'],
    'sShape': ['a', 'b'],
    'zShape': ['a', 'b'],
    'piShape': ['a', 'b', 'c', 'd'],
    'rectangle': ['a', 'b'],
    'discrete': <String>[],
  };
  static const monotonicShapes = ['ramp', 'sShape', 'zShape'];
  static Map<String, dynamic> membership(String type, double min, double max) {
    final span = max - min, mid = min + (max - min) / 2;
    final parameters = switch (type) {
      'triangle' => [min, mid, max],
      'trapezoid' || 'piShape' => [
          min,
          min + span / 3,
          min + span * 2 / 3,
          max
        ],
      'gaussian' => [mid, span / 4],
      'sigmoid' => [mid, 10 / span],
      'bell' => [mid, span / 4, 2.0],
      'discrete' => [
          [min, 0.0],
          [mid, 1.0],
          [max, 0.0]
        ],
      _ => [min, max],
    };
    return {'type': type, 'parameters': parameters};
  }

  void addTerm(bool input, int index) {
    final variable = (input ? inputs : outputs)[index];
    final catalog = terms(input, index);
    final name = uniqueName('term', catalog.keys);
    final min = variable['min'], max = variable['max'];
    catalog[name] = membership(
        !input && family == 'tsukamoto' ? 'ramp' : 'triangle',
        min is num ? min.toDouble() : 0,
        max is num && min is num && max > min ? max.toDouble() : 100);
  }

  void renameTerm(bool input, int index, String oldName, String name) {
    final catalog = terms(input, index);
    if (name.trim().isEmpty || (name != oldName && catalog.containsKey(name))) {
      throw const FormatException('Choose a nonempty, unique term name.');
    }
    if (name == oldName) return;
    final entries = catalog.entries
        .map((e) => MapEntry(e.key == oldName ? name : e.key, e.value))
        .toList();
    catalog
      ..clear()
      ..addEntries(entries);
    final variable = (input ? inputs : outputs)[index]['name'];
    for (final rule in rules) {
      if (input) {
        _renameReferences(
            rule['when'] as Map<String, dynamic>, variable, oldName, name);
      } else if (rule['output'] == variable && rule['term'] == oldName) {
        rule['term'] = name;
      }
    }
  }

  void _renameReferences(
      Map<String, dynamic> node, Object variable, String old, String name) {
    if (node['type'] == 'term' &&
        node['variable'] == variable &&
        node['term'] == old) node['term'] = name;
    for (final key in ['left', 'right', 'operand']) {
      if (node[key] is Map<String, dynamic>)
        _renameReferences(node[key], variable, old, name);
    }
  }

  Map<String, dynamic> defaultCondition() {
    final input = inputs.first;
    final catalog = input['terms'] as Map;
    return {
      'type': 'term',
      'variable': input['name'],
      'term': catalog.keys.firstOrNull ?? ''
    };
  }

  void addRule() {
    final output = outputs.first;
    (json['rules'] as List).add({
      'name': uniqueName('rule', rules.map((r) => r['name'] as String)),
      'when': defaultCondition(),
      'output': output['name'],
      'weight': 1.0,
      if (family == 'sugeno')
        'consequent': {'type': 'constant', 'value': 50.0}
      else
        'term': (output['terms'] as Map).keys.firstOrNull ?? '',
    });
  }

  static String uniqueName(String prefix, Iterable<String> names) {
    var i = 1;
    while (names.contains('$prefix$i')) {
      i++;
    }
    return '$prefix$i';
  }

  LabModel validate() {
    final candidate = LabModel.importJson(json);
    try {
      candidate.evaluate(candidate.initialValues);
    } on StateError catch (e) {
      throw FormatException(e.message);
    }
    return candidate;
  }
}
