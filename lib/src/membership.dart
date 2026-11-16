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
    final difference = x - mean;
    final z =
        difference.isFinite ? difference / sigma : x / sigma - mean / sigma;
    return math.exp(-0.5 * z * z);
  }
}

void _orderedEdge(double a, double b) {
  _finite([a, b]);
  if (a >= b || !(b - a).isFinite) {
    throw ArgumentError('Endpoints require a finite positive span.');
  }
}

/// Saturating linear membership from zero at [start] to one at [end].
/// Descending ramps use start > end; tails keep their endpoint degrees.
final class Ramp implements MembershipFunction {
  /// Requires distinct finite endpoints with a finite span.
  Ramp(this.start, this.end) {
    _finite([start, end]);
    if (start == end || !(end - start).isFinite) {
      throw ArgumentError(
          'Ramp endpoints must be distinct with a finite span.');
    }
  }

  /// Zero-membership endpoint.
  final double start;

  /// Full-membership endpoint.
  final double end;
  @override
  double degree(double x) {
    _finite([x]);
    if (start < end) {
      if (x <= start) return 0;
      if (x >= end) return 1;
    } else {
      if (x >= start) return 0;
      if (x <= end) return 1;
    }
    return (x - start) / (end - start);
  }
}

/// Stable logistic membership, 1 / (1 + exp(-slope * (x-midpoint))).
final class Sigmoid implements MembershipFunction {
  /// Positive slope rises; negative slope falls. Zero slope is rejected.
  Sigmoid(this.midpoint, this.slope) {
    _finite([midpoint, slope]);
    if (slope == 0) throw ArgumentError('Sigmoid slope must be nonzero.');
  }

  /// Half-membership location.
  final double midpoint;

  /// Signed steepness.
  final double slope;
  @override
  double degree(double x) {
    _finite([x]);
    final difference = x - midpoint;
    final z =
        difference.isFinite ? slope * difference : slope * x - slope * midpoint;
    if (z >= 0) return 1 / (1 + math.exp(-z));
    final e = math.exp(z);
    return e / (1 + e);
  }
}

/// Generalized bell: 1 / (1 + abs((x-center)/width)^(2*slope)).
final class Bell implements MembershipFunction {
  /// [width] and [slope] must be finite and positive.
  Bell(this.center, this.width, this.slope) {
    _finite([center, width, slope]);
    if (width <= 0 || slope <= 0)
      throw ArgumentError('Bell width and slope must be positive.');
  }

  /// Full-membership center.
  final double center;

  /// Distance from center at half membership.
  final double width;

  /// Positive shape exponent parameter.
  final double slope;
  @override
  double degree(double x) {
    _finite([x]);
    if (x == center) return 1;
    final distance = (x - center).abs();
    final scale = math.max(x.abs(), center.abs());
    final logDistance = distance.isFinite
        ? math.log(distance)
        : math.log(scale) + math.log((x / scale - center / scale).abs());
    final logRatio = logDistance - math.log(width);
    if (logRatio == 0) return .5;
    final z = 2 * (slope * logRatio);
    if (z >= 0) {
      final e = math.exp(-z);
      return e / (1 + e);
    }
    return 1 / (1 + math.exp(z));
  }
}

/// Smooth quadratic transition from zero at a to one at b.
final class SShape implements MembershipFunction {
  /// Requires a < b with finite span.
  SShape(this.a, this.b) {
    _orderedEdge(a, b);
  }

  /// Start of the transition.
  final double a;

  /// End of the transition.
  final double b;
  @override
  double degree(double x) {
    _finite([x]);
    if (x <= a) return 0;
    if (x >= b) return 1;
    final t = (x - a) / (b - a);
    return t <= .5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t);
  }
}

/// Smooth quadratic transition from one at a to zero at b.
final class ZShape implements MembershipFunction {
  /// Requires a < b with finite span.
  ZShape(this.a, this.b) : _rising = SShape(a, b);

  /// Start of the transition.
  final double a;

  /// End of the transition.
  final double b;
  final SShape _rising;
  @override
  double degree(double x) => 1 - _rising.degree(x);
}

/// Smooth compact membership with S-shaped rise, plateau and Z-shaped fall.
final class PiShape implements MembershipFunction {
  /// Requires a < b <= c < d, with finite rising/falling spans.
  PiShape(this.a, this.b, this.c, this.d)
      : _rise = SShape(a, b),
        _fall = ZShape(c, d) {
    if (b > c) throw ArgumentError('PiShape plateau requires b <= c.');
  }

  /// Left endpoint.
  final double a;

  /// Plateau start.
  final double b;

  /// Plateau end.
  final double c;

  /// Right endpoint.
  final double d;
  final SShape _rise;
  final ZShape _fall;
  @override
  double degree(double x) {
    _finite([x]);
    if (x <= b) return _rise.degree(x);
    if (x < c) return 1;
    return _fall.degree(x);
  }
}

/// Rectangular membership, one on the closed interval and zero outside it.
final class Rectangle implements MembershipFunction {
  /// Requires a < b with finite span.
  Rectangle(this.a, this.b) {
    _orderedEdge(a, b);
  }

  /// Inclusive left endpoint.
  final double a;

  /// Inclusive right endpoint.
  final double b;
  @override
  double degree(double x) {
    _finite([x]);
    return x >= a && x <= b ? 1 : 0;
  }
}

/// Immutable point for a piecewise linear membership function.
final class MembershipPoint {
  /// Requires a finite coordinate and a degree between zero and one.
  MembershipPoint(this.x, this.membership) {
    _finite([x, membership]);
    if (membership < 0 || membership > 1)
      throw ArgumentError('Point degree must be between zero and one.');
  }

  /// Crisp coordinate.
  final double x;

  /// Membership degree.
  final double membership;
}

/// Piecewise linear membership through ordered points; zero outside support.
final class DiscreteSet implements MembershipFunction {
  /// Copies at least two points, strictly ordered by x, with a finite total span.
  /// Duplicate coordinates are rejected rather than silently merged.
  DiscreteSet(List<MembershipPoint> points)
      : points = List.unmodifiable(points) {
    if (points.length < 2 || !(points.last.x - points.first.x).isFinite) {
      throw ArgumentError(
          'At least two points with a finite span are required.');
    }
    for (var i = 1; i < points.length; i++) {
      if (points[i - 1].x >= points[i].x)
        throw ArgumentError('Points must be strictly increasing.');
    }
  }

  /// Immutable ordered membership points.
  final List<MembershipPoint> points;
  @override
  double degree(double x) {
    _finite([x]);
    if (x < points.first.x || x > points.last.x) return 0;
    if (x == points.last.x) return points.last.membership;
    var low = 0, high = points.length - 1;
    while (high - low > 1) {
      final mid = (low + high) ~/ 2;
      if (x < points[mid].x) {
        high = mid;
      } else {
        low = mid;
      }
    }
    final left = points[low], right = points[high];
    final t = (x - left.x) / (right.x - left.x);
    return (1 - t) * left.membership + t * right.membership;
  }
}
