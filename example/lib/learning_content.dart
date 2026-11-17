import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'lab_model.dart';
import 'scenarios.dart';

const engineVersion = '0.3.0'; // Keep aligned with the root pubspec; tested.
const repositoryUrl = 'https://github.com/kleberandrade/fuzzy-engine';
String guideUrl(bool pt) =>
    '$repositoryUrl/blob/main/doc/guide.${pt ? 'pt-BR' : 'en'}.md';
String topicUrl(String topic, bool pt) =>
    '$repositoryUrl/blob/main/doc/$topic.${pt ? 'pt-BR' : 'en'}.md';

class LocalText {
  const LocalText(this.en, this.pt);
  final String en, pt;
  String at(bool portuguese) => portuguese ? pt : en;
}

enum LabPreset { mamdani, sugeno, tsukamoto, irrigation, climate, uncovered }

class PresetLaunch {
  const PresetLaunch(this.model, this.values);
  final LabModel model;
  final Map<String, double> values;
}

PresetLaunch launchPreset(LabPreset preset) {
  if (preset == LabPreset.irrigation)
    return PresetLaunch(
        LabModel(FuzzyModelDocument(
            engine: controller('soilMoisture', 'watering', 0, 100),
            name: 'Irrigation',
            inputUnits: {'soilMoisture': '%'},
            outputUnits: {'watering': '%'})),
        {'soilMoisture': 0});
  if (preset == LabPreset.climate)
    return PresetLaunch(
        LabModel(FuzzyModelDocument(
            engine: climateController(),
            name: 'Climate controller',
            inputUnits: {'temperature': '°C', 'humidity': '%'},
            outputUnits: {'fanDemand': '%', 'heaterDemand': '%'})),
        {'temperature': 20, 'humidity': 50});
  if (preset == LabPreset.uncovered)
    return PresetLaunch(
        LabModel(FuzzyModelDocument(
            name: 'No-decision experiment',
            engine: FuzzyEngine(
              inputs: [
                FuzzyVariable(
                    name: 'demand',
                    min: 0,
                    max: 100,
                    terms: {'low': Triangle(0, 0, 50)})
              ],
              outputs: [
                FuzzyVariable(
                    name: 'power',
                    min: 0,
                    max: 100,
                    terms: {'low': Triangle(0, 0, 50)})
              ],
              rules: [
                FuzzyRule(
                    name: 'low demand → low power',
                    when: const Term('demand', 'low'),
                    output: 'power',
                    term: 'low')
              ],
            ))),
        {'demand': 75});
  final index = switch (preset) {
    LabPreset.sugeno => 1,
    LabPreset.tsukamoto => 2,
    _ => 0
  };
  return PresetLaunch(comparisonModels()[index], {'demand': 25});
}

class Lesson {
  const Lesson(this.id, this.title, this.explanation, this.formula,
      this.interpretation, this.preset, this.source);
  final String id, formula, source;
  final LocalText title, explanation, interpretation;
  final LabPreset preset;
}

