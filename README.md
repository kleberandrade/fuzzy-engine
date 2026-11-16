# fuzzy_engine

An explainable, dependency-free Mamdani fuzzy logic engine for Dart and Flutter.

[Português](README.pt-BR.md) · [Concepts and design](docs/guide.en.md) · [Flutter demo](example/README.md)

**Development version:** not yet published. The package name is provisional;
registry availability has not been confirmed. Use a local path today.

## What is fuzzy logic?

Instead of deciding only true/false, describe how much a value belongs to a
linguistic set. At 32°C, temperature can be warm to degree 0.72 and hot to degree
0.28. Rules combine these degrees to produce a gradual decision. Degrees are
not probabilities. This is not fuzzy text search, machine learning or an HTTP API.

Use it for interpretable controllers, irrigation, game difficulty and heuristic
scoring where overlapping human concepts matter. Prefer ordinary conditions for
simple exact boundaries. Rules and ranges require domain calibration.

## Install locally

```yaml
dependencies:
  fuzzy_engine:
    path: ../fuzzy_engine
```

Dart >=3.3.0. No Flutter dependency in the core. Once released, use
`dart pub add fuzzy_engine` (or `flutter pub add fuzzy_engine`).

## Complete example

```dart
import 'package:fuzzy_engine/fuzzy_engine.dart';

void main() {
  final engine = FuzzyEngine(
    inputs: [
      FuzzyVariable(name: 'temperature', min: 0, max: 50, terms: {
        'cold': Triangle(0, 0, 25),
        'warm': Triangle(0, 25, 50),
        'hot': Triangle(25, 50, 50),
      }),
    ],
    outputs: [
      FuzzyVariable(name: 'fanSpeed', min: 0, max: 100, terms: {
        'low': Triangle(0, 0, 50),
        'medium': Triangle(0, 50, 100),
        'high': Triangle(50, 100, 100),
      }),
    ],
    rules: [
      FuzzyRule(name: 'cold → low', when: const Term('temperature', 'cold'),
        output: 'fanSpeed', term: 'low'),
      FuzzyRule(name: 'warm → medium', when: const Term('temperature', 'warm'),
        output: 'fanSpeed', term: 'medium'),
      FuzzyRule(name: 'hot → high', when: const Term('temperature', 'hot'),
        output: 'fanSpeed', term: 'high'),
    ],
  );
  final result = engine.evaluate({'temperature': 32});
  print(result.value('fanSpeed')); // Approximately 51.85
  print(result.memberships);      // cold: 0, warm: 0.72, hot: 0.28
  for (final activation in result.rules) {
    print('${activation.rule.name}: ${activation.strength}');
  }
}
```

## Features

- Triangle, trapezoid and Gaussian functions, plus custom membership functions.
- Composable min AND, max OR and complement NOT.
- Weighted rules, min implication, max aggregation, numerical centroid.
- Multiple inputs and outputs; immutable result maps and rule diagnostics.
- Eager validation of names, ranges, references and weights.

```dart
final condition = const Term('temperature', 'hot')
    .and(const Term('humidity', 'high'))
    .or(const Term('temperature', 'cold').not());
```

Both input variables and terms must exist in the engine configuration.
Set `weight: 0.8` on a rule to multiply its antecedent activation by 0.8.

## Behavior and limitations

Inputs must exactly match declared names, be finite and be inside their ranges;
invalid input throws `ArgumentError`. No implicit clamping occurs. Unknown output
names also throw. A declared output with zero aggregated area returns `null`:
choose an application-specific fallback explicitly. Custom functions returning
nonfinite values or degrees outside the interval 0–1 throw `StateError` when sampled.

`intervals: 1000` uses 1001 samples with trapezoidal integration. More intervals
increase cost and usually improve accuracy; narrow sets may need finer sampling.
Output functions are restricted to their declared output universe. Endpoint
shoulders are inclusive; outside support triangles/trapezoids return zero.
The engine is synchronous. Cost is approximately O(inputs × terms + rules +
outputs × intervals × relevant rules); large models should be benchmarked and
may need an isolate in UI applications. No learning or automatic tuning occurs.

## Examples and development

The Flutter lab provides sliders, membership curves and rule activations for
climate control, irrigation and adaptive game difficulty. It supports English and
Portuguese. See [running instructions](example/README.md).

```sh
dart pub get
dart analyze --fatal-infos
dart test
dart run example/quick_start.dart
dart doc
dart pub publish --dry-run
```

Read the [release checklist](docs/PUBLISHING.md) before publishing. MIT licensed.
