# Estratégias de inferência configuráveis

[English](strategies.en.md) · [Arquitetura](architecture.pt-BR.md)

## Padrões e compatibilidade

As chamadas existentes de `FuzzyEngine` e `Condition.evaluate(values)` mantêm os
padrões: AND mínimo, OR máximo, complemento padrão, implicação mínimo, agregação
máximo e centroide. O peso da regra continua multiplicando o grau da condição
completa, depois de AND/OR/NOT. O argumento `operators` de `Condition.evaluate`
é nomeado e opcional.

```dart
final engine = FuzzyEngine(
  inputs: inputs,
  outputs: outputs,
  rules: rules,
  operators: const FuzzyOperators(
    conjunction: AlgebraicProduct(),
    disjunction: ProbabilisticSum(),
  ),
  implication: const AlgebraicProduct(),
  aggregation: const ProbabilisticSum(),
  defuzzifier: const Centroid(),
  intervals: 1000,
);
```

`inputs`, `outputs` e `rules` são listas de configuração já definidas pelo modelo.
Execute `dart run example/strategies_example.dart` para um exemplo completo de
AND produto, implicação produto, agregação probabilística, inspeção de curvas e
um seletor de máximos implementado pela aplicação.

## Estratégias disponíveis

| Configuração | Interface | Padrão | Outras implementações incluídas |
| --- | --- | --- | --- |
| operators.conjunction | TNorm | Minimum | AlgebraicProduct, BoundedDifference |
| operators.disjunction | SNorm | Maximum | ProbabilisticSum, BoundedSum |
| operators.negation | FuzzyNegation | StandardNegation | Implementações próprias |
| implication | TNorm | Minimum | AlgebraicProduct, BoundedDifference |
| aggregation | SNorm | Maximum | ProbabilisticSum, BoundedSum |
| defuzzifier | Defuzzifier | Centroid | Implementações próprias |

A implicação produto escala a função de saída em vez de recortá-la, no estilo
Larsen. Isso não cria conclusões Sugeno. As escolhas são globais no motor, ainda
não configuráveis por saída ou bloco de regras. Operadores das condições e
implicação são independentes: escolher AND produto não altera a implicação.

## Referência das fórmulas

| Estratégia | Fórmula |
| --- | --- |
| Minimum | min(a, b) |
| AlgebraicProduct | a × b |
| BoundedDifference | max(0, a + b − 1) |
| Maximum | max(a, b) |
| ProbabilisticSum | a + b − a × b |
| BoundedSum | min(1, a + b) |
| StandardNegation | 1 − a |

A soma probabilística usa a expressão equivalente `a + (1 - a) * b` para reduzir
erros de arredondamento nos extremos. O nome não transforma graus em probabilidades.
Quem implementa classes próprias deve respeitar as leis das t-normas/s-normas,
como elementos neutros, monotonicidade, comutatividade e associatividade; a validação
de intervalo em execução não prova essas propriedades. Use estratégias imutáveis
e determinísticas.

## Contrato de defuzzificação e curvas de saída

Implemente `Defuzzifier.defuzzify(SampledFuzzySet output)`. As amostras são
uniformemente espaçadas e incluem os dois extremos. `degrees` é imutável,
`intervals` é a quantidade de amostras menos um e `xAt(i)` retorna a coordenada.

Retorne null somente para área amostrada zero; para área positiva, retorne um
valor finito no universo. O motor retorna null para área zero sem chamar a
estratégia, evitando uma alternativa implícita. Com área positiva, null, NaN,
infinito e valores fora do universo lançam `StateError`. Operadores e funções de
pertinência que produzam graus inválidos também lançam `StateError`. Construir
um `SampledFuzzySet` inválido lança `ArgumentError`. Chamadas diretas aos operadores
incluídos pressupõem argumentos válidos entre zero e um.

`result.outputSets['fan']` permite inspecionar as amostras agregadas usadas no
cálculo. Não são parcelas aditivas por regra. A grade pode não detectar conjuntos
mais estreitos que seu passo: área amostrada zero continua produzindo null.
`Centroid` mantém a integração trapezoidal composta utilizada anteriormente.
`RightmostMaximum`, no exemplo, escolhe o último máximo por igualdade exata das
amostras; não é um novo defuzzificador incluído no núcleo nem interpola o pico.

Guardar as curvas custa O(saídas × intervalos) de memória. O motor continua
síncrono. Veja as [medições de desempenho](performance.md) antes de escolher
resoluções para modelos grandes ou avaliações a cada quadro da interface.