const lessons = [
  Lesson(
      'memberships',
      LocalText('1 · Describe overlapping concepts',
          '1 · Descreva conceitos sobrepostos'),
      LocalText(
          'A crisp measurement can belong to more than one linguistic set. A membership degree is between zero and one; it is not a probability. The package implements eleven shapes, including triangles, smooth curves and discrete points.',
          'Uma medição exata pode pertencer a mais de um conjunto linguístico. O grau de pertinência fica entre zero e um; não é uma probabilidade. O pacote implementa onze formatos, incluindo triângulos, curvas suaves e pontos discretos.'),
      'μlow(x) = 1 − x/100     μhigh(x) = x/100     (0 ≤ x ≤ 100)',
      LocalText(
          'In the comparison ramps, demand 25 has low = 0.75 and high = 0.25. Change a shape in the visual editor and inspect the overlap.',
          'Nas rampas de comparação, demanda 25 tem low = 0,75 e high = 0,25. Altere um formato no editor visual e observe a sobreposição.'),
      LabPreset.mamdani,
      'toolbox'),
  Lesson(
      'rules',
      LocalText('2 · Combine conditions and weights',
          '2 · Combine condições e pesos'),
      LocalText(
          'The default AND takes the smaller degree; OR takes the larger; NOT complements it. Very squares a degree and Somewhat takes its square root. A rule weight scales the complete antecedent, not the final crisp output.',
          'Por padrão, E usa o menor grau; OU, o maior; NÃO calcula o complemento. Muito eleva o grau ao quadrado e Um pouco calcula sua raiz quadrada. O peso da regra multiplica o antecedente completo, não a saída numérica final.'),
      'AND(a,b) = min(a,b)     OR(a,b) = max(a,b)     NOT(a) = 1−a\nwᵢ = aᵢ × qᵢ',
      LocalText(
          'For a = 0.75 and weight q = 0.5, strength w = 0.375. Other conjunction/disjunction strategies exist in the core; these equations describe the lab defaults.',
          'Com a = 0,75 e peso q = 0,5, a força w = 0,375. O núcleo oferece outras estratégias de conjunção/disjunção; estas equações descrevem os padrões do laboratório.'),
      LabPreset.climate,
      'strategies'),
  Lesson(
      'mamdani',
      LocalText('3 · Mamdani: reduce an output curve',
          '3 · Mamdani: reduza uma curva de saída'),
      LocalText(
          'Mamdani clips each consequent membership with its rule strength, aggregates using maximum and defuzzifies the sampled set. Centroid balances the area; Bisector splits it; maximum methods select the first, last or mean of peak coordinates. Larsen is the core preset using product implication.',
          'Mamdani recorta cada pertinência de saída pela força da regra, agrega pelo máximo e defuzzifica o conjunto amostrado. O Centroide equilibra a área; o Bissetor a divide; os métodos de máximos escolhem a primeira, a última ou a média das posições de pico. Larsen é o preset do núcleo que usa implicação por produto.'),
      'μout(x) = maxᵢ min(wᵢ, μᵢ(x))\ny = ∫ x μout(x) dx / ∫ μout(x) dx',
      LocalText(
          'The lab comparison uses 200 intervals (201 samples). A fully active shoulder usually produces an interior centroid, not the universe endpoint. More samples increase cost and may improve accuracy.',
          'A comparação usa 200 intervalos (201 amostras). Um ombro totalmente ativo costuma produzir um centroide no interior, não no extremo do universo. Mais amostras aumentam o custo e podem melhorar a precisão.'),
      LabPreset.mamdani,
      'toolbox'),
  Lesson(
      'sugeno',
      LocalText('4 · Sugeno: blend numeric consequents',
          '4 · Sugeno: combine conclusões numéricas'),
      LocalText(
          'Sugeno rules return constants or linear functions of the original crisp inputs. The default weighted average normalizes by total strength. Weighted sum is a separate core option; it does not normalize and can exceed individual consequent values.',
          'As regras Sugeno retornam constantes ou funções lineares das entradas exatas originais. A média ponderada padrão normaliza pela força total. A soma ponderada é uma opção distinta do núcleo; ela não normaliza e pode ultrapassar os valores individuais das conclusões.'),
      'zᵢ = bᵢ + Σⱼ cᵢⱼ xⱼ\ny = Σᵢ(wᵢ zᵢ) / Σᵢ wᵢ',
      LocalText(
          'With demand 25, the preset strengths are 0.75/0.25 and constants 20/80: output = 35. The coefficients are hand configured; the package does not train them.',
          'Com demanda 25, as forças são 0,75/0,25 e as constantes 20/80: saída = 35. Os coeficientes são configurados manualmente; o pacote não os treina.'),
      LabPreset.sugeno,
      'sugeno'),
  Lesson(
      'tsukamoto',
      LocalText('5 · Tsukamoto: invert monotonic terms',
          '5 · Tsukamoto: inverta termos monotônicos'),
      LocalText(
          'Each active Tsukamoto rule inverts a monotonic output term at its weighted strength, then a weighted average combines those crisp values. The core supports invertible ramp, S and Z output terms. Weight is applied before inversion and used again in the average.',
          'Cada regra Tsukamoto ativa inverte um termo monotônico de saída na força ponderada; uma média ponderada combina os valores numéricos. O núcleo oferece termos de saída invertíveis de rampa, S e Z. O peso é aplicado antes da inversão e usado novamente na média.'),
      'zᵢ = μᵢ⁻¹(wᵢ)     y = Σᵢ(wᵢ zᵢ) / Σᵢ wᵢ',
      LocalText(
          'Demand 25 gives inverse value 25 for both preset ramps and output 25. Its consequents differ from the Mamdani triangles and Sugeno constants, so the three presets are not interchangeable accuracy scores.',
          'Demanda 25 resulta em inverso 25 nas duas rampas do preset e saída 25. As conclusões diferem dos triângulos Mamdani e das constantes Sugeno; os três presets não são medidas intercambiáveis de precisão.'),
      LabPreset.tsukamoto,
      'tsukamoto'),
  Lesson(
      'validation',
      LocalText('6 · Recognize no decision and limits',
          '6 · Reconheça ausência de decisão e limites'),
      LocalText(
          'Zero activated area or zero total strength means no decision, represented by null, never a fabricated zero. JSON v1/v2 interchange validates built-in types, references and budgets. FIS/FCL interchange is restricted and does not imply full vendor conformance. No automatic learning, type-2 or hybrid Mamdani/Sugeno engine is implemented.',
          'Área ativada ou soma de forças positivas igual a zero significa ausência de decisão, representada por null, nunca por um zero inventado. O intercâmbio JSON v1/v2 valida tipos internos, referências e limites. FIS/FCL têm perfis restritos, sem garantia de conformidade completa com fornecedores. Não há aprendizado automático, tipo 2 ou motor híbrido Mamdani/Sugeno.'),
      '∫ μout(x) dx = 0  ⇒  y = null\nΣᵢ wᵢ = 0  ⇒  y = null',
      LocalText(
          'Open the deliberately uncovered example at demand 75. Repair the missing coverage with the visual editor. These thresholds are educational, not calibrated hardware or safety controllers.',
          'Abra o exemplo propositalmente sem cobertura na demanda 75. Corrija a cobertura pelo editor visual. Os limites são didáticos, não controladores calibrados para equipamentos ou segurança.'),
      LabPreset.uncovered,
      'model-tools'),
];

