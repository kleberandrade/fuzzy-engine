import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzy_engine_example/scenarios.dart';

void main() {
  test('ventilation surface covers endpoints and every sampled input pair', () {
    final engine = ventilationController();
    expect(engine.inputs.length, 2);
    expect(engine.rules.length, 9);
    for (var t = 0; t <= 20; t++) {
      for (var h = 0; h <= 20; h++) {
        final result =
            engine.evaluate({'temperature': 2.0 * t, 'humidity': 5.0 * h});
        expect(result.value('fanDemand'), inInclusiveRange(0, 100));
        expect(result.rules.any((r) => r.strength > 0), true);
      }
    }
  });
  test(
      'climate FIS round-trip covers both outputs and retains independent rules',
      () {
    final original = climateController();
    final model = climateFisModel();
    for (var t = 0; t <= 20; t++) {
      for (var h = 0; h <= 20; h++) {
        final inputs = {'temperature': 2.0 * t, 'humidity': 5.0 * h};
        final expected = original.evaluate(inputs);
        final result = model.evaluate(inputs);
        for (final output in ['fanDemand', 'heaterDemand']) {
          expect(result.values[output], inInclusiveRange(0, 100));
          expect(
              result.values[output], closeTo(expected.value(output)!, 1e-12));
        }
        expect(result.usedFallback, isFalse);
      }
    }
    final cold = model.evaluate({'temperature': 0, 'humidity': 0});
    final hot = model.evaluate({'temperature': 40, 'humidity': 100});
    expect(
        cold.values['heaterDemand'], greaterThan(hot.values['heaterDemand']!));
    expect(cold.values['fanDemand'], lessThan(hot.values['fanDemand']!));
  });
  test('each input independently changes the ventilation decision', () {
    final engine = ventilationController();
    double value(double t, double h) =>
        engine.evaluate({'temperature': t, 'humidity': h}).value('fanDemand')!;
    expect(value(20, 50), closeTo(50, 1e-10));
    expect(value(40, 50), greaterThan(value(20, 50)));
    expect(value(40, 0), closeTo(50, 1e-10));
    expect(value(0, 0), lessThan(value(40, 100)));
  });
}
