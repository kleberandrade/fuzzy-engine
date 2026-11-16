import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Compare defuzzifiers on one two-input irrigation model.
void main() {
  final inputs = [
    FuzzyVariable(name: 'soilMoisture', min: 0, max: 100, terms: {
      'dry': ZShape(30, 70),
      'wet': SShape(30, 70),
    }),
    FuzzyVariable(name: 'airTemperature', min: 0, max: 50, terms: {
      'hot': Sigmoid(25, .25),
    }),
  ];
  final outputs = [
    FuzzyVariable(name: 'watering', min: 0, max: 100, terms: {
      'low': ZShape(0, 60),
      'high': SShape(40, 100),
    }),
  ];
  final rules = [
    FuzzyRule(
        name: 'dry and somewhat hot',
        when: const Term('soilMoisture', 'dry')
            .and(const Term('airTemperature', 'hot').hedge(const Somewhat())),
        output: 'watering',
        term: 'high'),
    FuzzyRule(
        name: 'wet',
        when: const Term('soilMoisture', 'wet'),
        output: 'watering',
        term: 'low'),
  ];
  final methods = <String, Defuzzifier>{
    'Centroid': const Centroid(),
    'Bisector': const Bisector(),
    'SmallestOfMaximum': SmallestOfMaximum(),
    'LargestOfMaximum': LargestOfMaximum(),
    'MeanOfMaximum': MeanOfMaximum(),
  };
  for (final method in methods.entries) {
    final engine = FuzzyEngine(
        inputs: inputs,
        outputs: outputs,
        rules: rules,
        defuzzifier: method.value);
    final result = engine.evaluate({'soilMoisture': 35, 'airTemperature': 32});
    print('${method.key}: ${result.value('watering')!.toStringAsFixed(2)}%');
  }
  // Degree .5 belongs to the very-hot set to degree .25.
  print('Very: ${const Very().transform(.5)}');
  final measured = DiscreteSet([
    MembershipPoint(0, 0),
    MembershipPoint(20, .4),
    MembershipPoint(50, 1),
    MembershipPoint(100, 0),
  ]);
  print('Interpolated measured degree at 35: ${measured.degree(35)}');
}
