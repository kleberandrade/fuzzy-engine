import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzy_engine_example/main.dart';

void main() {
  testWidgets('scenario, language and input changes update the lab',
      (tester) async {
    await tester.pumpWidget(const FuzzyApp());
    expect(find.text('Climatização'), findsOneWidget);
    expect(find.textContaining('fanSpeed:'), findsOneWidget);
    await tester.tap(find.text('Irrigação'));
    await tester.pumpAndSettle();
    expect(find.textContaining('watering:'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(0);
    await tester.pump();
    expect(find.textContaining('83.3 / 100'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Irrigation'), findsOneWidget);
    await tester.tap(find.text('Game'));
    await tester.pumpAndSettle();
    expect(find.textContaining('difficulty:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
