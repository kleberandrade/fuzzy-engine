# Das medições às decisões

As etapas abaixo descrevem os operadores padrão. Consulte as [estratégias configuráveis](strategies.pt-BR.md) para alternativas.

## Etapas da inferência

1. Defina o universo de cada variável: intervalo finito e unidade de medida.
2. Defina conjuntos linguísticos sobrepostos: frio, morno, quente.
3. Fuzzifique cada medição avaliando suas funções de pertinência.
4. Avalie condições: AND = min(a,b), OR = max(a,b), NOT = 1-a.
5. Multiplique o grau da condição pelo peso da regra, entre 0 e 1.
6. Recorte a função de saída: min(ativação, pertinência).
7. Agregue as funções de cada saída pelo máximo, sem somá-las.
8. Calcule o centroide: integral(x × agregado(x)) / integral(agregado(x)).

A implementação integra em coordenadas normalizadas usando a regra trapezoidal
composta e converte o centroide ao intervalo original. `intervals` define quantos
segmentos de integração são usados. Denominador zero produz null.

## Formatos de pertinência

| Função | Parâmetros | Aplicação |
| --- | --- | --- |
| Triangle | início, pico, fim | Termos simples e sobrepostos |
| Trapezoid | início, início do platô, fim do platô, fim | Faixa de pertinência plena |
| Gaussian | média, sigma positivo | Transições suaves e suporte infinito |

Triangle(0,0,25) representa um ombro à esquerda e vale 1 em zero.
Trapezoid(0,0,10,10) é um retângulo com extremos inclusivos. A gaussiana é
truncada no intervalo de saída durante a defuzzificação.
Para criar funções, implemente `MembershipFunction`. Mantenha-as determinísticas
e imutáveis, pois o motor guarda as referências das funções.

## Interpretando o resultado

No modelo do README, 32°C produz morno=0,72 e quente=0,28. A saída média é
recortada em 0,72, a alta em 0,28, e o máximo entre elas é integrado.
Grau 0,72 não significa 72% de chance. Ativações explicam as condições das regras,
mas não são contribuições aditivas ao resultado: a agregação usa máximo.
O resultado mostra as pertinências das entradas e as ativações de todas as regras.

## Como modelar

Comece com poucas regras. Cubra todo o espaço de entrada, inclusive extremos.
Examine saídas nulas, regras contraditórias e transições bruscas. Compare com
cenários conhecidos e estados intermediários. Use unidades consistentes e ajuste
os conjuntos ao comportamento real antes de conectar atuadores.
O resultado não precisa atingir os extremos: o centroide de um ombro totalmente
ativado fica dentro dele. O peso de uma regra altera a área e possivelmente o
centroide; não é um multiplicador direto do valor final.

Os exemplos didáticos usam uma entrada cada. Adicione umidade na climatização,
temperatura na irrigação ou erros recentes no jogo com novas variáveis e condições
compostas. Sugeno está disponível no [SugenoEngine](sugeno.pt-BR.md).
Serialização e aprendizado automático ainda não fazem parte do escopo atual.

[Referência completa](toolbox.pt-BR.md): onze funções de pertinência, modificadores linguísticos e cinco defuzzificadores.
