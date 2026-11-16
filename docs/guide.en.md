# From measurements to decisions

The pipeline below describes the default operators. See [configurable strategies](strategies.en.md) for alternatives.

## The inference pipeline

1. Define each universe: a finite interval with meaningful units.
2. Define overlapping linguistic sets: cold, warm, hot.
3. Fuzzify each crisp measurement by evaluating membership functions.
4. Evaluate antecedents: AND = min(a,b), OR = max(a,b), NOT = 1-a.
5. Multiply each antecedent by its rule weight in [0,1].
6. Clip each consequent at its weighted activation: min(strength, membership).
7. Aggregate consequents per output with max, not sum.
8. Compute centroid: integral(x * aggregated(x)) / integral(aggregated(x)).

The implementation integrates on normalized output coordinates using composite
trapezoidal quadrature, then maps the centroid to the original universe.
`intervals` is the number of integration segments. A zero denominator yields null.

## Membership shapes

| Shape | Parameters | Typical use |
| --- | --- | --- |
| Triangle | left, peak, right | Simple overlapping linguistic terms |
| Trapezoid | left, plateau start, plateau end, right | Fully true across a band |
| Gaussian | mean, positive sigma | Smooth transitions with infinite support |

Triangle(0,0,25) is a left shoulder on [0,25]. Its value at zero is 1.
Trapezoid(0,0,10,10) is a rectangle with inclusive endpoints. Gaussian values
outside the output universe are truncated during defuzzification.
Custom functions implement `MembershipFunction`; keep them deterministic and
immutable because the engine retains function references.

## Interpreting results

For the README model at 32°C, warm=0.72 and hot=0.28. The medium consequent
is clipped to 0.72, the high consequent to 0.28, and their maximum is integrated.
A 0.72 degree does not mean a 72% chance. Rule activations explain conditions,
but do not represent additive shares of the final output because aggregation
uses max. Results expose input memberships and all weighted rule activations.

## Modeling practice

Start with a small rule base. Cover the full input space, including boundaries,
and examine null outputs, contradictory rules and abrupt transitions. Compare
outputs against known scenarios and validate intermediate states. Keep units
consistent. Tune sets against actual domain behavior before connecting actuators.
Outputs need not reach their interval extrema: a fully activated shoulder's
centroid lies inside the shoulder, not at the endpoint. Increasing rule weight
can affect both area and centroid; it is not a multiplier on the crisp output.

The educational models intentionally use one input each. Add humidity to climate,
temperature to irrigation, or recent errors to game difficulty using another
input variable and composed conditions. Sugeno is available through the separate [SugenoEngine](sugeno.en.md).
Serialization and automatic rule learning remain outside the current scope.

[Full toolbox reference](toolbox.en.md): eleven membership functions, linguistic modifiers and five defuzzifiers.
