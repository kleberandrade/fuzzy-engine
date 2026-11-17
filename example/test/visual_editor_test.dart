// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzy_engine_example/main.dart';
import 'package:fuzzy_engine_example/lab_model.dart';
import 'package:fuzzy_engine_example/visual_editor_page.dart';

void main() {
  testWidgets('dark is default and light toggle preserves scenario state',
      (tester) async {
    await tester.pumpWidget(const FuzzyApp());
    expect(
        Theme.of(tester.element(find.byType(Lab))).brightness, Brightness.dark);
    await tester.tap(find.byKey(const ValueKey('toggle-theme')));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(Lab))).brightness,
        Brightness.light);
    expect(find.text('Climatização'), findsOneWidget);
  });

  testWidgets(
      'changing a curve updates preview; invalid shape cannot apply; Back cancels',
      (tester) async {
    final original = comparisonModels().first;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => VisualEditorPage(
                                model: original, portuguese: false))),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final parameter = find.byKey(const ValueKey('parameter-true-0-low-ramp-1'));
    await tester.scrollUntilVisible(parameter, 200,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('variables-true')),
                matching: find.byType(Scrollable))
            .first);
    await tester.enterText(parameter, '80');
    await tester.pumpAndSettle();
    expect(original.inputs.first.terms['low']!.degree(50), .5);
    await tester.enterText(parameter, '100');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('apply-visual')))
            .onPressed,
        isNull);
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('visual Sugeno consequent applies a changed decision',
      (tester) async {
    LabModel? saved;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      saved = await Navigator.push<LabModel>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => VisualEditorPage(
                                  model: comparisonModels()[1],
                                  portuguese: false)));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();
    final constant = find.byWidgetPredicate(
        (w) => w is TextFormField && w.key.toString().contains('constant-'));
    await tester.scrollUntilVisible(constant, 250,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('visual-rules')),
                matching: find.byType(Scrollable))
            .first);
    await tester.enterText(constant, '40');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-visual')));
    await tester.pumpAndSettle();
    expect(saved!.evaluate({'demand': 50}).outputs['power'], 60);
  });

  testWidgets(
      'narrow editor supports large text and invalid input without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: VisualEditorPage(
                model: comparisonModels()[2], portuguese: true))));
    await tester.enterText(find.byKey(const ValueKey('true-0-max')), '-1');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('apply-visual')))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('small screen keeps the editor usable above the keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(
        home: VisualEditorPage(
            model: comparisonModels().first, portuguese: true)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('rule builder adds and removes a composed rule', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: VisualEditorPage(
            model: comparisonModels().first, portuguese: false)));
    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
            of: find.byKey(const ValueKey('visual-rules')),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('add-rule')), 250,
        scrollable: scrollable);
    await tester.tap(find.byKey(const ValueKey('add-rule')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('condition-rule2-type')), -250,
        scrollable: scrollable);
    await tester.tap(find.byKey(const ValueKey('condition-rule2-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AND').last);
    await tester.pumpAndSettle();
    expect(find.text('Left condition'), findsOneWidget);
    expect(find.text('Right condition'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('delete-rule')), 250,
        scrollable: scrollable);
    await tester.tap(find.byKey(const ValueKey('delete-rule')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('apply-visual')))
            .onPressed,
        isNotNull);
  });

  testWidgets('edited scenario range stays valid when switching scenarios',
      (tester) async {
    await tester.pumpWidget(const FuzzyApp());
    await tester.tap(find.byKey(const ValueKey('edit-scenario')));
    await tester.pumpAndSettle();
    final inputList = find
        .descendant(
            of: find.byKey(const ValueKey('variables-true')),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('true-0-min')), 150,
        scrollable: inputList);
    await tester.enterText(find.byKey(const ValueKey('true-0-min')), '30');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-visual')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Irrigação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Climatização'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('temperature: 40.0'), 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('temperature: 40.0'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('inspect-scenario')), -150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('inspect-scenario')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('input-temperature')))
            .min,
        30);
    expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('input-temperature')))
            .value,
        40);
    expect(tester.takeException(), isNull);
  });
}
