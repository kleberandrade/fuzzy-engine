# fuzzy_engine

**[Abrir o Fuzzy Lab online](https://kleberandrade.github.io/fuzzy-engine/)** ·
[Guia de cenários e limitações (EN)](doc/lab-guide.md)

Compare Mamdani, Sugeno e Tsukamoto, explore curvas e regras, altere a
defuzzificação Mamdani e importe/exporte configurações JSON validadas.
Use o editor visual para alterar curvas, pesos e condições das regras sem editar JSON.
O tema escuro é padrão, com opção de tema claro.
A navbar responsiva inclui marca original, bandeiras circulares Brasil/Reino Unido,
Aprender com fórmulas e cinco exercícios, além de seis exemplos executáveis.
Idioma e tema são salvos no navegador quando permitido, sem descartar o experimento
ao trocar o idioma ou a seção. A interface permite alternar português e inglês; os cenários anteriores continuam disponíveis.

[Importação/exportação experimental FIS Mamdani/Sugeno](doc/fis.pt-BR.md), com
política explícita para saída sem decisão e comparação numérica independente.
O exemplo Flutter também oferece uma superfície com duas entradas.

Motores de lógica fuzzy Mamdani, Sugeno e Tsukamoto para Dart e Flutter, explicáveis e sem dependências de execução.

[English](README.md) · [Guia conceitual](doc/guide.pt-BR.md) · [Exemplo Flutter](example/README.md)

**Publicado:** [fuzzy_engine](https://pub.dev/packages/fuzzy_engine).
Instale com `dart pub add fuzzy_engine` ou `flutter pub add fuzzy_engine`.

O FIS aceita múltiplas saídas. O exemplo Flutter demonstra ventilação e aquecimento
com duas entradas, gráficos e regras visíveis após exportação/importação FIS.

## Arquitetura e escopo

Consulte os [diagramas de classes](doc/architecture.pt-BR.md) e a
[matriz de recursos e evolução](doc/roadmap.pt-BR.md). Esta versão entrega
motores Mamdani, Sugeno e Tsukamoto tipo 1, ainda não um framework completo de lógica fuzzy.

## O que é lógica fuzzy?

Em vez de apenas verdadeiro/falso, descrevemos quanto um valor pertence a um
conjunto linguístico. A 32°C, a temperatura pode ser morna com grau 0,72 e quente
com grau 0,28. Regras combinam esses graus para produzir decisões graduais.
Grau de pertinência não é probabilidade. Não é busca aproximada de texto,
aprendizado de máquina ou serviço HTTP.

Use em controles interpretáveis, irrigação, dificuldade de jogos e avaliações
heurísticas com conceitos sobrepostos. Para limites exatos simples, condições
convencionais podem ser suficientes. Os limites e as regras precisam de calibração.

## Instalação local

```yaml
dependencies:
  fuzzy_engine:
    path: ../fuzzy_engine
```

Requer Dart >=3.3.0. O núcleo não depende de Flutter. Após a publicação, será possível
usar `dart pub add fuzzy_engine` ou `flutter pub add fuzzy_engine`.

## Exemplo completo

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

## Recursos

- Tsukamoto com inversas monotônicas analíticas e atalho Larsen explícito.

- Intercâmbio JSON versionado, metadados de unidades e diagnóstico por amostragem limitada.

- Sugeno de ordem zero/um, média ponderada normalizada e soma ponderada explícita.

- Onze funções de pertinência, incluindo curvas S/Z/Pi e conjuntos discretos interpolados.
- Cinco defuzzificadores: centroide, bissetor e três métodos de máximos; modificadores Very/Somewhat.
- AND/OR/NOT, implicação e agregação configuráveis, preservando os padrões mínimo/máximo/complemento.
- Regras com peso, defuzzificação extensível e centroide numérico como padrão.
- Múltiplas entradas e saídas, resultados imutáveis, curvas agregadas e diagnóstico de cada regra.
- Validação antecipada de nomes, intervalos, referências e pesos.

```dart
final condition = const Term('temperature', 'hot')
    .and(const Term('humidity', 'high'))
    .or(const Term('temperature', 'cold').not());
```

As variáveis e os termos referenciados precisam existir na configuração.
Uma regra com `weight: 0.8` multiplica sua ativação por 0,8.

Veja as [estratégias configuráveis](doc/strategies.pt-BR.md) e execute
`dart run example/strategies_example.dart` para um pipeline personalizado completo.

## Comportamento e limites

Informe exatamente as entradas declaradas, com valores finitos dentro do intervalo.
Entradas inválidas lançam `ArgumentError`; não há ajuste automático de valores.
Consultar uma saída desconhecida também lança erro. Uma saída com área agregada
zero retorna `null`: defina uma alternativa adequada no aplicativo.
Funções personalizadas que retornem graus não finitos ou fora de [0,1] lançam
`StateError` quando avaliadas.

`intervals: 1000` usa 1001 amostras e integração trapezoidal. Aumentar a resolução
custa mais processamento e geralmente melhora a aproximação; conjuntos estreitos
podem exigir mais amostras. As saídas são integradas apenas em seu universo declarado.
Triângulos e trapézios admitem ombros com extremos repetidos; fora do suporte,
retornam zero. O cálculo é síncrono e tem custo aproximado de O(entradas × termos +
regras + saídas × intervalos × regras relevantes). Meça modelos grandes e considere
um isolate em interfaces. Guardar as curvas de saída custa
O(saídas × intervalos) de memória. Não há treinamento nem calibração automática.

## Exemplos e desenvolvimento

O laboratório Flutter tem controles deslizantes, curvas de pertinência e ativações
das regras para climatização, irrigação e dificuldade de jogos, em português e inglês.
Veja [como executar](example/README.md).

```sh
dart pub get --no-example
dart analyze --fatal-infos
dart test
dart run example/quick_start.dart
dart doc
flutter pub publish --dry-run
```

Consulte o [checklist de publicação](doc/PUBLISHING.md). Licença MIT.

[Guia das funções e exemplo de irrigação com duas entradas](doc/toolbox.pt-BR.md).

[Guia Sugeno e exemplo executável](doc/sugeno.pt-BR.md). Use `SugenoEngine` para conclusões constantes/lineares; o `FuzzyEngine` existente mantém os padrões Mamdani.

[Intercâmbio JSON e diagnósticos](doc/model-tools.pt-BR.md), com esquema versionado e exemplo executável.

[Tsukamoto e Larsen](doc/tsukamoto.pt-BR.md), [JSON v2](doc/model-v2.schema.json) e [proposta FIS/FCL](doc/interoperability.pt-BR.md). O perfil restrito FIS Mamdani/Sugeno está implementado e comparado numericamente
com scikit-fuzzy/NumPy. FCL restrito também tem importação/exportação; conformidade completa continua pendente.

[Intercâmbio experimental FCL](doc/fcl.pt-BR.md) · [Qualidade no pub.dev](doc/pub-quality.md)
