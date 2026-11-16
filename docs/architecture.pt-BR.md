# Diagramas de classes e arquitetura

[English](architecture.en.md) · [Escopo e evolução](roadmap.pt-BR.md)

Os diagramas representam o código implementado, não recursos planejados. Estão
separados entre modelo do motor, funções de pertinência e expressões das regras.
O GitHub renderiza estes blocos Mermaid. Leitores Markdown sem esse suporte podem
exibir o código; a documentação da interface pública é gerada com `dart doc`.

## Motor, configuração e resultados

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

`FuzzyEngine` copia as listas da configuração e valida as referências na construção.
Entradas e saídas usam `FuzzyVariable`, em espaços de nomes separados.
As conclusões das regras referenciam variáveis e termos de saída pelo nome.
`FuzzyResult.value()` retorna **double?**: null significa área agregada zero. O
diagrama omite a nulabilidade para compatibilidade de renderização. Os mapas e
listas do resultado são imutáveis. `RuleActivation` referencia a regra e registra
os graus antes/depois do peso; não representa uma parcela aditiva do centroide.

## Funções de pertinência

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

`FuzzyVariable.terms` associa nomes linguísticos a funções `MembershipFunction`.
As funções são referenciadas, sem cópia profunda. Implementações personalizadas
devem ser imutáveis, determinísticas e retornar graus finitos entre zero e um.

## Condições e composição

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

`Term` é público. `_Binary` e `_Not` são classes privadas retornadas por `and`, `or`
e `not`; o usuário não as instancia diretamente. `references` reúne referências
aos termos de entrada para validação antecipada. Os operadores padrão são
AND mínimo, OR máximo e NOT complemento; a configuração FuzzyOperators é propagada
por todas as expressões compostas. `Condition` é sealed; ainda não permite
implementar novas condições fora desta biblioteca.

## Estratégias de inferência

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

Implemente `MembershipFunction`, `TNorm`, `SNorm`, `FuzzyNegation` ou `Defuzzifier`
para personalizar o pipeline. As estratégias são globais no `FuzzyEngine`.
`FuzzyResult.outputSets` expõe as curvas agregadas imutáveis. `Defuzzifier` retorna
**double?**; a nulabilidade foi omitida no diagrama para compatibilidade.
Veja os [contratos e exemplos](strategies.pt-BR.md). Sugeno agora tem modelo
próprio de consequente e motor, documentados abaixo.

Código: [motor](../lib/src/engine.dart), [modelo](../lib/src/model.dart),
[pertinência](../lib/src/membership.dart), [operadores](../lib/src/operators.dart),
[defuzzificação](../lib/src/defuzzification.dart).

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

_MaximumDefuzzifier é uma base privada omitida na visão geral; os três métodos de máximos implementam Defuzzifier por ela. _Hedged é privada e criada por Condition.hedge. Veja os [contratos](toolbox.pt-BR.md).

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

SugenoAggregation seleciona weightedAverage ou weightedSum. Os diagramas omitem nulabilidade: valores de saída e conclusões/contribuições inativas podem ser null. Os motores compartilham validação e fuzzificação das entradas internamente, mantendo modelos próprios de conclusão e redução. [Comportamento Sugeno](sugeno.pt-BR.md).
