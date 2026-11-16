import 'dart:math' as math;
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'package:test/test.dart';

void main() {
  test('ramp saturates beyond endpoints in both directions', () {
    final rising = Ramp(0, 10), falling = Ramp(10, 0);
    for (final x in [-5.0, 0.0, 2.5, 5.0, 10.0, 15.0]) {
      final expected = (x / 10).clamp(0.0, 1.0);
      expect(rising.degree(x), expected);
      expect(falling.degree(x), 1 - expected);
    }
  });
  test('sigmoid matches logistic reference and supports descending curves', () {
    final rising = Sigmoid(5, 2), falling = Sigmoid(5, -2);
    expect(rising.degree(5), .5);
    expect(rising.degree(6), closeTo(1 / (1 + math.exp(-2)), 1e-12));
    for (final x in [-1000.0, 0.0, 5.0, 10.0, 1000.0]) {
      expect(rising.degree(x) + falling.degree(x), closeTo(1, 1e-12));
    }
    expect(rising.degree(1000), 1);
    expect(rising.degree(-1000), 0);
  });
  test('bell has expected center, half-width and shape', () {
    final bell = Bell(5, 2, 2);
    expect(bell.degree(5), 1);
    expect(bell.degree(3), .5);
    expect(bell.degree(7), .5);
    expect(bell.degree(9), closeTo(1 / 17, 1e-12));
    expect(bell.degree(1), bell.degree(9));
  });
  test('S and Z shapes agree with independent quadratic values', () {
    final s = SShape(0, 10), z = ZShape(0, 10);
    final values = {
      -1.0: 0.0,
      0.0: 0.0,
      2.5: .125,
      5.0: .5,
      7.5: .875,
      10.0: 1.0,
      11.0: 1.0
    };
    for (final entry in values.entries) {
      expect(s.degree(entry.key), entry.value);
      expect(z.degree(entry.key), 1 - entry.value);
    }
  });
  test('Pi shape combines two smooth edges and an inclusive plateau', () {
    final pi = PiShape(0, 2, 6, 10);
    expect([
      pi.degree(-1),
      pi.degree(0),
      pi.degree(1),
      pi.degree(2),
      pi.degree(4),
      pi.degree(6),
      pi.degree(8),
      pi.degree(10),
      pi.degree(11)
    ], [
      0,
      0,
      .5,
      1,
      1,
      1,
      .5,
      0,
      0
    ]);
    expect(PiShape(0, 5, 5, 10).degree(5), 1);
  });
  test('rectangle includes its endpoints and has zero tails', () {
    final r = Rectangle(2, 4);
    expect([r.degree(1), r.degree(2), r.degree(3), r.degree(4), r.degree(5)],
        [0, 1, 1, 1, 0]);
  });
  test(
      'discrete set interpolates nonuniform points and preserves endpoint values',
      () {
    final f = DiscreteSet([
      MembershipPoint(0, .2),
      MembershipPoint(2, 1),
      MembershipPoint(10, .4)
    ]);
    expect(f.degree(-1), 0);
    expect(f.degree(0), .2);
    expect(f.degree(1), closeTo(.6, 1e-12));
    expect(f.degree(2), 1);
    expect(f.degree(6), closeTo(.7, 1e-12));
    expect(f.degree(10), .4);
    expect(f.degree(11), 0);
  });
  test('discrete set copies the source list and rejects mutations', () {
    final points = [MembershipPoint(0, 0), MembershipPoint(1, 1)];
    final f = DiscreteSet(points);
    points.clear();
    expect(f.degree(.5), .5);
    expect(() => f.points.clear(), throwsUnsupportedError);
  });
  test('invalid parameters fail eagerly', () {
    for (final create in <Object Function()>[
      () => Ramp(1, 1),
      () => Ramp(-1e308, 1e308),
      () => Sigmoid(0, 0),
      () => Sigmoid(double.nan, 1),
      () => Bell(0, 0, 1),
      () => Bell(0, 1, -1),
      () => Bell(0, 1, double.infinity),
      () => SShape(1, 1),
      () => ZShape(2, 1),
      () => SShape(-1e308, 1e308),
      () => PiShape(0, 3, 2, 4),
      () => PiShape(0, 0, 1, 2),
      () => Rectangle(2, 1),
      () => Rectangle(0, double.infinity),
      () => MembershipPoint(0, 1.1),
      () => MembershipPoint(double.nan, 0),
      () => DiscreteSet([]),
      () => DiscreteSet([MembershipPoint(0, 0)]),
      () => DiscreteSet([MembershipPoint(1, 0), MembershipPoint(1, 1)]),
      () => DiscreteSet([MembershipPoint(1, 0), MembershipPoint(0, 1)]),
      () =>
          DiscreteSet([MembershipPoint(-1e308, 0), MembershipPoint(1e308, 1)]),
    ]) {
      expect(create, throwsArgumentError);
    }
  });
  final functions = <String, MembershipFunction>{
    'ramp': Ramp(0, 1),
    'sigmoid': Sigmoid(0, 1),
    'bell': Bell(0, 1, 2),
    'S': SShape(0, 1),
    'Z': ZShape(0, 1),
    'Pi': PiShape(0, 1, 2, 3),
    'rectangle': Rectangle(0, 1),
    'discrete': DiscreteSet([MembershipPoint(0, 0), MembershipPoint(1, 1)]),
  };
  for (final entry in functions.entries) {
    test('${entry.key} rejects nonfinite input and stays bounded on a grid',
        () {
      for (final x in [double.nan, double.infinity, double.negativeInfinity]) {
        expect(() => entry.value.degree(x), throwsArgumentError);
      }
      for (var i = -100; i <= 100; i++) {
        final degree = entry.value.degree(i / 10);
        expect(degree.isFinite, isTrue);
        expect(degree, inInclusiveRange(0, 1));
      }
    });
  }
  test('extreme finite inputs avoid overflow in normalized differences', () {
    expect(Sigmoid(-1e308, 1e-308).degree(1e308),
        closeTo(1 / (1 + math.exp(-2)), 1e-12));
    expect(Gaussian(-1e308, 1e308).degree(1e308), closeTo(math.exp(-2), 1e-12));
    expect(Bell(0, 1e-300, 1e-300).degree(1e300), closeTo(.5, 1e-12));
    expect(Bell(-1e308, 1e308, 1).degree(1e308), closeTo(.2, 1e-12));
  });
}
