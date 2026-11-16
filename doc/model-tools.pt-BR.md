# Modelos versionados e diagnósticos

[English](model-tools.en.md) · [JSON Schema v1](model-v1.schema.json) · [Diagramas](architecture.pt-BR.md)

## Atualização para v2

A exportação padrão agora emite v2 e suporta Tsukamoto como terceira família.
A importação aceita v1 e v2. Use FuzzyModelCodec(exportVersion: 1) para exportar
Mamdani/Sugeno ao formato antigo; Tsukamoto não pode ser rebaixado. O envelope e
os identificadores anteriores mantêm o significado. A v2 acrescenta engineType=tsukamoto,
saídas monotônicas limitadas, validationSamples e inverseTolerance. Veja o
[esquema v2](model-v2.schema.json) e o [guia Tsukamoto](tsukamoto.pt-BR.md).
A descrição de v1 abaixo continua como perfil legado, não como exportação padrão.

## Importação e exportação

FuzzyModelCodec suporta FuzzyEngine, SugenoEngine e TsukamotoEngine. Passe o motor ao encode ou
use FuzzyModelDocument para preservar nome, descrição e unidades. O núcleo usa
somente dart:convert; não acessa arquivos, rede nem serviços externos. Ler/gravar
arquivos é responsabilidade da aplicação.

```dart
final codec = FuzzyModelCodec();
final document = FuzzyModelDocument(
  engine: engine,
  name: 'Fan control',
  inputUnits: {'temperature': '°C'},
  outputUnits: {'fan': '%'},
);
final source = codec.encode(document);
final restored = codec.decode(source);
final restoredEngine = restored.engine as FuzzyEngine;
final report = const FuzzyDiagnostics().analyze(
  restored,
  samplesPerInput: 5,
  maxEvaluations: 10000,
);
print(restoredEngine.evaluate({'temperature': 20}).value('fan'));
print(report.nullOutputCounts);
```

O trecho pressupõe um modelo Mamdani existente com as variáveis temperature/fan.
Para código completo, execute `dart run example/model_tools_example.dart`.
Para Sugeno, use o mesmo codec ou decodeSugeno(source). Os métodos decodeMamdani
e decodeSugeno retornam somente o motor: use decode(source) para preservar os
metadados. toJson/fromJson trabalham com mapas; encode/decode com texto JSON.
A importação também executa a validação dos construtores dos modelos. Mapas
exportados são separados da configuração do motor.

## Esquema versão 1

O documento exige schemaVersion, engineType, metadata, inputs, outputs, rules,
operators e settings. engineType aceita exatamente mamdani ou sugeno; a versão
é o valor inteiro 1, aceitando a representação numérica equivalente 1.0.
Campos, versões, tipos e referências desconhecidos são rejeitados. Exemplos:
[modelo Mamdani](../test/fixtures/mamdani-v1.json) e
[modelo Sugeno](../test/fixtures/sugeno-v1.json).

| Componente | Representação v1 |
| --- | --- |
| Variável | name, min, max e termos por nome linguístico |
| Pertinência | type e vetor parameters na ordem do construtor |
| DiscreteSet | type=discrete, parameters=[[x,grau], ...] |
| Condição | term(variable,term), and/or(left,right), not(operand), hedge(modifier,operand) |
| Modificadores | very ou somewhat |
| Operadores | Nomes das normas incluídas e negação standard |
| Configuração Mamdani | intervals, implication, aggregation e defuzzifier |
| Método de máximos | type e tolerance explícita |
| Configuração Sugeno | aggregation=weightedAverage ou weightedSum |
| Conclusão constante | type=constant e value |
| Conclusão linear | type=linear, intercept e coeficientes por nome de entrada |
| Metadados | name/description anuláveis; mapas inputUnits e outputUnits |

São suportadas as onze funções de pertinência, três t-normas, três s-normas,
cinco defuzzificadores, Very/Somewhat e conclusões constantes/lineares. A ordem
dos parâmetros segue os construtores no [guia de funções](toolbox.pt-BR.md).
Os identificadores são triangle, trapezoid, gaussian, ramp, sigmoid, bell, sShape,
zShape, piShape, rectangle e discrete. Normas: minimum, algebraicProduct,
boundedDifference, maximum, probabilisticSum e boundedSum. O esquema contém os
campos completos.

Extensões Dart continuam disponíveis em execução, mas funções, operadores,
negações, modificadores, defuzzificadores e callbacks próprios lançam UnsupportedError
na exportação. A v1 não carrega plugins, código-fonte Dart nem executa expressões
textuais. Tipos JSON não suportados lançam FormatException. As unidades precisam
referenciar variáveis declaradas; são rótulos, sem conversão ou verificação
dimensional. Descrições são somente texto e nunca são executadas.

