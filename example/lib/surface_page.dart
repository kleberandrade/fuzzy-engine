// Retain compatibility with Flutter SDKs predating the Material UI extraction.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'scenarios.dart';
import 'lab_model.dart';
import 'workbench_page.dart';

/// Two-input controls, activation explanations and a cached decision heatmap.
class SurfacePage extends StatefulWidget {
  const SurfacePage({super.key, required this.portuguese});
  final bool portuguese;
  @override
  State<SurfacePage> createState() => _SurfacePageState();
}

class _SurfacePageState extends State<SurfacePage> {
  final FisModel model = climateFisModel();
  late final Map<String, List<List<double?>>> grids;
  String selectedOutput = 'fanDemand';
  double temperature = 20, humidity = 50;
  static const resolution = 21;
  @override
  void initState() {
    super.initState();
    grids = {
      for (final output in model.engine.outputs)
        output.name: List.generate(
            resolution, (_) => List<double?>.filled(resolution, null))
    };
    for (var h = 0; h < resolution; h++) {
      for (var t = 0; t < resolution; t++) {
        final result = model.evaluate({
          'temperature': 40 * t / (resolution - 1),
          'humidity': 100 * h / (resolution - 1),
        });
        for (final entry in result.values.entries) {
          grids[entry.key]![h][t] = entry.value;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = AppScope.pt(context, fallback: widget.portuguese);
    final result =
        model.evaluate({'temperature': temperature, 'humidity': humidity});
    final value = result.values['fanDemand'];
    final heater = result.values['heaterDemand'];
    return Scaffold(
        appBar: AppBar(
            title: Text(
                pt ? 'Climatização: duas saídas' : 'Climate: two outputs')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  Text(pt
                      ? 'Temperatura e umidade controlam ventilação e aquecimento.'
                      : 'Temperature and humidity control fan and heater demand.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      icon: const Icon(Icons.tune),
                      label: Text(pt
                          ? 'Editar cópia na bancada'
                          : 'Edit a copy in the workbench'),
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => WorkbenchPage(
                                  portuguese: pt,
                                  initialModel: LabModel(FuzzyModelDocument(
                                      engine: climateController(),
                                      name: 'Climate controller')))))),
                  const SizedBox(height: 16),
                  Text(
                      '${pt ? 'Temperatura' : 'Temperature'}: ${temperature.toStringAsFixed(1)} °C'),
                  Slider(
                      key: const ValueKey('temperature-slider'),
                      value: temperature,
                      min: 0,
                      max: 40,
                      label: '${temperature.toStringAsFixed(1)} °C',
                      onChanged: (v) => setState(() => temperature = v)),
                  Text(
                      '${pt ? 'Umidade' : 'Humidity'}: ${humidity.toStringAsFixed(1)}%'),
                  Slider(
                      key: const ValueKey('humidity-slider'),
                      value: humidity,
                      min: 0,
                      max: 100,
                      label: '${humidity.toStringAsFixed(1)}%',
                      onChanged: (v) => setState(() => humidity = v)),
                  Text(
                      '${pt ? 'Demanda' : 'Demand'}: ${value?.toStringAsFixed(1) ?? '—'} / 100',
                      key: const ValueKey('surface-output'),
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(
                      '${pt ? 'Aquecimento' : 'Heating'}: ${heater?.toStringAsFixed(1) ?? '—'} / 100',
                      key: const ValueKey('heater-output')),
                  const SizedBox(height: 16),
                  Text(pt
                      ? 'Modelo exportado para FIS e importado novamente.'
                      : 'Model exported to FIS and imported again.'),
                  Wrap(spacing: 12, children: [
                    for (final name in grids.keys)
                      ChoiceChip(
                          key: ValueKey('surface-$name'),
                          label: Text(name == 'fanDemand'
                              ? (pt ? 'Ventilação' : 'Fan')
                              : (pt ? 'Aquecimento' : 'Heating')),
                          selected: selectedOutput == name,
                          onSelected: (_) =>
                              setState(() => selectedOutput = name)),
                  ]),
                  const SizedBox(height: 24),
                  Text(
                      pt
                          ? 'Superfície de decisão (vista superior)'
                          : 'Decision surface (top view)',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(pt
                      ? 'Eixo vertical: umidade, de 0% embaixo a 100% em cima.'
                      : 'Vertical axis: humidity, 0% at bottom to 100% at top.'),
                  SizedBox(
                      height: 260,
                      child: Semantics(
                          label: pt
                              ? 'Mapa de demanda: azul baixo, vermelho alto. O círculo marca as entradas atuais.'
                              : 'Demand map: blue low, red high. The circle marks current inputs.',
                          child: CustomPaint(
                              painter: _SurfacePainter(grids[selectedOutput]!,
                                  temperature / 40, humidity / 100)))),
                  Text(pt
                      ? 'Eixo horizontal: temperatura, 0 a 40 °C.'
                      : 'Horizontal axis: temperature, 0 to 40 °C.'),
                  Text(pt
                      ? 'Azul = 0 · Vermelho = 100 · Cinza = sem decisão'
                      : 'Blue = 0 · Red = 100 · Gray = no decision'),
                  const SizedBox(height: 16),
                  Text(pt
                      ? 'Malha de 21 × 21 decisões; marcador calculado nas entradas exatas.'
                      : 'Grid of 21 × 21 decisions; marker evaluated at the exact inputs.'),
                  Text(pt
                      ? 'Modelo didático, sem calibração para equipamentos reais.'
                      : 'Educational model, not calibrated for real equipment.'),
                  const SizedBox(height: 16),
                  Text(pt ? 'Ativação das regras' : 'Rule activation',
                      style: Theme.of(context).textTheme.titleLarge),
                  for (final rule in result.trace.rules)
                    ListTile(
                        title: Text('${rule.rule.output}: ${rule.rule.name}'),
                        subtitle: LinearProgressIndicator(value: rule.strength),
                        trailing: Text(
                            '${(rule.strength * 100).toStringAsFixed(0)}%')),
                ]))));
  }
}

class _SurfacePainter extends CustomPainter {
  _SurfacePainter(this.grid, this.x, this.y);
  final List<List<double?>> grid;
  final double x, y;
  @override
  void paint(Canvas canvas, Size size) {
    final rows = grid.length, cols = grid.first.length;
    // Voronoi cells centered on sample coordinates, including both endpoints.
    for (var h = 0; h < rows; h++) {
      for (var t = 0; t < cols; t++) {
        final value = grid[h][t];
        final left = ((t - .5) / (cols - 1)).clamp(0.0, 1.0) * size.width;
        final right = ((t + .5) / (cols - 1)).clamp(0.0, 1.0) * size.width;
        final top = (1 - ((h + .5) / (rows - 1)).clamp(0.0, 1.0)) * size.height;
        final bottom =
            (1 - ((h - .5) / (rows - 1)).clamp(0.0, 1.0)) * size.height;
        canvas.drawRect(
            Rect.fromLTRB(left, top, right, bottom),
            Paint()
              ..color = value == null
                  ? Colors.grey
                  : Color.lerp(
                      Colors.blue, Colors.red, (value / 100).clamp(0.0, 1.0))!);
      }
    }
    final point = Offset(x * size.width, (1 - y) * size.height);
    canvas.drawCircle(point, 7, Paint()..color = Colors.white);
    canvas.drawCircle(
        point,
        7,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _SurfacePainter old) =>
      old.grid != grid || old.x != x || old.y != y;
}
