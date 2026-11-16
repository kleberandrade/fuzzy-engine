import 'dart:convert';
import 'dart:math' as math;
import 'package:fuzzy_engine/fuzzy_engine.dart';

/// Microbenchmark for membership functions and sampled defuzzification.
void main(List<String> args) {
  final count = args.isEmpty ? 100000 : int.parse(args.single);
  if (count <= 0) throw ArgumentError('Evaluation count must be positive.');
  final shapes = <String, MembershipFunction>{
    'Triangle': Triangle(0, 50, 100),
    'Trapezoid': Trapezoid(0, 30, 70, 100),
    'Gaussian': Gaussian(50, 20),
    'Ramp': Ramp(0, 100),
    'Sigmoid': Sigmoid(50, .1),
    'Bell': Bell(50, 20, 2),
    'SShape': SShape(0, 100),
    'ZShape': ZShape(0, 100),
    'PiShape': PiShape(0, 30, 70, 100),
    'Rectangle': Rectangle(20, 80),
    'DiscreteSet': DiscreteSet([
      MembershipPoint(0, 0),
      MembershipPoint(30, 1),
      MembershipPoint(100, 0)
    ]),
  };
  for (final entry in shapes.entries) {
    for (var i = 0; i < 1000; i++) {
      entry.value.degree((i % 1001) / 10);
    }
    var sum = 0.0;
    final timer = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      sum += entry.value.degree((i % 1001) / 10);
    }
    timer.stop();
    print(jsonEncode({
      'shape': entry.key,
      'calls': count,
      'microsecondsPerCall': timer.elapsedMicroseconds / count,
      'checksum': sum
    }));
  }
  final samples = SampledFuzzySet(
      min: 0,
      max: 100,
      degrees: [for (var i = 0; i <= 1000; i++) 1 - i / 1000]);
  final methods = <String, Defuzzifier>{
    'Centroid': const Centroid(),
    'Bisector': const Bisector(),
    'SmallestOfMaximum': SmallestOfMaximum(),
    'LargestOfMaximum': LargestOfMaximum(),
    'MeanOfMaximum': MeanOfMaximum()
  };
  final calls = math.max(1, count ~/ 100);
  for (final entry in methods.entries) {
    for (var i = 0; i < 50; i++) {
      entry.value.defuzzify(samples);
    }
    var sum = 0.0;
    final timer = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      sum += entry.value.defuzzify(samples)!;
    }
    timer.stop();
    print(jsonEncode({
      'defuzzifier': entry.key,
      'calls': calls,
      'samples': samples.degrees.length,
      'microsecondsPerCall': timer.elapsedMicroseconds / calls,
      'checksum': sum
    }));
  }
}
