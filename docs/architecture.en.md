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
        +FuzzyOperators operators
        +TNorm implication
        +SNorm aggregation
        +Defuzzifier defuzzifier
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
        +Map outputSets
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
collects input term references for eager validation. The default operations are
min AND, max OR, complement NOT; evaluation propagates the selected FuzzyOperators
through every nested expression. `Condition` is sealed; implementing a new
condition outside this library is not currently supported.

## Inference strategies

```mermaid
classDiagram
    direction TB
    class FuzzyEngine
    class FuzzyOperators
    class TNorm {
        <<interface>>
        +combine(a, b) double
    }
    class SNorm {
        <<interface>>
        +combine(a, b) double
    }
    class FuzzyNegation {
        <<interface>>
        +complement(value) double
    }
    FuzzyEngine --> FuzzyOperators : operators
    FuzzyEngine --> TNorm : implication
    FuzzyEngine --> SNorm : aggregation
    FuzzyOperators --> TNorm : conjunction
    FuzzyOperators --> SNorm : disjunction
    FuzzyOperators --> FuzzyNegation : negation
```

```mermaid
classDiagram
    direction TB
    class FuzzyEngine
    class Defuzzifier {
        <<interface>>
        +defuzzify(output) double
    }
    class Centroid
    class SampledFuzzySet {
        +double min
        +double max
        +List degrees
        +int intervals
        +bool hasArea
        +xAt(index) double
    }
    class FuzzyResult
    Defuzzifier <|.. Centroid
    FuzzyEngine --> Defuzzifier : strategy
    Defuzzifier ..> SampledFuzzySet : reads
    FuzzyEngine ..> SampledFuzzySet : creates
    FuzzyResult o-- SampledFuzzySet : outputSets
```

Implement `MembershipFunction`, `TNorm`, `SNorm`, `FuzzyNegation` or `Defuzzifier`
to customize the pipeline. `FuzzyEngine` applies selected strategies engine-wide.
`FuzzyResult.outputSets` exposes immutable aggregated samples. `Defuzzifier` returns
**double?**; nullability is omitted in the diagram for renderer portability.
See [strategy contracts and examples](strategies.en.md). Sugeno now has a separate
consequent model and engine, documented below.

Source: [engine](../lib/src/engine.dart), [model](../lib/src/model.dart),
[membership](../lib/src/membership.dart), [operators](../lib/src/operators.dart),
[defuzzification](../lib/src/defuzzification.dart).

## Additional membership classes / Classes adicionais de pertinência

```mermaid
classDiagram
    direction TB
    class MembershipFunction
    MembershipFunction <|.. Ramp
    MembershipFunction <|.. Sigmoid
    MembershipFunction <|.. Bell
    MembershipFunction <|.. Rectangle
```

```mermaid
classDiagram
    direction TB
    class MembershipFunction
    MembershipFunction <|.. SShape
    MembershipFunction <|.. ZShape
    MembershipFunction <|.. PiShape
```

```mermaid
classDiagram
    direction TB
    class MembershipFunction
    class DiscreteSet
    class MembershipPoint {
        +double x
        +double membership
    }
    MembershipFunction <|.. DiscreteSet
    DiscreteSet "1" o-- "2..*" MembershipPoint : points
```

## Defuzzifier implementations / Implementações de defuzzificação

```mermaid
classDiagram
    direction TB
    class Defuzzifier
    Defuzzifier <|.. Centroid
    Defuzzifier <|.. Bisector
    Defuzzifier <|.. SmallestOfMaximum
```

```mermaid
classDiagram
    direction TB
    class Defuzzifier
    Defuzzifier <|.. LargestOfMaximum
    Defuzzifier <|.. MeanOfMaximum
```

## Linguistic modifiers / Modificadores linguísticos

```mermaid
classDiagram
    direction TB
    class Condition
    class _Hedged
    class FuzzyHedge {
        <<interface>>
        +transform(degree) double
    }
    class Very
    class Somewhat
    Condition <|-- _Hedged
    _Hedged --> FuzzyHedge : modifier
    FuzzyHedge <|.. Very
    FuzzyHedge <|.. Somewhat
```