const exercises = [
  LocalText(
      'Explain overlap: at demand 25, record 0.75/0.25 and identify both active rules. Complete when neither number is described as a probability.',
      'Explique a sobreposição: na demanda 25, registre 0,75/0,25 e identifique as duas regras ativas. Conclua sem descrever os graus como probabilidades.'),
  LocalText(
      'Compare defuzzifiers: keep demand 25 and record all five Mamdani outputs. Complete when you explain one centroid-versus-maximum difference.',
      'Compare defuzzificadores: mantenha demanda 25 e registre as cinco saídas Mamdani. Conclua explicando uma diferença entre centroide e máximo.'),
  LocalText(
      'Edit Sugeno: change the low consequent from 20 to 40 in the visual editor. Complete when demand 50 yields 60, then export the validated model.',
      'Edite Sugeno: altere a conclusão low de 20 para 40 no editor visual. Conclua quando demanda 50 produzir 60 e exporte o modelo validado.'),
  LocalText(
      'Repair coverage: open No decision, add a high membership and a matching rule. Complete when demand 75 yields a finite result and malformed edits still block Apply.',
      'Corrija a cobertura: abra Sem decisão, adicione pertinência high e uma regra correspondente. Conclua quando demanda 75 produzir resultado finito e edições inválidas ainda bloquearem Aplicar.'),
  LocalText(
      'Explain two outputs: open Climate at 20°C / 50%, inspect fan and heater rules, then edit a copy. Complete when you record both outputs and show the original reference surface remains unchanged.',
      'Explique duas saídas: abra Clima em 20°C / 50%, inspecione regras de ventilação e aquecimento e edite uma cópia. Conclua registrando ambas as saídas e mostrando que a superfície original permanece igual.'),
];
