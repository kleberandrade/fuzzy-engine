# Interoperabilidade FIS/FCL: perfis propostos

[English](interoperability.en.md)

**Estado: importação experimental de FIS Mamdani implementada.** Veja o
[perfil aceito, políticas e limitações](fis.pt-BR.md). Exportação, FIS Sugeno,
FCL e conformidade numérica externa continuam pendentes.
Suportar Mamdani, Sugeno e Tsukamoto no motor e no JSON não significa compatibilidade
de arquivos com MATLAB, IEC 61131-7 ou outras bibliotecas.

## Primeiro perfil FIS proposto

| Área | Alvo inicial | Rejeitar até haver suporte explícito |
| --- | --- | --- |
| Famílias | Mamdani tipo 1; depois Sugeno constante/linear | Tipo 2, híbridos e extensões Tsukamoto |
| Variáveis | Universos de entrada finitos, nomeados e uma saída | Universos implícitos/ilimitados e vetores de regras com múltiplas saídas |
| Pertinência | trimf, trapmf, gaussmf | Funções arbitrárias e convenções de parâmetros não mapeadas |
| Condições | AND ou OR planos, complemento explícito e índices de entradas ignoradas | Misturas aninhadas não representáveis no perfil escolhido |
| Regras | Condição não vazia, uma conclusão e pesos/convenções explícitos | Todas as entradas ignoradas, até haver representação de condição verdadeira |
| Decisão | Conjunção mínimo/produto, disjunção máximo/probabilística, implicação mínimo/produto, agregação máximo, centroide ou média Sugeno normalizada | Métodos, valores alternativos ou estado anterior não suportados |

A tabela descreve o objetivo amplo; o guia de importação lista o perfil entregue. O parser precisa mapear os parâmetros
pelo significado, não pela posição do construtor. Convenções de largura/centro da
gaussiana devem ser verificadas na definição do formato. Coeficientes lineares
precisam ser associados à ordem declarada das entradas, com convenção do intercepto
verificada. Seções, campos, funções e métodos desconhecidos devem falhar com posição
no arquivo, sem escolher padrões silenciosamente.

## Primeiro perfil FCL proposto

Um FUNCTION_BLOCK, variáveis REAL, universos finitos explícitos, um RULEBLOCK,
termos lineares por pontos representáveis por DiscreteSet, conjunção/implicação
mínimo, agregação máximo e centro de gravidade. Gramáticas mais amplas virão depois
de validar esse primeiro perfil com referências independentes.

DEFAULT e políticas de retenção de valor anterior precisam ser representados
explicitamente. O núcleo retorna null quando nenhuma regra decide a saída; isso
não pode substituir silenciosamente um DEFAULT numérico ou estado anterior.
O exemplo de referência do jFuzzyLogic usa DEFAULT := 0; esse caso exigirá uma
política de adaptação explícita, sem mudar os padrões do núcleo inadvertidamente.

## Critérios para alegações de compatibilidade

1. Definir lexer/parser com limites para o dialeto escolhido; nunca executar o texto.
2. Obter fixtures independentes, com origem e licenças registradas.
3. Comparar saídas crisp, pertinências e ativações nos extremos, sobreposições e
   pontos sem regras ativas.
4. Especificar coordenadas de amostragem e integração. Mesmo nome de método não
   garante mesma discretização; as tolerâncias numéricas precisam de justificativa.
5. Preservar os campos suportados ao exportar/importar e rejeitar o restante,
   sem aproximação ou descarte silencioso. Testes de ida e volta não bastam.
6. Manter as fixtures JSON v1/v2 passando e documentar cada dialeto externo aceito.

O importador inicial tem parser limitado e fixtures analíticas originais. Ainda
faltam arquivos exportados por ferramentas externas e comparação numérica; os
critérios para alegações mais fortes de compatibilidade não foram atendidos.
Use os esquemas JSON para portar modelos do pacote. Não há certificação de
fornecedor nem conformidade completa com padrões externos.

Referências primárias:
- [MathWorks readfis](https://in.mathworks.com/help/fuzzy/readfis.html)
- [Documentação Sugeno MathWorks](https://www.mathworks.com/help/fuzzy/sugfis.html)
- [Documentação FCL jFuzzyLogic](https://jfuzzylogic.sourceforge.net/html/fcl.html)
- [Artigo técnico FuzzyLite](https://fuzzylite.com/downloads/FuzzyLite-Libraries.pdf)
