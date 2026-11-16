/// Pure release preparation, separate from filesystem and Git side effects.
({String pubspec, String changelog, String version}) prepareRelease(
    String pubspec, String changelog, String level) {
  if (!{'patch', 'minor', 'major'}.contains(level)) {
    throw ArgumentError('Choose patch, minor or major.');
  }
  final pattern =
      RegExp(r'^version: ([0-9]+)\.([0-9]+)\.([0-9]+)[ \t]*$', multiLine: true);
  final match = pattern.firstMatch(pubspec);
  if (match == null)
    throw FormatException('Expected a stable version in pubspec.yaml.');
  var major = int.parse(match[1]!);
  var minor = int.parse(match[2]!);
  var patch = int.parse(match[3]!);
  switch (level) {
    case 'major':
      major++;
      minor = 0;
      patch = 0;
    case 'minor':
      minor++;
      patch = 0;
    case 'patch':
      patch++;
  }
  final version = '$major.$minor.$patch';
  final section = RegExp(r'^## Unreleased\s*\n([\s\S]*?)(?=^## |$(?![\s\S]))',
          multiLine: true)
      .firstMatch(changelog);
  if (section == null ||
      !section[1]!.contains(RegExp(r'^- \S', multiLine: true))) {
    throw FormatException('Add release notes under ## Unreleased first.');
  }
  if (RegExp('^## ${RegExp.escape(version)}\\s*\$', multiLine: true)
      .hasMatch(changelog)) {
    throw FormatException('Version already occurs in changelog.');
  }
  return (
    pubspec: pubspec.replaceRange(match.start, match.end, 'version: $version'),
    changelog: changelog.replaceRange(section.start, section.end,
        '## Unreleased\n\n## $version\n\n${section[1]!.trim()}\n\n'),
    version: version,
  );
}
