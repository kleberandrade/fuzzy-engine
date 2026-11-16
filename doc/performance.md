# Pipeline benchmark / Medições do pipeline

Run from the package root / Execute a partir da raiz:

```sh
dart run benchmark/inference_benchmark.dart 200
```

The optional number is a positive evaluation count per scenario. Each scenario
has one input, one output, 1000 integration intervals, 50 warm-up evaluations and
1, 10 or 100 active rules. The benchmark includes inference, sample allocation and
defuzzification, and reports a checksum to catch changes in the computed output.
It uses default operators. It is not a Flutter frame-time or end-to-end benchmark.

O número opcional é a quantidade de avaliações por cenário. Cada cenário tem uma
entrada, uma saída, 1000 intervalos, 50 avaliações de aquecimento e 1, 10 ou 100
regras ativas. A medição inclui inferência, alocação de amostras e defuzzificação.
O checksum ajuda a detectar alterações nos resultados. Não mede quadros Flutter.

## Initial local comparison / Comparação local inicial

Single illustrative runs on macOS arm64, Dart 3.11.5 JIT, 2026-11-16. The baseline
is the default engine at commit 734843d; the new pipeline uses default strategies.
Both returned checksum **12871.800000000077** for all three scenarios.

| Active rules / Regras | Baseline µs/evaluation | Configurable pipeline µs/evaluation |
| --- | ---: | ---: |
| 1 | 37.215 | 47.880 |
| 10 | 252.370 | 276.875 |
| 100 | 2415.835 | 2554.180 |

The new pipeline adds strategy dispatch, range checks and retained output curves.
This run shows an overhead rather than a speed improvement. A second baseline
run varied to 35.115 / 260.205 / 2474.755 µs, so these are observations, not a stable
regression threshold. Use repeated isolated runs and release/AOT builds on target
hardware before making performance commitments.

O pipeline adiciona chamadas de estratégia, validações e curvas retidas no
resultado. A medição mostrou custo adicional. Outra execução da base variou para
35,115 / 260,205 / 2474,755 µs; os valores não são um limite estável de regressão.
Repita as medições em isolamento e em compilação release/AOT no dispositivo-alvo.

Both versions have evaluation cost approximately O(inputs × terms + rules +
outputs × intervals × relevant rules). Retaining all output samples adds
O(outputs × intervals) memory per result. This benchmark does not measure peak
memory or garbage-collection behavior. Keep grid sizes appropriate for the model;
benchmark and consider isolates for expensive UI evaluations.

Guardar as amostras acrescenta O(saídas × intervalos) de memória por resultado.
Não houve medição de pico de memória nem do coletor de lixo. Ajuste a resolução
ao modelo e considere isolates para avaliações custosas na interface.

## Toolbox benchmark / Benchmark dos componentes

```sh
dart run benchmark/toolbox_benchmark.dart 100000
```

Measures each of the eleven shapes over a deterministic input cycle, and all five
defuzzifiers over the same 1001-point falling ramp. Defaults: 100000 membership
calls and 1000 defuzzifier calls after warm-up. These are JIT microbenchmarks,
not end-to-end timings; discrete sets use only three points here.

One local run on the same environment measured centroid 0.810, bisector 4.669,
smallest maximum 3.960, largest maximum 4.039 and mean maximum 4.044 µs/call.
Membership calls ranged from 0.028 to 0.051 µs. These noisy measurements do not
establish general performance rankings. Bisector and maxima add linear scans;
DiscreteSet searches O(log(points)). Other membership functions are O(1).
The Gaussian extreme-value guard adds a branch; no performance guarantee is made.

Mede as onze funções em um ciclo determinístico e os cinco métodos na mesma
curva de 1001 pontos. Valores padrão: 100000 chamadas de pertinência e 1000 de
defuzzificação, após aquecimento. São microbenchmarks JIT, com apenas três pontos
no conjunto discreto. As medições locais não estabelecem uma classificação geral
de desempenho. Bissetor e máximos têm varreduras lineares; DiscreteSet busca em
O(log(pontos)). As outras funções de pertinência têm custo O(1).

## Sugeno benchmark

```sh
dart run benchmark/sugeno_benchmark.dart 1000
```

Two inputs, one crisp output, product AND, linear consequents and 1/10/100 rules;
50 warm-up calls per scenario. No output integration grid is used. Each consequent
is 23 for the chosen input; strengths are 0.4. At 1000 calls, average checksums are
23000; sum checksums are approximately 9200 / 92000 / 920000.

| Rules | Weighted average µs/evaluation | Weighted sum µs/evaluation |
| --- | ---: | ---: |
| 1 | 11.256 | 1.742 |
| 10 | 12.455 | 3.112 |
| 100 | 18.105 | 15.391 |

