# Pertinência, modificadores e defuzzificação

[English](toolbox.en.md) · [Estratégias](strategies.pt-BR.md) · [Diagramas de classes](architecture.pt-BR.md)

## Catálogo de pertinência

| Função | Construtor | Comportamento |
| --- | --- | --- |
| Triangle | Triangle(a, b, c) | Pico linear; extremos repetidos formam ombros |
| Trapezoid | Trapezoid(a, b, c, d) | Bordas lineares e platô inclusivo |
| Gaussian | Gaussian(mean, sigma) | Curva suave; sigma > 0 |
| Ramp | Ramp(start, end) | Satura em 0 no início e 1 no fim; decrescente se start > end |
| Sigmoid | Sigmoid(midpoint, slope) | Logística estável; inclinação positiva sobe, negativa desce |
| Bell | Bell(center, width, slope) | Sino generalizado; largura e parâmetro de forma positivos |
| SShape | SShape(a, b) | Transição quadrática suave de 0 para 1 |
| ZShape | ZShape(a, b) | Transição quadrática suave de 1 para 0 |
| PiShape | PiShape(a, b, c, d) | Subida S, platô inclusivo e descida Z; a < b <= c < d |
| Rectangle | Rectangle(a, b) | 1 no intervalo fechado, 0 fora |
| DiscreteSet | DiscreteSet(points) | Interpolação linear entre pontos ordenados MembershipPoint; 0 fora do suporte |

Todos os construtores e avaliações rejeitam argumentos não finitos. Ramp e bordas
suaves exigem amplitude finita e não nula. As novas funções de borda/retângulo
rejeitam largura zero; ombros com extremos repetidos continuam em Triangle/Trapezoid.
Sigmoid rejeita inclinação zero. Bell vale 1 no centro e 0,5 à distância width.
Seu cálculo logarítmico evita estouro de potências intermediárias. Diferenças
normalizadas de Gaussian e Sigmoid também tratam valores finitos extremos opostos
sem primeiro estourar a subtração.

Ramp, SShape e ZShape têm **caudas saturadas**. Triangle, Trapezoid, PiShape,
Rectangle e DiscreteSet têm suporte finito e retornam zero fora dele. Sigmoid,
Gaussian e Bell têm suporte matematicamente infinito; o cálculo em ponto flutuante
pode saturar em zero ou um em valores extremos. A integração das saídas respeita
sempre o universo declarado.

DiscreteSet copia a lista. Os pontos devem ter coordenadas estritamente crescentes,
sem duplicatas; exige ao menos dois pontos e amplitude total finita. MembershipPoint
exige coordenada finita e grau finito entre zero e um, inclusive. Os graus nos
extremos são preservados, mesmo quando não nulos; podem existir descontinuidades
nos limites do suporte. A busca interna é binária, com interpolação linear, sem
arredondar para o ponto mais próximo. A classe não representa aritmética fuzzy.

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

## Modificadores linguísticos

Very aplica d² (concentração); Somewhat aplica sqrt(d) (dilatação).
Use `Condition.hedge(FuzzyHedge)` em um termo ou condição composta completa.
O modificador é aplicado antes do peso da regra. Ele preserva referências aos
termos para validação e propaga os operadores selecionados. Modificadores próprios
devem produzir graus finitos entre zero e um; resultados inválidos lançam StateError.
Chamadas diretas aos métodos transform incluídos pressupõem graus válidos.

A ordem é explícita: `term.hedge(const Very()).not()` calcula 1 − d², enquanto
`term.not().hedge(const Very())` calcula (1 − d)². Encadeamentos seguem da esquerda
para a direita. Os modificadores não alteram as funções dos conjuntos de saída.

## Cinco defuzzificadores

| Estratégia | Decisão | Semântica das amostras |
| --- | --- | --- |
| Centroid | Centro da área | Integração trapezoidal de x × grau dividida pela integral do grau |
| Bisector | Divide a área ao meio | Resolve metade da área sob a curva linear entre amostras |
| SmallestOfMaximum | Primeiro máximo | Primeira coordenada qualificada na grade |
| LargestOfMaximum | Último máximo | Última coordenada qualificada na grade |
| MeanOfMaximum | Média dos máximos | Média aritmética de todas as coordenadas qualificadas |

Centroid continua sendo o padrão. Escolha outro com `defuzzifier: const Bisector()`
ou `defuzzifier: MeanOfMaximum(tolerance: 1e-6)`. Todos retornam null para área
amostrada zero, inclusive em chamadas diretas ao defuzzificador.

Bisector integra exatamente os segmentos lineares entre as amostras, normaliza
os graus para estabilidade e resolve analiticamente o segmento do cruzamento.
Se metade da área for atingida no início de um platô nulo, escolhe a coordenada
mais à esquerda desse intervalo de soluções. Isso não é integração exata de uma
função não linear não amostrada.

Os métodos de máximos usam `tolerance: 0` por padrão: igualdade exata ao maior grau
amostrado. A tolerância é absoluta, finita e entre 0 e 1, inclusive. Uma amostra
qualifica se máximo − grau <= tolerância. Valores grandes podem incluir graus
zero quando o máximo é pequeno; esse comportamento precisa ser escolhido.
MeanOfMaximum calcula a média de todas as coordenadas qualificadas, inclusive
máximos desconectados; não é necessariamente o ponto médio do primeiro e do
último. Esses métodos não interpolam picos não amostrados. A resolução pode
alterar suas decisões.

## Exemplo executável

```sh
dart run example/toolbox_example.dart
```

O modelo didático de irrigação usa duas entradas, conjuntos suaves de umidade do
solo, sigmoide de temperatura e modificador linguístico. Para soilMoisture=35 e
airTemperature=32, a grade padrão de 1000 intervalos produz:

| Método | Intensidade de irrigação |
| --- | ---: |
| Centroid | 79,51% |
| Bisector | 83,10% |
| SmallestOfMaximum | 88,30% |
| LargestOfMaximum | 100,00% |
| MeanOfMaximum | 94,15% |

Uma mesma saída fuzzy pode produzir decisões crisp diferentes. Escolha o método
pelo domínio, não pelo resultado numérico mais atraente. Os percentuais representam
intensidade abstrata, não minutos calibrados nem comandos de atuadores.
Veja as [medições de desempenho](performance.md).
