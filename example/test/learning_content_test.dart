import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzy_engine_example/learning_content.dart';

void main() {
  test(
      'learning sources, version, exercises and favicon match repository artifacts',
      () {
    expect(File('../pubspec.yaml').readAsStringSync(),
        contains('version: $engineVersion\n'));
    for (final lesson in lessons) {
      for (final locale in ['en', 'pt-BR']) {
        expect(File('../doc/${lesson.source}.$locale.md').existsSync(), isTrue);
      }
      expect(lesson.title.en, isNotEmpty);
      expect(lesson.title.pt, isNotEmpty);
      expect(lesson.explanation.en, isNot(lesson.explanation.pt));
    }
    expect(exercises, hasLength(5));
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync());
    expect(manifest['icons'][0]['src'], 'favicon.svg');
    expect(File('web/favicon.svg').readAsStringSync(),
        File('../doc/brand/fuzzy-mark.svg').readAsStringSync());
  });
  test(
      'every educational preset evaluates its documented inputs in the real core',
      () {
    for (final preset in LabPreset.values) {
      final launch = launchPreset(preset);
      final result = launch.model.evaluate(launch.values);
      expect(result.outputs, isNotEmpty);
      if (preset == LabPreset.uncovered)
        expect(result.outputs.values.single, isNull);
      else
        expect(result.outputs.values.every((v) => v != null && v.isFinite),
            isTrue);
    }
    final sugeno = launchPreset(LabPreset.sugeno);
    expect(sugeno.model.evaluate(sugeno.values).outputs['power'],
        closeTo(35, 1e-9));
    final tsukamoto = launchPreset(LabPreset.tsukamoto);
    expect(tsukamoto.model.evaluate(tsukamoto.values).outputs['power'],
        closeTo(25, 1e-9));
  });
}
