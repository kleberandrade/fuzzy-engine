# Inferência Takagi–Sugeno

[English](sugeno.en.md) · [Diagramas de classes](architecture.pt-BR.md)

## Comparando Mamdani e Sugeno

| Aspecto | FuzzyEngine (padrões Mamdani) | SugenoEngine |
| --- | --- | --- |
| Entradas | FuzzyVariable | A mesma FuzzyVariable |
| Condições | Termos, AND/OR/NOT e modificadores | As mesmas condições e operadores configuráveis |
| Conclusões | Conjuntos linguísticos de saída | Constantes ou equações lineares crisp |
| Modelo de saída | FuzzyVariable com universo e termos | SugenoOutput somente com nome |
| Decisão | Implicação, agregação e defuzzificação amostradas | Média ponderada ou soma ponderada explícita |
| Diagnóstico | Pertinências, ativações e curvas | Pertinências, ativações, conclusões crisp, contribuições brutas e pesos totais |

Use Mamdani quando conjuntos linguísticos de saída forem úteis; Sugeno quando
as regras precisarem selecionar ou combinar equações numéricas. O pacote não
aprende regras nem ajusta coeficientes automaticamente. Ambos são tipo 1 e usam
aritmética double determinística. São interfaces separadas: não há motor híbrido
misturando as duas famílias de saída na mesma instância.

## Modelo completo

Importe `package:fuzzy_engine/fuzzy_engine.dart` e use o código dentro de main:

```dart
final inputs = [
  FuzzyVariable(name: 'temperature', min: 0, max: 40, terms: {
    'cold': Ramp(40, 0),
    'hot': Ramp(0, 40),
  }),
];
final engine = SugenoEngine(
  inputs: inputs,
  outputs: [SugenoOutput('fan')],
  aggregation: SugenoAggregation.weightedAverage,
  rules: [
    SugenoRule(
      name: 'cold',
      when: const Term('temperature', 'cold'),
      output: 'fan',
      consequent: ConstantConsequent(20),
    ),
    SugenoRule(
      name: 'hot',
      when: const Term('temperature', 'hot'),
      output: 'fan',
      weight: .5,
      consequent: LinearConsequent(
        intercept: 20,
        coefficients: {'temperature': 2},
      ),
    ),
  ],
);
final result = engine.evaluate({'temperature': 10});
print(result.value('fan')); // Approximately 22.8571428571
```

O exemplo mistura uma conclusão constante e uma linear, o que é permitido.
Um modelo apenas com constantes é de ordem zero. As conclusões de primeira ordem
seguem `z = intercept + sum(coefficient[name] * crispInput[name])`.
Coeficientes omitidos não dependem daquela entrada. Um mapa vazio equivale ao
intercepto constante. Coeficientes negativos e resultados fora do intervalo de
graus de pertinência são válidos.

## Equações de redução

Se a_i é o grau da condição completa e q_i o peso da regra, a ativação final é
w_i = a_i × q_i. A conclusão é avaliada nas **entradas crisp originais**, produzindo
z_i. Cada saída considera somente suas regras ativas:

- `weightedAverage`: y = sum(w_i × z_i) / sum(w_i).
- `weightedSum`: y = sum(w_i × z_i), sem normalização.

A primeira é a decisão Sugeno normalizada padrão. A segunda é uma alternativa
explícita e pode exceder todos os valores individuais das conclusões. Duplicar
regras pode alterar a soma mesmo quando a média permanece igual. Não são usados
grade de integração, implicação Mamdani, conjuntos de saída nem Defuzzifier.
A opção escolhida vale para todas as regras e saídas daquele motor.

SugenoOutput não tem intervalo de saída. Não há ajuste automático ao domínio da
aplicação nem valor alternativo implícito. Uma saída sem regras de ativação positiva
retorna **null nos dois modos**, mesmo que uma soma vazia puramente algébrica fosse
zero. Uma conclusão zero com ativação positiva retorna 0. Saídas declaradas sem
regras são permitidas e permanecem null.

## Explicação e validação

Os mapas/listas outputs, memberships, rules e totalWeights de SugenoResult são
imutáveis. Cada SugenoActivation contém a regra, condição, ativação,
consequentValue e weightedContribution bruto (w × z). Conclusões inativas ou com
peso zero não são avaliadas e têm conclusão/contribuição null. As contribuições
brutas ainda não são parcelas normalizadas da média.

As entradas devem corresponder exatamente aos nomes declarados, ser finitas e
estar no universo definido. A construção rejeita modelos vazios, nomes duplicados,
termos inexistentes e referências de conclusões a entradas desconhecidas. Entradas
e saídas têm espaços de nomes separados. Parâmetros incluídos devem ser finitos;
pesos ficam entre zero e um, inclusive. Consultar saída desconhecida lança
ArgumentError. Conclusões ativas não finitas e resultados não representáveis
lançam StateError, em vez de retornar NaN ou infinito.

Implemente SugenoConsequent para uma função crisp personalizada e determinística.
Declare os nomes de entrada usados em references; o motor valida essas referências
mesmo em regras inativas. O callback recebe um mapa crisp imutável. O motor verifica
se o resultado é finito, mas não prova que a lista de referências está completa
nem impede exceções próprias do callback. Mantenha a configuração personalizada
imutável. Essa interface executa código Dart fornecido por quem programa, não
expressões textuais recebidas de configurações externas.

## Comportamento numérico

A média divide as ativações positivas pela maior delas antes da redução, evitando
perder uma média válida quando todos os pesos são muito pequenos. Os produtos são
formados antes da divisão pelo denominador escalado para não zerar prematuramente
pesos normalizados. A soma compensada reduz erros de cancelamento, com alternativa
escalada se uma soma intermediária estourar.

A média é limitada ao mínimo/máximo matemático das conclusões ativas para conter
arredondamentos extremos. Isso não é ajuste ao intervalo operacional da aplicação.
A soma ponderada não tem essa restrição; um resultado realmente não representável
lança StateError. Os produtos das equações lineares precisam ser representáveis,
mesmo se termos posteriores pudessem cancelá-los. Continua sendo aritmética de
precisão finita: diferenças extremas de escala podem perder informação. O produto
condição × peso e as contribuições brutas podem sofrer underflow; a normalização
não recupera uma ativação que já se tornou exatamente zero.

## Comparação executável

```sh
dart run example/sugeno_example.dart
```

Em temperature=10, cold=0,75 e hot=0,25. O peso da regra hot é 0,5, produzindo
ativações 0,75 e 0,125, com total 0,875.

| Conclusões | Cold z | Hot z | Média ponderada | Soma ponderada |
| --- | ---: | ---: | ---: | ---: |
| Constantes 20 e 80 | 20 | 80 | 28,5714 | 25,0000 |
| Lineares 10+t e 20+2t | 20 | 40 | 22,8571 | 20,0000 |

Os valores ilustram uma pontuação abstrata de ventilação, não comandos calibrados.
Veja os [benchmarks](performance.md): os cenários Sugeno e Mamdani não representam
controladores numericamente equivalentes nem devem ser tratados como intercambiáveis.

O terceiro motor, [Tsukamoto](tsukamoto.pt-BR.md), usa conclusões monotônicas invertidas.
