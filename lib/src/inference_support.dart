import 'model.dart';
import 'operators.dart';

// Shared implementation helpers, intentionally not exported by the package.
Map<String, FuzzyVariable> indexFuzzyVariables(List<FuzzyVariable> variables) {
  final map = <String, FuzzyVariable>{};
  for (final variable in variables) {
    if (map.containsKey(variable.name)) {
      throw ArgumentError('Duplicate variable: ${variable.name}');
    }
    map[variable.name] = variable;
  }
  return map;
}

Map<String, Map<String, double>> fuzzifyInputs(
    List<FuzzyVariable> inputs, Map<String, double> values) {
  if (values.length != inputs.length ||
      inputs.any((input) => !values.containsKey(input.name))) {
    throw ArgumentError('Supply exactly the declared inputs.');
  }
  final memberships = <String, Map<String, double>>{};
  for (final input in inputs) {
    final x = values[input.name];
    if (x == null || !x.isFinite || x < input.min || x > input.max) {
      throw ArgumentError(
          'Input ${input.name} must be in [${input.min}, ${input.max}].');
    }
    memberships[input.name] = input.terms.map(
        (name, function) => MapEntry(name, checkedDegree(function.degree(x))));
  }
  return memberships;
}
