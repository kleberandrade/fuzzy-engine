// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy_engine_example/main.dart';
import 'package:fuzzy_engine_example/app_settings.dart';

class MemoryPreferences implements PreferenceStore {
  final values = <String, String>{};
  @override
  String? read(String key) => values[key];
  @override
  void write(String key, String value) => values[key] = value;
}

Future<void> english(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('language-en')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Learn and language preserve the running input and persist preference',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryPreferences();
    await tester.pumpWidget(FuzzyApp(preferences: store));
    final slider = find.byType(Slider).first;
    await tester.scrollUntilVisible(slider, 200,
        scrollable: find.byType(Scrollable).first);
    tester.widget<Slider>(slider).onChanged!(32);
    await tester.pumpAndSettle();
    await english(tester);
    await tester.tap(find.byKey(const ValueKey('nav-learn')));
    await tester.pumpAndSettle();
    expect(find.text('From measurements to decisions'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-laboratory')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(slider, 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<Slider>(slider).value, 32);
    expect(store.values['fuzzy-lab.language'], 'en');
    expect(find.byTooltip('Português (Brasil)'), findsOneWidget);
    expect(find.byTooltip('English (United Kingdom)'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('language-en'))).width,
        greaterThanOrEqualTo(48));
    await tester.tap(find.byKey(const ValueKey('toggle-theme')));
    await tester.pumpAndSettle();
    expect(store.values['fuzzy-lab.theme'], 'light');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(FuzzyApp(preferences: store));
    await tester.pumpAndSettle();
    expect(find.text('Gradual decisions. Visible rules.'), findsOneWidget);
    expect(Theme.of(tester.element(find.byType(Lab))).brightness,
        Brightness.light);
  });
  testWidgets('examples run actual engines and open the matching preset',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(FuzzyApp(preferences: MemoryPreferences()));
    await english(tester);
    await tester.tap(find.byKey(const ValueKey('nav-examples')));
    await tester.pumpAndSettle();
    final open = find.byKey(const ValueKey('open-example-sugeno'));
    await tester.scrollUntilVisible(open, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.textContaining('power: 35.00'), findsOneWidget);
    expect(
        tester.widget<Slider>(find.byKey(const ValueKey('input-demand'))).value,
        25);
  });
  testWidgets(
      'phone navigation and keyboard keep draft values across language switch',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(FuzzyApp(preferences: MemoryPreferences()));
    await tester.tap(find.byKey(const ValueKey('nav-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aprender').last);
    await tester.pumpAndSettle();
    expect(find.text('De medições a decisões'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laboratório').last);
    await tester.pumpAndSettle();
    final edit = find.byKey(const ValueKey('edit-scenario'));
    await tester.scrollUntilVisible(edit, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    final min = find.byKey(const ValueKey('true-0-min'));
    await tester.scrollUntilVisible(min, 200,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('variables-true')),
                matching: find.byType(Scrollable))
            .first);
    await tester.enterText(min, '10');
    await tester.pumpAndSettle();
    await english(tester);
    expect(find.text('Visual model editor'), findsOneWidget);
    expect(
        tester
            .widget<EditableText>(
                find.descendant(of: min, matching: find.byType(EditableText)))
            .controller
            .text,
        '10');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'keyboard focus activates Learn and documentation follows the locale',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryPreferences()..values['fuzzy-lab.language'] = 'en';
    final links = <String>[];
    await tester
        .pumpWidget(FuzzyApp(preferences: store, onOpenLink: links.add));
    await tester.pumpAndSettle();
    bool learnFocused() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<TextButton>()
            ?.key ==
        const ValueKey('nav-learn');
    for (var i = 0; i < 15 && !learnFocused(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    expect(learnFocused(), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('From measurements to decisions'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('Formula:')), findsWidgets);
    semantics.dispose();
    await tester.tap(find.byKey(const ValueKey('nav-docs')));
    await tester.pumpAndSettle();
    expect(links.single, endsWith('guide.en.md'));
    await tester.tap(find.byKey(const ValueKey('language-pt-BR')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-docs')));
    await tester.pumpAndSettle();
    expect(links.last, endsWith('guide.pt-BR.md'));
    expect(find.text('De medições a decisões'), findsOneWidget);
  });
  testWidgets('JSON error feedback changes language without losing the draft',
      (tester) async {
    final store = MemoryPreferences()..values['fuzzy-lab.language'] = 'en';
    await tester.pumpWidget(FuzzyApp(preferences: store));
    await tester.pumpAndSettle();
    final open = find.byKey(const ValueKey('open-workbench'));
    await tester.scrollUntilVisible(open, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(open);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('configuration')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '{}');
    await tester.tap(find.text('Validate and load'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Invalid configuration'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('language-pt-BR')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Configuração inválida'), findsOneWidget);
    expect(find.textContaining('JSON inválido ou esquema não suportado'),
        findsOneWidget);
    expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '{}');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
