# Escopo e plano de evolução

[English](roadmap.en.md) · [Arquitetura implementada](architecture.pt-BR.md)

## Escopo atual

A versão 0.1.0 é um motor Mamdani tipo 1 inicial. Ainda não é um framework completo
de lógica fuzzy. Há inferência com múltiplas entradas/saídas, mas cada cenário
Flutter usa uma entrada. O plano abaixo é uma proposta: não representa recursos
já implementados nem compromisso com datas de lançamento.

| Área | Implementado | Ausente / proposto |
| --- | --- | --- |
| Inferência | Mamdani e pesos nas ativações | Sugeno de ordem zero/um, Larsen e Tsukamoto |
| AND / OR / NOT | Mínimo / máximo / complemento, expressões compostas | T-normas e s-normas configuráveis, modificadores linguísticos |
| Implicação / agregação | Recorte mínimo / união máximo | Implicação produto, somas probabilística e limitada |
| Defuzzificação | Centroide por integração numérica | Bissetor e menor/maior/média dos máximos |
| Pertinência | Triangular, trapezoidal, gaussiana e interface extensível | Rampa, sigmoide, sino, curvas S/Z/Pi e conjuntos discretos |
| Base de regras | Uma conclusão por regra com peso e nome | Blocos, múltiplas conclusões e políticas de ativação |
| Configuração | Objetos Dart validados | Esquema JSON versionado, importação/exportação e parser |
| Explicação | Pertinências de entrada e ativações | Curvas agregadas de saída, cobertura e regras inativas |
| Ferramentas | Três demos de uma entrada, testes e guias bilíngues | Superfícies de múltiplas entradas, benchmarks e bases de referência |

## Sequência proposta

1. **Pipeline extensível.** Criar interfaces explícitas para operadores, implicação,
   agregação e defuzzificação, preservando os padrões atuais. Validar cada estratégia
   com referências numéricas independentes.
2. **Ampliar Mamdani tipo 1.** Incluir operadores produto/probabilísticos/limitados,
   funções de pertinência comuns, modificadores linguísticos e defuzzificadores
   adicionais. Definir extremos, platôs, tolerância e área zero em cada algoritmo.
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
