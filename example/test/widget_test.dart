// Retain compatibility with Flutter SDKs predating the Material UI extraction.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzy_engine_example/main.dart';

void main() {
  testWidgets('two inputs change the decision and return to the original lab',
      (tester) async {
    await tester.pumpWidget(const FuzzyApp());
    await tester.tap(find.byKey(const ValueKey('open-surface')));
    await tester.pumpAndSettle();
    expect(find.text('Ventilação: duas entradas'), findsOneWidget);
    expect(find.text('Demanda: 50.0 / 100'), findsOneWidget);
    tester
        .widget<Slider>(find.byKey(const ValueKey('temperature-slider')))
        .onChanged!(40);
    await tester.pump();
    expect(find.text('Demanda: 83.3 / 100'), findsOneWidget);
    tester
        .widget<Slider>(find.byKey(const ValueKey('humidity-slider')))
        .onChanged!(0);
    await tester.pump();
    expect(find.text('Demanda: 50.0 / 100'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Climatização'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final height in [600.0, 900.0]) {
    testWidgets(
        'scenario, language and input changes update the lab at ${height.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(800, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> reveal(Finder target, {double delta = 200}) async {
        await tester.scrollUntilVisible(target, delta,
            scrollable: find.byType(Scrollable));
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(const FuzzyApp());
      expect(find.text('Climatização'), findsOneWidget);
      // Results are below the fold on short screens and built lazily by ListView.
      await reveal(find.textContaining('fanSpeed:'));
      expect(find.textContaining('fanSpeed:'), findsOneWidget);
      await reveal(find.text('Irrigação'), delta: -200);
      await tester.tap(find.text('Irrigação'));
      await tester.pumpAndSettle();
      await reveal(find.textContaining('watering:'));
      expect(find.textContaining('watering:'), findsOneWidget);
      await reveal(find.byType(Slider), delta: -200);
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(0);
      await tester.pump();
      await reveal(find.textContaining('83.3 / 100'));
      expect(find.textContaining('83.3 / 100'), findsOneWidget);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await reveal(find.text('Irrigation'), delta: -200);
      expect(find.text('Irrigation'), findsOneWidget);
      await tester.tap(find.text('Game'));
      await tester.pumpAndSettle();
      await reveal(find.textContaining('difficulty:'));
      expect(find.textContaining('difficulty:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
