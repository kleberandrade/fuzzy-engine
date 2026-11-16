import 'lib/scenarios.dart';

void main() {
  final engine = controller('temperature', 'fanSpeed', 0, 50);
  final result = engine.evaluate({'temperature': 32});
  print('Fan speed: ${result.value('fanSpeed')!.toStringAsFixed(2)}%');
  for (final activation in result.rules) {
    print('${activation.rule.name}: ${activation.strength}');
  }
}