One illustrative local Dart 3.11.5 JIT run, same environment as earlier notes.
JIT warm-up/order affects these timings; no stable ranking or speedup is claimed.
The Mamdani benchmark uses different output semantics and is not an equivalent
controller. Sugeno cost is approximately O(input terms + condition nodes + total
consequent coefficients + rules + outputs), with O(rules + input memberships +
outputs + largest consequent coefficient count) peak working storage, excluding
configuration and garbage-collector behavior. These measurements do not measure
peak memory or GUI frame latency.

Duas entradas, uma saída crisp, AND produto, conclusões lineares e 1/10/100 regras.
Os tempos acima são uma execução JIT local ilustrativa, sem promessa de desempenho.
Não há grade de integração. O benchmark Mamdani tem outra semântica de saída e não
é um controlador equivalente. Não foram medidos pico de memória nem quadros de UI.

## Model tools / Ferramentas de modelos

```sh
dart run benchmark/model_tools_benchmark.dart 200
```

One local Dart 3.11.5 JIT run: a 1234-code-unit, four-rule Mamdani document with
100 integration intervals measured encode 52.155, decode 69.925 and diagnose
128.105 µs/call (200 calls after 20 warm-ups). The diagnostic scenario executes
five actual grid evaluations. These are informational measurements, not guarantees.
JSON traversal is bounded by codec limits; diagnostic cost grows as the full
Cartesian grid times engine evaluation cost, plus membership and structural scans.
Report storage includes per-rule counters, input-grid coordinates and bounded
failure examples; the full Cartesian result history is not retained.

Medição JIT local ilustrativa: encode 52,155, decode 69,925 e diagnóstico 128,105
µs/chamada para o cenário acima. O diagnóstico executa cinco avaliações reais.
Não são garantias. A grade cartesiana multiplica o custo de avaliação do motor;
o relatório não retém todo o histórico de combinações, apenas contadores, grades
de entrada e exemplos limitados de falha.

## Tsukamoto benchmark

```sh
dart run benchmark/tsukamoto_benchmark.dart 1000
```

One input, one SShape output term, 33 validation probes and 1/10/100 identical
active rules. A local Dart 3.11.5 JIT run measured 9.348 / 11.593 / 14.125 µs per
evaluation. All checksums were 61270.16653792661. Constructor measurements were
3517 / 95 / 180 µs, demonstrating warm-up/order effects rather than a meaningful
cross-scenario ranking. Constructor probing is outside timed inference loops.
This is not a comparison with numerically equivalent Mamdani or Sugeno models.

Construction validates every monotonic term in O(terms × validationSamples),
plus model/reference validation. Evaluation cost is approximately O(input terms +
condition nodes + active inverse calls + rules + outputs), assuming O(1) built-in
inverses. Custom functions may cost more. No output integration grid is allocated.
Inverse consistency checks add a forward membership evaluation per active rule.

Medições JIT ilustrativas, sem garantia de desempenho. A construção valida todas
as funções, enquanto o tempo de inferência inclui inversão e verificação direta
por regra ativa. Não há grade de integração de saída. Os cenários não são modelos
numericamente equivalentes aos benchmarks Mamdani/Sugeno.

## Experimental FIS import

```sh
dart run benchmark/fis_benchmark.dart 1000
```

The original 598-code-unit ventilation fixture, 50 warm-up imports and 1000 timed
imports measured 81.909 µs/import in one local Dart 3.11.5 JIT run; checksum 3000
rules. File reading and inference are outside the timed loop. This is an
informational observation, not a performance guarantee or vendor comparison.
Parsing is bounded by source size and explicit input/rule/membership limits;
engine construction validates references without allocating inference output grids.

Na medição local, importar a fixture levou 81,909 µs por operação após aquecimento.
Leitura do arquivo e inferência ficam fora do tempo medido. O valor varia com
máquina, SDK e modelo; não é garantia nem comparação com outras bibliotecas.

## FIS import/export extension (2026-11-16)

The updated benchmark separates import and export for both original fixtures.
One Dart 3.11.5 JIT run, 50 warm-ups and 1000 operations per case:

| Family | Import µs/op | Export µs/op |
| --- | ---: | ---: |
| Mamdani (598 input code units) | 56.707 | 11.563 |
| Sugeno (596 input code units) | 31.803 | 8.029 |

Import checksums were 3000/2000 rules; export checksums were 600000/582000 code
units. File reading and inference are excluded. Results are illustrative and
sensitive to warm-up/order, machine and SDK. They are not vendor comparisons.

O benchmark agora separa importação e exportação Mamdani/Sugeno. As medições são
ilustrativas, sem leitura de arquivo nem inferência no intervalo cronometrado.
Não representam garantia de desempenho nem comparação com outras ferramentas.
