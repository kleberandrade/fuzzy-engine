# Escopo e plano de evolução

[English](roadmap.en.md) · [Arquitetura implementada](architecture.pt-BR.md)

## Progresso

A etapa de pipeline extensível está implementada localmente, com 68 testes passando,
contratos públicos e exemplo executável. A nova validação remota do CI está pendente.
A etapa de ampliação Mamdani também está implementada: onze funções de pertinência,
cinco defuzzificadores e modificadores Very/Somewhat. Sugeno é a próxima etapa.

## Escopo atual

A versão 0.1.0 é um motor Mamdani tipo 1 inicial. Ainda não é um framework completo
de lógica fuzzy. Há inferência com múltiplas entradas/saídas, mas cada cenário
Flutter usa uma entrada. Os itens concluídos estão marcados abaixo. Os demais são propostas, sem
representar recursos já entregues nem compromisso com datas de lançamento.

| Área | Implementado | Ausente / proposto |
| --- | --- | --- |
| Inferência | Padrões Mamdani e implicação produto configurável | Sugeno de ordem zero/um e Tsukamoto |
| AND / OR / NOT | Normas e negação configuráveis; AND mínimo/produto/limitado e OR máximo/probabilístico/limitado; Very/Somewhat | Outros modificadores |
| Implicação / agregação | Configuráveis; mínimo/produto/limitado e máximo/probabilístico/limitado | Estratégias por bloco de regras/saída |
| Defuzzificação | Centroide, bissetor, três métodos de máximos e interface extensível | Defuzzificação por saída |
| Pertinência | Onze funções, incluindo Ramp, Sigmoid, Bell, S/Z/Pi, Rectangle e DiscreteSet | Outras funções especializadas |
| Base de regras | Uma conclusão por regra com peso e nome | Blocos, múltiplas conclusões e políticas de ativação |
| Configuração | Objetos Dart validados | Esquema JSON versionado, importação/exportação e parser |
| Explicação | Pertinências, ativações e curvas agregadas imutáveis | Cobertura e regras inativas |
| Ferramentas | Três demos de uma entrada, testes e guias bilíngues | Superfícies de múltiplas entradas, benchmarks e bases de referência |

## Sequência proposta

1. **Pipeline extensível — implementado, aguardando CI remoto.** Interfaces
   públicas para operadores, implicação, agregação e defuzzificação preservam os
   padrões. Testes numéricos independentes cobrem as estratégias selecionáveis.
2. **Ampliar Mamdani tipo 1 — implementado, aguardando CI remoto.** Novas funções
   de pertinência, Very/Somewhat, bissetor e métodos de máximos incluídos. Extremos,
   platôs, tolerância e área zero têm contratos documentados.
3. **Sugeno.** Conclusões constantes e lineares com média ponderada normalizada;
   manter soma ponderada como método distinto. Testar resultados analíticos e peso
   total zero.
4. **Portabilidade e diagnóstico.** JSON versionado com testes de ida e volta;
   diagnóstico de cobertura, regras inativas/contraditórias, curvas e unidades.
   A configuração não deve executar expressões Dart arbitrárias.
5. **Controladores avançados e integrações.** Larsen e Tsukamoto monotônico com
   validação da inversa; interoperabilidade FCL/FIS após definir um subconjunto
   suportado e casos de conformidade.

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