## Limites e comportamento do parser

| Opção | Padrão | Significado |
| --- | ---: | --- |
| maxSourceLength | 1000000 | Unidades UTF-16 no texto de encode/decode |
| maxNodes | 10000 | Valores e contêineres JSON, inclusive metadados |
| maxDepth | 64 | Profundidade JSON e travessia das condições |
| maxOutputSamples | 1000000 | Soma de intervals+1 entre todas as saídas Mamdani |

O tamanho textual é verificado antes de jsonDecode. Nós e profundidade são
verificados após o parse e antes da construção do motor. Mapas recebidos diretamente
também são verificados, inclusive ciclos e valores não finitos. A exportação aplica
os mesmos limites estruturais e de amostras. Intervalos inteiros como 1000.0 são
aceitos. Esses limites não constituem um sandbox de CPU para callbacks próprios
ou grades de diagnóstico arbitrárias.
O parser Dart trata sintaxe e nomes de propriedades duplicados; este codec não é
um protocolo de canonicalização/assinatura. Se sua aplicação proíbe chaves JSON
duplicadas, rejeite-as antes. O JSON Schema descreve a estrutura; os construtores
e o codec verificam também ordenação de parâmetros, referências, unidades e
limites configurados. Nenhum arquivo de origem é regravado automaticamente. Reexportar com o codec padrão produz v2; selecione exportVersion: 1 para preservar o envelope legado.

## Diagnóstico por amostragem

FuzzyDiagnostics recebe um motor ou documento e não altera suas regras. Usa o
produto cartesiano completo de grades uniformes, incluindo extremos. Com k entradas
e n amostras por entrada, são n^k avaliações. O padrão é 11 amostras por entrada,
com limite de 10000 avaliações. Grades maiores são rejeitadas antes de executar
callbacks, sem truncamento silencioso. Componentes personalizados são executados
localmente e precisam ser determinísticos e sem efeitos colaterais.

| Código | Interpretação |
| --- | --- |
| inputCoverageGap | Nenhum termo supera o limiar em uma coordenada amostrada |
| inputMembershipFailure | Avaliação de pertinência inválida ou com exceção |
| zeroWeightRule | Regra explicitamente desativada; informativo |
| ruleNotObserved | Nenhuma ativação acima do limiar nas avaliações bem-sucedidas |
| outputWithoutDecision | Saída null em avaliações bem-sucedidas |
| duplicateRules | Mesmos antecedente estrutural, saída, conclusão e peso |
| competingConsequents | Mesmo antecedente/saída, conclusões ativas diferentes |
| structuralAnalysisSkipped | Componente próprio ou profundo impede comparação estrutural |
| evaluationFailure | Exceção ao avaliar o motor em uma combinação amostrada |

O limiar padrão é zero: ativação significa strength > limiar. Alterá-lo modifica
o relatório, não a inferência. A cobertura das entradas compara pertinências ao
mesmo limiar. Contadores de regras e saídas excluem avaliações com falha.
UncoveredEvaluations conta pontos bem-sucedidos sem regras acima do limiar, o que
é diferente de saída null: uma regra pode ativar e a grade de saída Mamdani ainda
assim não detectar uma conclusão muito estreita.

São **observações, não provas de cobertura contínua nem resolução automática de
conflitos**. Uma regra ausente na grade pode ativar entre amostras. Antecedentes
não são simplificados por equivalência lógica nem têm operandos AND/OR reordenados.
A ordem de chaves de coeficientes lineares é normalizada na comparação.
Duplicatas e conclusões concorrentes podem ser intencionais, especialmente com
soma ponderada; nenhuma regra é removida. O alerta de concorrência não prova uma
contradição matemática. Não se infere consistência dimensional.

O relatório tem grades, lacunas, contagens, máximos, saídas nulas, falhas e achados
imutáveis. toJson produz dados portáveis. Mensagens brutas de callbacks e stack
traces não são incluídos. Por padrão retém até três exemplos de entrada com falha;
use maxFailureExamples=0 para não retê-los. O relatório pode conter valores da
aplicação: compartilhar/exportar é decisão de quem usa o pacote. A amostragem de
extensões próprias continua funcionando mesmo quando a comparação estrutural é
pulada. Grades com falha em todos os pontos não rotulam falsamente regras como
não observadas.

## Reproduzindo o exemplo

O exemplo inclui deliberadamente uma regra hot/high duplicada, outra hot/low
concorrente e a regra cold desativada. Cinco amostras de temperatura produzem uma
saída fan null, uma duplicata e um aviso de concorrência. O relatório explica isso
sem declarar automaticamente que o modelo está errado nem modificá-lo.

Veja as [medições de desempenho](performance.md).
