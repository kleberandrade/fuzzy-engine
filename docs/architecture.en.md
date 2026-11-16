# Class diagrams and architecture

[Português](architecture.pt-BR.md) · [Scope and roadmap](roadmap.en.md)

These diagrams describe the implemented code, not planned features. They are
split into the engine model, membership functions and antecedent expressions.
GitHub renders these Mermaid blocks. A Markdown viewer without Mermaid support
may show source; API reference documentation is available through `dart doc`.

## Engine, configuration and results

```mermaid
classDiagram
    direction TB
    class FuzzyEngine {
        +List~FuzzyVariable~ inputs
        +List~FuzzyVariable~ outputs
        +List~FuzzyRule~ rules
        +int intervals
        +evaluate(values) FuzzyResult
    }
    class FuzzyVariable {
        +String name
        +double min
        +double max
        +Map terms
    }
    class FuzzyRule {
        +String name
        +Condition when
        +String output
        +String term
        +double weight
    }
    class FuzzyResult {
        +Map outputs
        +Map memberships
        +List~RuleActivation~ rules
        +value(name) double
    }
    class RuleActivation {
        +FuzzyRule rule
        +double antecedent
        +double strength
    }
    FuzzyEngine "1" o-- "1..*" FuzzyVariable : inputs and outputs
    FuzzyEngine "1" o-- "1..*" FuzzyRule : configuration
    FuzzyEngine ..> FuzzyResult : creates
    FuzzyResult "1" *-- "1..*" RuleActivation : diagnostics
    RuleActivation --> FuzzyRule : references
```

`FuzzyEngine` copies configuration lists and validates references at construction.
Variables use the same class for inputs and outputs, but have separate namespaces.
Rule consequents reference output variables and terms by name, not object pointers.
`FuzzyResult.value()` returns **double?**: null means zero aggregated area. The
diagram omits nullability for renderer portability. Result maps/lists are immutable.
`RuleActivation` stores a reference to its rule and weighted/unweighted degrees;
it does not represent an additive share of the final centroid.

## Membership functions

```mermaid
classDiagram
    direction TB
    class MembershipFunction {
        <<interface>>
        +degree(x) double
    }
    class Triangle {
        +double a
        +double b
        +double c
    }
    class Trapezoid {
        +double a
        +double b
        +double c
        +double d
    }
    class Gaussian {
        +double mean
        +double sigma
    }
    class FuzzyVariable
    MembershipFunction <|.. Triangle
    MembershipFunction <|.. Trapezoid
    MembershipFunction <|.. Gaussian
    FuzzyVariable "1" o-- "1..*" MembershipFunction : named terms
```

`FuzzyVariable.terms` maps linguistic names to `MembershipFunction` instances.
These functions are referenced, not deeply copied. Custom implementations should
be immutable, deterministic and return finite degrees between zero and one.

## Conditions and composition

```mermaid
classDiagram
    direction TB
    class Condition {
        <<sealed>>
        +evaluate(values) double
        +references Iterable
        +and(other) Condition
        +or(other) Condition
        +not() Condition
    }
    class Term {
        +String variable
        +String term
    }
    class _Binary {
        +Condition left
        +Condition right
        +bool isAnd
    }
    class _Not {
        +Condition child
    }
    class FuzzyRule
    Condition <|-- Term
    Condition <|-- _Binary
    Condition <|-- _Not
    FuzzyRule --> Condition : when
    _Binary --> Condition : left and right
    _Not --> Condition : child
```

`Term` is public. `_Binary` and `_Not` are private implementation classes returned
by `and`, `or` and `not`; callers never instantiate them directly. `references`
collects input term references for eager validation. The built-in operations are
fixed: min AND, max OR, complement NOT. `Condition` is sealed; implementing a new
condition outside this library is not currently supported.

## Extension boundaries

Implementing `MembershipFunction` is the current custom extension point.
Inference, implication, aggregation and defuzzification strategies are hardcoded
in `FuzzyEngine`; there is no public strategy interface yet. Adding Sugeno should
introduce a distinct consequent model rather than treating crisp functions as
Mamdani membership sets. See the roadmap for the proposed sequencing.

Source: [engine](../lib/src/engine.dart), [model](../lib/src/model.dart),
[membership](../lib/src/membership.dart).