_MaximumDefuzzifier is a private implementation base, omitted from the overview; the three maxima strategies implement Defuzzifier through it. _Hedged is private and created by Condition.hedge. See [behavior contracts](toolbox.en.md).

## Sugeno

```mermaid
classDiagram
    direction TB
    class SugenoEngine
    class FuzzyVariable
    class SugenoOutput {
        +String name
    }
    class SugenoRule
    class FuzzyOperators
    SugenoEngine "1" o-- "1..*" FuzzyVariable : inputs
    SugenoEngine "1" o-- "1..*" SugenoOutput : outputs
    SugenoEngine "1" o-- "1..*" SugenoRule : rules
    SugenoEngine --> FuzzyOperators : operators
```

```mermaid
classDiagram
    direction TB
    class SugenoRule
    class Condition
    class SugenoConsequent {
        <<interface>>
        +references Iterable
        +evaluate(inputs) double
    }
    class ConstantConsequent {
        +double value
    }
    class LinearConsequent {
        +double intercept
        +Map coefficients
    }
    SugenoRule --> Condition : when
    SugenoRule --> SugenoConsequent : consequent
    SugenoConsequent <|.. ConstantConsequent
    SugenoConsequent <|.. LinearConsequent
```

```mermaid
classDiagram
    direction TB
    class SugenoEngine {
        +SugenoAggregation aggregation
        +evaluate(values) SugenoResult
    }
    class SugenoResult {
        +Map outputs
        +Map memberships
        +Map totalWeights
        +List rules
        +value(name) double
    }
    class SugenoActivation {
        +double antecedent
        +double strength
        +double consequentValue
        +double weightedContribution
    }
    class SugenoRule
    SugenoEngine ..> SugenoResult : creates
    SugenoResult "1" *-- "1..*" SugenoActivation : diagnostics
    SugenoActivation --> SugenoRule : rule
```

SugenoAggregation selects weightedAverage or weightedSum. Diagram return types omit nullability: result values, inactive consequent values and contributions are nullable. The engines share input validation/fuzzification internally, without sharing their consequent or reduction models. [Sugeno behavior](sugeno.en.md).

## Model interchange and diagnostics / Intercâmbio e diagnóstico

```mermaid
classDiagram
    direction TB
    class FuzzyModelCodec {
        +encode(model) String
        +decode(source) FuzzyModelDocument
        +decodeMamdani(source) FuzzyEngine
        +decodeSugeno(source) SugenoEngine
    }
    class FuzzyModelDocument {
        +Object engine
        +Map inputUnits
        +Map outputUnits
    }
    class FuzzyEngine
    class SugenoEngine
    FuzzyModelCodec ..> FuzzyModelDocument : imports and exports
    FuzzyModelDocument --> FuzzyEngine : one engine family
    FuzzyModelDocument --> SugenoEngine : one engine family
```

```mermaid
classDiagram
    direction TB
    class Condition
    class ConditionVisitor {
        <<interface>>
        +visitTerm(term)
        +visitAnd(left, right)
        +visitOr(left, right)
        +visitNot(child)
        +visitHedge(child, modifier)
    }
    class FuzzyModelCodec
    Condition ..> ConditionVisitor : accept
    FuzzyModelCodec ..> ConditionVisitor : typed tree inspection
```

```mermaid
classDiagram
    direction TB
    class FuzzyDiagnostics {
        +analyze(model) FuzzyDiagnosticReport
    }
    class FuzzyDiagnosticReport {
        +int evaluations
        +int failedEvaluations
        +Map ruleActivationCounts
        +Map nullOutputCounts
        +toJson() Map
    }
    class DiagnosticIssue {
        +DiagnosticCode code
        +DiagnosticSeverity severity
        +List rules
    }
    FuzzyDiagnostics ..> FuzzyDiagnosticReport : creates
    FuzzyDiagnosticReport "1" *-- "0..*" DiagnosticIssue : issues
```

[Model interchange and sampling contracts](model-tools.en.md). ConditionVisitor adds typed inspection without exposing private condition-node implementations.
