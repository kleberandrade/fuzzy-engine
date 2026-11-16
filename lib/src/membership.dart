import 'dart:math' as math;

/// Maps a finite crisp value to a degree between 0 and 1.
abstract interface class MembershipFunction {
  /// Returns the membership degree of [x].
  double degree(double x);
}

void _finite(Iterable<double> values) {
  if (values.any((v) => !v.isFinite)) {
    throw ArgumentError('Parameters must be finite.');
  }
}

/// Triangular membership; repeated endpoints form left/right shoulders.
final class Triangle implements MembershipFunction {
  /// Requires a <= b <= c and a < c.
  Triangle(this.a, this.b, this.c) {
    _finite([a, b, c]);
    if (a > b || b > c || a == c) throw ArgumentError('Invalid triangle.');
  }

  /// Left endpoint.
  final double a;

  /// Peak.
  final double b;

  /// Right endpoint.
  final double c;
  @override
  double degree(double x) {
    _finite([x]);
    if (x < a || x > c) return 0;
    if (x == b) return 1;
    return x < b ? (x - a) / (b - a) : (c - x) / (c - b);
  }
}

/// Trapezoidal membership with an inclusive plateau.
final class Trapezoid implements MembershipFunction {
  /// Requires a <= b <= c <= d and a < d.
  Trapezoid(this.a, this.b, this.c, this.d) {
    _finite([a, b, c, d]);
    if (a > b || b > c || c > d || a == d) {
      throw ArgumentError('Invalid trapezoid.');
    }
  }

  /// Left endpoint.
  final double a;

  /// Plateau start.
  final double b;

  /// Plateau end.
  final double c;

  /// Right endpoint.
  final double d;
  @override
  double degree(double x) {
    _finite([x]);
    if (x < a || x > d) return 0;
    if (x >= b && x <= c) return 1;
    return x < b ? (x - a) / (b - a) : (d - x) / (d - c);
  }
}

/// Gaussian membership exp(-0.5 * ((x - mean) / sigma)^2).
final class Gaussian implements MembershipFunction {
  /// Requires positive [sigma].
  Gaussian(this.mean, this.sigma) {
    _finite([mean, sigma]);
    if (sigma <= 0) throw ArgumentError('sigma must be positive.');
  }

  /// Center.
  final double mean;

  /// Standard deviation.
  final double sigma;
  @override
  double degree(double x) {
    _finite([x]);
    final z = (x - mean) / sigma;
    return math.exp(-0.5 * z * z);
  }
}
