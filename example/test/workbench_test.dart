// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzy_engine_example/workbench_page.dart';
import 'package:fuzzy_engine_example/lab_model.dart';
import 'package:fuzzy_engine/fuzzy_engine.dart';

void main() {
  testWidgets(
    'compare, change reduction, reset, reject import and cancel edits',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: WorkbenchPage(portuguese: false)),
      );
      expect(find.text('Sugeno'), findsWidgets);
      tester
          .widget<Slider>(find.byKey(const ValueKey('input-demand')))
          .onChanged!(25);
      await tester.pumpAndSettle();
      expect(find.textContaining('power: 35.00'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('reset-inputs')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Slider>(find.byKey(const ValueKey('input-demand'))).value,
        50,
      );
      await tester.tap(find.byKey(const ValueKey('configuration')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '{}');
      await tester.tap(find.text('Validate and load'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Invalid configuration'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Demand comparison'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('select a defuzzifier, import Sugeno and restore presets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: WorkbenchPage(portuguese: false)),
    );
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byType(DropdownButton<String>),
      250,
      scrollable: scrollable,
    );
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smallest of maximum').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('configuration')),
      -250,
      scrollable: scrollable,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('configuration')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      comparisonModels()[1].export(),
    );
    await tester.tap(find.text('Validate and load'));
    await tester.pumpAndSettle();
    expect(find.text('Restore comparison'), findsOneWidget);
    expect(find.text('Mamdani'), findsNothing);
    expect(find.textContaining('power: 50.00'), findsOneWidget);
    await tester.tap(find.text('Restore comparison'));
    await tester.pumpAndSettle();
    expect(find.text('Mamdani'), findsOneWidget);
    expect(find.text('Restore comparison'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('imported overflow reports an error and reset recovers', (
    tester,
  ) async {
    final model = LabModel(
      FuzzyModelDocument(
        engine: SugenoEngine(
          inputs: [
            FuzzyVariable(
              name: 'x',
              min: -1,
              max: 1,
              terms: {'all': Rectangle(-1, 1)},
            ),
          ],
          outputs: [SugenoOutput('y')],
          rules: [
            SugenoRule(
              name: 'overflow',
              when: const Term('x', 'all'),
              output: 'y',
              consequent: LinearConsequent(
                intercept: 1e308,
                coefficients: {'x': 1e308},
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: WorkbenchPage(portuguese: false)),
    );
    await tester.tap(find.byKey(const ValueKey('configuration')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), model.export());
    await tester.tap(find.text('Validate and load'));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byKey(const ValueKey('input-x'))).onChanged!(1);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Cannot evaluate these inputs'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Cannot evaluate these inputs'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('reset-inputs')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reset-inputs')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Slider>(find.byKey(const ValueKey('input-x'))).value,
      0,
    );
    expect(find.textContaining('Cannot evaluate these inputs'), findsNothing);
  });
  testWidgets('phone and large text keep controls accessible', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: const WorkbenchPage(portuguese: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('demand')), findsWidgets);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
