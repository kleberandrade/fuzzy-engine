# Membership, hedges and defuzzification

[Português](toolbox.pt-BR.md) · [Strategies](strategies.en.md) · [Class diagrams](architecture.en.md)

## Membership catalog

| Function | Constructor | Behavior |
| --- | --- | --- |
| Triangle | Triangle(a, b, c) | Piecewise linear peak; repeated endpoints create shoulders |
| Trapezoid | Trapezoid(a, b, c, d) | Piecewise linear edges and inclusive plateau |
| Gaussian | Gaussian(mean, sigma) | Smooth curve; sigma > 0 |
| Ramp | Ramp(start, end) | Saturates at 0 at start and 1 at end; descending if start > end |
| Sigmoid | Sigmoid(midpoint, slope) | Stable logistic; positive slope rises, negative falls |
| Bell | Bell(center, width, slope) | Generalized bell; width and slope positive |
| SShape | SShape(a, b) | Smooth quadratic rise from 0 to 1 |
| ZShape | ZShape(a, b) | Smooth quadratic fall from 1 to 0 |
| PiShape | PiShape(a, b, c, d) | S rise, inclusive plateau, Z fall; a < b <= c < d |
| Rectangle | Rectangle(a, b) | 1 on the closed interval, 0 outside |
| DiscreteSet | DiscreteSet(points) | Linear interpolation through ordered MembershipPoint objects; 0 outside support |

All constructors and degree evaluations reject nonfinite arguments. Ramp and smooth
edges require finite nonzero spans. New edge/rectangle classes reject zero width;
use shoulders in Triangle/Trapezoid when repeated endpoints are intentional.
`Sigmoid` rejects slope zero. `Bell` is 1 at its center and 0.5 at distance width.
It uses logarithmic evaluation to avoid intermediate-power overflow. Gaussian and
sigmoid normalized differences also handle opposite extreme finite values without
first overflowing their subtraction.

Ramp, SShape and ZShape have **saturating tails**. Triangle, Trapezoid, PiShape,
Rectangle and DiscreteSet have finite support and return zero outside it. Sigmoid,
Gaussian and Bell have infinite support mathematically; floating-point evaluation
can saturate to zero or one for extreme arguments. Output integration always stays
inside the declared variable universe.

DiscreteSet copies its list. Points must be strictly increasing, without duplicates;
at least two points and a finite total span are required. Each MembershipPoint
has a finite x and a finite degree in the closed interval from zero to one.
Endpoint values are preserved, even if nonzero, so a discontinuity at support
boundaries is possible. Interior evaluation uses binary search and interpolation,
not nearest-neighbor lookup. The class does not represent fuzzy arithmetic values.

```dart
final hot = Sigmoid(25, .25);
final dry = ZShape(30, 70);
final measured = DiscreteSet([
  MembershipPoint(0, 0),
  MembershipPoint(20, .4),
  MembershipPoint(50, 1),
  MembershipPoint(100, 0),
]);

final condition = const Term('soilMoisture', 'dry')
    .and(const Term('airTemperature', 'hot').hedge(const Somewhat()));
```

## Linguistic modifiers

`Very` applies d² (concentration); `Somewhat` applies sqrt(d) (dilation).
Use `Condition.hedge(FuzzyHedge)` on a term or a complete compound condition.
Hedges run before rule weights. They retain term references for model validation
and propagate selected antecedent operators. Custom hedges must return finite
degrees between zero and one; invalid output throws StateError. Direct calls to
built-in transform methods assume valid degrees.

Order is explicit: `term.hedge(const Very()).not()` means 1 − d², whereas
`term.not().hedge(const Very())` means (1 − d)². Chaining applies left to right.
Hedges do not change the membership functions used by consequent output sets.

## Five defuzzifiers

| Strategy | Decision | Sampling semantics |
| --- | --- | --- |
| Centroid | Center of area | Composite trapezoidal integral of x × degree divided by degree |
| Bisector | Equal-area split | Solves for half the area under the piecewise linear sampled curve |
| SmallestOfMaximum | First maximum | First qualifying grid coordinate |
| LargestOfMaximum | Last maximum | Last qualifying grid coordinate |
| MeanOfMaximum | Mean of maxima | Arithmetic mean of all qualifying grid coordinates |

Centroid remains the default. Select another with `defuzzifier: const Bisector()`
or `defuzzifier: MeanOfMaximum(tolerance: 1e-6)`. All methods return null on zero
sampled area, including standalone defuzzifier calls.

Bisector uses exact integration of the linear segments between samples, rescales
degrees for numerical stability and solves the crossing segment analytically.
If half the area is reached at the start of a zero plateau, the leftmost such
coordinate is selected. This is a choice among equally valid equal-area splits.
It does not integrate an underlying unsampled nonlinear function exactly.

The maxima methods use `tolerance: 0` by default (exact equality to the highest
sampled degree). Tolerance is absolute in membership units, finite and in [0,1].
A point qualifies if maximum − degree <= tolerance. A large tolerance can include
zero-degree samples when the maximum is small; it is opt-in, not a hidden default.
MeanOfMaximum averages all qualifying coordinates, including disconnected maxima;
it is not generally the midpoint of the first and last. Maxima methods do not
interpolate unsampled peaks. Grid resolution can change their decisions.

## Executable example

```sh
dart run example/toolbox_example.dart
```

This two-input educational irrigation model combines smooth soil-moisture sets,
a temperature sigmoid and a linguistic modifier. At soilMoisture=35 and
airTemperature=32, the default 1000-interval grid yields:

| Method | Watering intensity |
| --- | ---: |
| Centroid | 79.51% |
| Bisector | 83.10% |
| SmallestOfMaximum | 88.30% |
| LargestOfMaximum | 100.00% |
| MeanOfMaximum | 94.15% |

The same fuzzy output can lead to different crisp decisions. Choose a method
based on the domain, not the most attractive numeric result. Values are abstract
intensity percentages, not calibrated irrigation durations or actuator commands.
Benchmarks: [performance notes](performance.md).
