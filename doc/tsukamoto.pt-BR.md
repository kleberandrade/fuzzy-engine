# Tsukamoto e o atalho Larsen

[English](tsukamoto.en.md) · [Diagramas](architecture.pt-BR.md)

## Inferência Tsukamoto

Cada regra converte sua ativação ponderada em uma saída crisp, invertendo uma
função de pertinência monotônica. O motor calcula a média ponderada normalizada
desses valores. Diferentemente de Mamdani, não agrega uma curva amostrada de saída
nem aplica defuzzificador integral; diferentemente de Sugeno, obtém a conclusão
a partir da ativação, não de uma constante ou equação das entradas crisp.

Se a_i é a condição completa e q_i o peso:
w_i = a_i × q_i, z_i = inversa_i(w_i), y = sum(w_i × z_i) / sum(w_i).
Neste pacote o peso é aplicado **antes da inversão e novamente como peso da média**.
Compare a convenção de pesos antes de afirmar equivalência com outra biblioteca.
TsukamotoEngine não oferece soma sem normalização.

```dart
final engine = TsukamotoEngine(
  inputs: [
    FuzzyVariable(name: 'demand', min: 0, max: 1, terms: {
      'low': Ramp(1, 0),
      'high': Ramp(0, 1),
    }),
  ],
  outputs: [
    TsukamotoOutput(name: 'power', min: 0, max: 100, terms: {
      'low': Ramp(100, 0),
      'high': Ramp(0, 100),
    }),
  ],
  rules: [
    TsukamotoRule(name: 'low', when: const Term('demand', 'low'),
      output: 'power', term: 'low'),
    TsukamotoRule(name: 'high', when: const Term('demand', 'high'),
      output: 'power', term: 'high', weight: .5),
  ],
);
final result = engine.evaluate({'demand': .25});
print(result.value('power')); // Approximately 23.2142857143
```

Em demand=0,25, as ativações são 0,75 e 0,125. A rampa decrescente inverte 0,75 em
25; a crescente inverte 0,125 em 12,5. A média é
(0,75 × 25 + 0,125 × 12,5) / 0,875 = 325/14 ≈ 23,214286.
Com os dois pesos iguais a um, essas rampas produzem 100 × demand. São percentuais
didáticos, não comandos de atuadores calibrados.

## Termos invertíveis

MonotonicMembershipFunction estende MembershipFunction com domainMin, domainMax,
isIncreasing e inverse(degree). Implementações incluídas:

| Função | Direção | Inversa generalizada |
| --- | --- | --- |
| Ramp(start,end) | Crescente ou decrescente | start + (end−start) × grau |
| SShape(a,b) | Crescente | a + (b−a) × sqrt(grau/2) para grau <= 0,5; ramo superior espelhado |
| ZShape(a,b) | Decrescente | SShape(a,b).inverse(1−grau) |

O domínio finito da transição, não as caudas saturadas, define os extremos.
Ramp.inverse(0) retorna start e inverse(1) retorna end. S/Z usam os extremos de
suas transições. As inversas incluídas rejeitam graus não finitos ou fora de zero
até um. O cálculo direto de pertinência dessas classes permanece igual.

A inversa matemática da sigmoide tem extremos infinitos em zero/um, por isso
Sigmoid não é aceita silenciosamente como saída finita Tsukamoto. Triângulos,
sinos e outras funções não monotônicas também não servem como conclusões desse
motor. Todas as funções existentes continuam disponíveis nas entradas.

TsukamotoOutput declara universo finito e mapa imutável de termos monotônicos.
O domínio de cada transição deve ter amplitude finita positiva e estar dentro
desse universo, podendo ocupar somente parte dele. A decisão ponderada fica no
intervalo das inversas ativas e no universo de saída. Sem regra de ativação
positiva, a saída é null. Regras inativas têm inverseValue/weightedContribution
null. Há suporte a múltiplas saídas, operadores, modificadores e validação estrita
das entradas.

## Validação e extensões próprias

O construtor verifica, em uma grade finita, monotonicidade direta/inversa,
cobertura dos extremos e consistência entre inversa e pertinência. Padrões:
validationSamples=33 (de 2 a 1001), inverseTolerance=1e-9 (erro absoluto de grau,
permitido de 0 a 0,001). Tolerância zero exige igualdade exata em ponto flutuante
e pode rejeitar inversas numéricas razoáveis.

Cada inversão ativa também é verificada em execução: precisa ser finita, estar
no domínio de transição e satisfazer abs(pertinência(inversa(w))−w) <= tolerância.
Falha em execução lança StateError; os diagnósticos registram a avaliação como
falha. Configurações inválidas detectadas na construção são rejeitadas.

As inversas incluídas são analíticas. Uma grade finita **não prova** monotonicidade
global de funções arbitrárias. Implementações próprias devem ser imutáveis,
determinísticas e respeitar o contrato. Todos os termos são verificados na
construção, mesmo sem regra ativa apontando para eles. Durante a inferência,
inversas inativas não são chamadas. Há os limites normais de precisão double:
ativações ponderadas muito pequenas podem virar zero antes da inversão. A média
usa a mesma aritmética estável do [Sugeno](sugeno.pt-BR.md).

## Explicações, JSON e diagnóstico

TsukamotoResult expõe outputs, memberships, rules e totalWeights imutáveis.
Cada TsukamotoActivation registra regra, condição, ativação e inverseValue;
weightedContribution é o produto bruto w × z, não uma parcela já normalizada.

```dart
final codec = FuzzyModelCodec(); // Exporta v2 por padrão.
final source = codec.encode(engine);
final restored = codec.decodeTsukamoto(source);
final report = const FuzzyDiagnostics().analyze(restored, samplesPerInput: 5);
```

O esquema v2 suporta saídas Ramp/SShape/ZShape incluídas, opções de validação,
metadados e os recursos compartilhados das condições. Funções monotônicas próprias
são extensões de execução e não são serializadas. A importação v1 de Mamdani/Sugeno
continua disponível; use FuzzyModelCodec(exportVersion: 1) para exportar ao formato
antigo. Tsukamoto não pode ser exportado como v1. Esquemas:
[v1](model-v1.schema.json), [v2](model-v2.schema.json).
A [fixture Tsukamoto v2](../test/fixtures/tsukamoto-v2.json) verifica um resultado
calculado à mão, além dos testes de ida e volta do codec.

## Construtor Larsen

```dart
final larsen = FuzzyEngine.larsen(
  inputs: inputs,
  outputs: outputs,
  rules: rules,
);
```

O atalho seleciona implicação AlgebraicProduct. Os padrões de operadores das
condições, agregação máximo, centroide e 1000 intervalos são mantidos, podendo
ser configurados. É o pipeline existente com escala produto em vez de recorte
mínimo. O JSON usa engineType=mamdani e implication=algebraicProduct, sem criar
outra família de esquema. FuzzyEngine continua com implicação mínimo por padrão.

## Exemplo executável

```sh
dart run example/tsukamoto_example.dart
dart run benchmark/tsukamoto_benchmark.dart 1000
```

Importação/exportação FCL/FIS **não está implementada**. O [perfil de interoperabilidade](interoperability.pt-BR.md)
define o trabalho restante, inclusive decisões sem regras e referências independentes
antes de prometer compatibilidade.

Referência conceitual: [artigo técnico FuzzyLite](https://fuzzylite.com/downloads/FuzzyLite-Libraries.pdf).
