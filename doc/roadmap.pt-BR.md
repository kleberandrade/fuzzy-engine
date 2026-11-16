# Escopo e plano de evolução

[English](roadmap.en.md) · [Arquitetura implementada](architecture.pt-BR.md)

## Progresso

A etapa de pipeline extensível está implementada localmente, com 281 testes passando,
contratos públicos e exemplo executável. A nova validação remota do CI está pendente.
A etapa de ampliação Mamdani também está implementada: onze funções de pertinência,
cinco defuzzificadores e modificadores Very/Somewhat. Sugeno com conclusões constantes/lineares e as duas reduções também está implementado.
Intercâmbio versionado, unidades e diagnósticos estruturais/por amostragem limitada
estão implementados. Tsukamoto e o atalho Larsen estão implementados. O intercâmbio restrito FIS Mamdani/Sugeno, as referências numéricas externas e a
superfície Flutter com duas entradas estão implementados. A importação inicial restrita FCL também está implementada; exportação FCL e conformidade completa continuam pendentes.

## Escopo atual

A versão em desenvolvimento inclui motores Mamdani, Sugeno e Tsukamoto tipo 1. Ainda não é um framework completo
de lógica fuzzy. Há inferência com múltiplas entradas/saídas, e o Flutter inclui uma superfície dedicada com duas entradas. Os itens concluídos estão marcados abaixo. Os demais são propostas, sem
representar recursos já entregues nem compromisso com datas de lançamento.

| Área | Implementado | Ausente / proposto |
| --- | --- | --- |
| Inferência | Mamdani/Larsen, Sugeno de ordem zero/um e Tsukamoto monotônico | Motores híbridos |
| AND / OR / NOT | Normas e negação configuráveis; AND mínimo/produto/limitado e OR máximo/probabilístico/limitado; Very/Somewhat | Outros modificadores |
| Implicação / agregação | Configuráveis; mínimo/produto/limitado e máximo/probabilístico/limitado | Estratégias por bloco de regras/saída |
| Defuzzificação | Centroide, bissetor, três métodos de máximos e interface extensível | Defuzzificação por saída |
| Pertinência | Onze funções, incluindo Ramp, Sigmoid, Bell, S/Z/Pi, Rectangle e DiscreteSet | Outras funções especializadas |
| Base de regras | Uma conclusão por regra com peso e nome | Blocos, múltiplas conclusões e políticas de ativação |
| Configuração | Objetos Dart, JSON v1/v2, metadados, catálogo e intercâmbio experimental FIS Mamdani/Sugeno | Exportação FCL, ampliação da gramática e migrações |
| Explicação | Rastreamento de entradas/saídas, cobertura amostrada e análise estrutural | Provas de cobertura contínua e resolução semântica de conflitos |
| Ferramentas | Demos Flutter, modelos de console, benchmarks, referências externas e superfície com duas entradas | Bases amplas de conformidade externa |

## Sequência proposta

1. **Pipeline extensível — implementado, aguardando CI remoto.** Interfaces
   públicas para operadores, implicação, agregação e defuzzificação preservam os
   padrões. Testes numéricos independentes cobrem as estratégias selecionáveis.
2. **Ampliar Mamdani tipo 1 — implementado, aguardando CI remoto.** Novas funções
   de pertinência, Very/Somewhat, bissetor e métodos de máximos incluídos. Extremos,
   platôs, tolerância e área zero têm contratos documentados.
3. **Sugeno — implementado, aguardando CI remoto.** Conclusões constantes/lineares,
   média ponderada normalizada, soma ponderada explícita e explicações imutáveis.
   Testes analíticos, de ativação zero e aritmética extrema incluídos.
4. **Portabilidade e diagnóstico — implementado, aguardando CI remoto.** JSON v1,
   unidades, fixtures de referência e testes de ida e volta, grades limitadas de
   cobertura/ativação e achados de duplicatas/concorrência. Sem executar expressões;
   os achados amostrados não provam cobertura ou contradição matemáticas.
5. **Controladores avançados — motor implementado, interoperabilidade pendente.**
   Atalho Larsen, Tsukamoto monotônico, validação de inversas, JSON v2 e diagnósticos
   implementados, com intercâmbio restrito FIS Mamdani/Sugeno e comparação numérica
   externa. A importação inicial restrita FCL também está implementada; exportação FCL e conformidade completa continuam pendentes. Veja o [escopo restante](interoperability.pt-BR.md).

## Critério de conclusão de cada recurso

Interface pública, explicações em português e inglês, exemplo executável,
referências numéricas independentes, testes de extremos e impacto em desempenho.
Alterações nos padrões numéricos precisam ser documentadas; modelos existentes
mantêm o comportamento, salvo mudança incompatível deliberada.

Tipo 2 intervalar, relações e composição fuzzy, aritmética fuzzy e aprendizado
neuro-fuzzy são áreas futuras separadas. Precisam de requisitos e modelos próprios;
não é necessário implementar todas para entregar um motor tipo 1 útil.

Referências sobre a amplitude de bibliotecas de controle estabelecidas:
[recursos do FuzzyLite](https://fuzzylite.com/) e
[artigo técnico](https://fuzzylite.com/downloads/FuzzyLite-Libraries.pdf).
A comparação é conceitual, sem promessa de compatibilidade nem reutilização de código.
