import 'package:test/test.dart';
import '../versioning.dart';

void main() {
  const spec =
      'name: fuzzy_engine\nversion: 0.1.9\nenvironment:\n  sdk: ">=3.3.0 <4.0.0"\n';
  const log =
      '## Unreleased\n\n- Fix interpolation.\n\n## 0.1.9\n\n- Previous release.\n';
  for (final entry
      in {'patch': '0.1.10', 'minor': '0.2.0', 'major': '1.0.0'}.entries) {
    test('${entry.key} moves pending notes and preserves previous release', () {
      final result = prepareRelease(spec, log, entry.key);
      expect(result.version, entry.value);
      expect(result.pubspec, contains('version: ${entry.value}\nenvironment:'));
      expect(
          result.changelog,
          startsWith(
              '## Unreleased\n\n## ${entry.value}\n\n- Fix interpolation.'));
      expect(result.changelog, contains('## 0.1.9\n\n- Previous release.'));
    });
  }
  test('refuses empty notes, prerelease source, duplicate and invalid bump',
      () {
    expect(
        () => prepareRelease(spec, '## Unreleased\n\n## 0.1.9\n- Old', 'patch'),
        throwsFormatException);
    expect(
        () => prepareRelease(
            spec.replaceFirst('0.1.9', '0.1.9-dev'), log, 'patch'),
        throwsFormatException);
    expect(() => prepareRelease(spec, '$log\n## 0.1.10\n- Existing', 'patch'),
        throwsFormatException);
    expect(() => prepareRelease(spec, log, 'automatic'), throwsArgumentError);
  });
}
