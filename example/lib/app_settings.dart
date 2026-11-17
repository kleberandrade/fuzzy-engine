// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'platform_stub.dart' if (dart.library.js_interop) 'platform_web.dart'
    as platform;

abstract interface class PreferenceStore {
  String? read(String key);
  void write(String key, String value);
}

class BrowserPreferences implements PreferenceStore {
  const BrowserPreferences();
  @override
  String? read(String key) => platform.readPreference(key);
  @override
  void write(String key, String value) => platform.writePreference(key, value);
}

class AppSettings extends ChangeNotifier {
  AppSettings(this.store) {
    portuguese = store.read('fuzzy-lab.language') != 'en';
    dark = store.read('fuzzy-lab.theme') != 'light';
    platform.setPageLanguage(portuguese ? 'pt-BR' : 'en');
  }
  final PreferenceStore store;
  late bool portuguese, dark;
  void setLanguage(String language) {
    portuguese = language != 'en';
    platform.setPageLanguage(portuguese ? 'pt-BR' : 'en');
    store.write('fuzzy-lab.language', portuguese ? 'pt-BR' : 'en');
    notifyListeners();
  }

  void toggleTheme() {
    dark = !dark;
    store.write('fuzzy-lab.theme', dark ? 'dark' : 'light');
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppSettings> {
  const AppScope(
      {super.key, required AppSettings settings, required super.child})
      : super(notifier: settings);
  static AppSettings? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.notifier;
  static bool pt(BuildContext context, {bool fallback = false}) =>
      of(context)?.portuguese ?? fallback;
}

String translatedOption(BuildContext context, String value) {
  if (!AppScope.pt(context))
    return const {
          'and': 'AND',
          'or': 'OR',
          'not': 'NOT',
          'term': 'Term',
          'very': 'Very',
          'somewhat': 'Somewhat'
        }[value] ??
        value;
  return const {
        'triangle': 'Triangular',
        'trapezoid': 'Trapezoidal',
        'gaussian': 'Gaussiana',
        'ramp': 'Rampa',
        'sigmoid': 'Sigmoide',
        'bell': 'Sino',
        'sShape': 'Curva S',
        'zShape': 'Curva Z',
        'piShape': 'Curva Pi',
        'rectangle': 'Retangular',
        'discrete': 'Pontos discretos',
        'term': 'Termo',
        'and': 'E (AND)',
        'or': 'OU (OR)',
        'not': 'NÃO (NOT)',
        'very': 'Muito (Very)',
        'somewhat': 'Um pouco (Somewhat)',
        'constant': 'Constante',
        'linear': 'Linear',
        'Centroid': 'Centroide',
        'Bisector': 'Bissetor',
        'Mean of maximum': 'Média dos máximos',
        'Smallest of maximum': 'Menor dos máximos',
        'Largest of maximum': 'Maior dos máximos',
        'weightedAverage': 'Média ponderada',
        'weightedSum': 'Soma ponderada',
        'Weighted inverse average': 'Média ponderada dos inversos',
        'Irrigation': 'Irrigação',
        'No-decision experiment': 'Experimento sem decisão',
        'Demand comparison': 'Comparação de demanda',
        'Climate controller': 'Controlador climático',
        'min': 'Mínimo',
        'max': 'Máximo',
        'b · peak': 'b · pico',
        'b · plateau start': 'b · início do platô',
        'c · plateau end': 'c · fim do platô',
        'mean': 'Média',
        'start': 'Início',
        'end': 'Fim',
        'midpoint': 'Ponto médio',
        'slope': 'Inclinação',
        'center': 'Centro',
        'width > 0': 'Largura > 0',
        'slope > 0': 'Inclinação > 0',
      }[value] ??
      value;
}

String translatedParameter(BuildContext context, String value) {
  final split = value.indexOf(' · ');
  if (split >= 0)
    return '${value.substring(0, split)} · ${translatedOption(context, value.substring(split + 3))}';
  return translatedOption(context, value);
}

String localizedProblem(String message, bool pt) {
  if (!pt) return message;
  final lower = message.toLowerCase();
  if (lower.contains('triangle'))
    return 'Triângulo inválido: use a ≤ b ≤ c e a < c.';
  if (lower.contains('trapezoid') || lower.contains('pi shape'))
    return 'Ordene os pontos da curva: a ≤ b ≤ c ≤ d, com intervalo não vazio.';
  if (lower.contains('gaussian') || lower.contains('sigma'))
    return 'A largura sigma precisa ser positiva e finita.';
  if (lower.contains('monotonic') || lower.contains('invert'))
    return 'A saída Tsukamoto precisa de termos monotônicos e invertíveis dentro do intervalo.';
  if (lower.contains('unique term'))
    return 'Escolha um nome de termo não vazio e único.';
  if (lower.contains('duplicate rule'))
    return 'Os nomes das regras precisam ser únicos.';
  if (lower.contains('unknown input term') ||
      lower.contains('unknown output term'))
    return 'Uma regra referencia um termo inexistente. Corrija a condição ou a conclusão.';
  if (lower.contains('weight')) return 'Use um peso finito entre zero e um.';
  if (lower.contains('source length') ||
      lower.contains('limit') ||
      lower.contains('budget'))
    return 'O modelo excede um limite de tamanho, profundidade ou custo do laboratório.';
  if (lower.contains('missing or unknown') ||
      lower.contains('syntax') ||
      lower.contains('unexpected') ||
      lower.contains('version'))
    return 'JSON inválido ou esquema não suportado. Use um documento completo de modelo v1/v2, sem campos extras.';
  if (lower.contains('overflow') || lower.contains('unrepresentable'))
    return 'O cálculo excedeu o intervalo numérico. Reduza coeficientes, valores ou pesos.';
  if (lower.contains('finite') || lower.contains('number'))
    return 'Informe apenas números finitos nos campos numéricos.';
  if (lower.contains('point'))
    return 'Ordene os pontos por x e mantenha os graus μ entre zero e um.';
  return 'Configuração inválida. Revise os intervalos, a ordem dos parâmetros, os nomes e as referências das regras.';
}

bool openExternal(String url) => platform.openExternal(url);
