// Retain compatibility with Flutter SDKs predating the Material UI extraction.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:fuzzy_engine/fuzzy_engine.dart';
import 'scenarios.dart';

void main() => runApp(const FuzzyApp());

class FuzzyApp extends StatelessWidget {
  const FuzzyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Fuzzy Lab',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            colorSchemeSeed: const Color(0xff5063e8), useMaterial3: true),
        home: const Lab(),
      );
}

class Lab extends StatefulWidget {
  const Lab({super.key});
  @override
  State<Lab> createState() => _LabState();
}

class _LabState extends State<Lab> {
  int selected = 0;
  double value = 25;
  bool portuguese = true;
  final models = [
    controller('temperature', 'fanSpeed', 0, 50),
    controller('soilMoisture', 'watering', 0, 100),
    controller('performance', 'difficulty', 0, 100)
  ];
  @override
  Widget build(BuildContext context) {
    final engine = models[selected];
    final input = engine.inputs.single;
    final result = engine.evaluate({input.name: value});
    final labels = portuguese
        ? ['Climatização', 'Irrigação', 'Jogo']
        : ['Climate', 'Irrigation', 'Game'];
    return Scaffold(
        appBar: AppBar(title: const Text('Fuzzy Lab'), actions: [
          TextButton(
              onPressed: () => setState(() => portuguese = !portuguese),
              child: Text(portuguese ? 'English' : 'Português')),
        ]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  Text(
                      portuguese
                          ? 'Decisões graduais, regras visíveis.'
                          : 'Gradual decisions. Visible rules.',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  Wrap(
                      spacing: 12,
                      children: List.generate(
                          3,
                          (i) => ChoiceChip(
                              label: Text(labels[i]),
                              selected: selected == i,
                              onSelected: (_) => setState(() {
                                    selected = i;
                                    value = models[i].inputs.single.max / 2;
                                  })))),
                  const SizedBox(height: 24),
                  Text('${input.name}: ${value.toStringAsFixed(1)}'),
                  Slider(
                      value: value,
                      min: input.min,
                      max: input.max,
                      onChanged: (v) => setState(() => value = v)),
                  SizedBox(
                      height: 180,
                      child:
                          CustomPaint(painter: MembershipPlot(input, value))),
                  const SizedBox(height: 12),
                  const Text('low • medium • high'),
                  const SizedBox(height: 24),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              '${engine.outputs.single.name}: ${result.outputs.values.single?.toStringAsFixed(1) ?? "—"} / 100',
                              style:
                                  Theme.of(context).textTheme.headlineSmall))),
                  for (final activation in result.rules)
                    ListTile(
                        title: Text(activation.rule.name),
                        subtitle:
                            LinearProgressIndicator(value: activation.strength),
                        trailing: Text(
                            '${(activation.strength * 100).toStringAsFixed(0)}%')),
                  const SizedBox(height: 16),
                  Text(portuguese
                      ? 'Modelos didáticos. Os graus não são probabilidades. Calibre limites e regras para seu domínio.'
                      : 'Educational models. Degrees are not probabilities. Calibrate ranges and rules for your domain.'),
                ]))));
  }
}

class MembershipPlot extends CustomPainter {
  MembershipPlot(this.variable, this.value);
  final FuzzyVariable variable;
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [Colors.blue, Colors.orange, Colors.red];
    var index = 0;
    for (final f in variable.terms.values) {
      final path = Path();
      for (var i = 0; i <= 200; i++) {
        final x = variable.min + (variable.max - variable.min) * i / 200;
        final y = size.height * (1 - f.degree(x));
        if (i == 0) {
          path.moveTo(0, y);
        } else {
          path.lineTo(size.width * i / 200, y);
        }
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = colors[index++ % colors.length]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    final x =
        (value - variable.min) / (variable.max - variable.min) * size.width;
    canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = Colors.grey
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant MembershipPlot oldDelegate) =>
      oldDelegate.value != value || oldDelegate.variable != variable;
}
