import 'dart:io';

/// CI gate before requesting publication credentials.
void main(List<String> args) {
  final version =
      RegExp(r'^version: ([0-9]+\.[0-9]+\.[0-9]+)$', multiLine: true)
          .firstMatch(File('pubspec.yaml').readAsStringSync())?[1];
  if (version == null || args.length != 1 || args.single != 'v$version') {
    throw StateError('Release tag must equal v<pubspec version>.');
  }
  if (!RegExp('^## ${RegExp.escape(version)}\\s*\$', multiLine: true)
      .hasMatch(File('CHANGELOG.md').readAsStringSync())) {
    throw StateError('Release version must have a changelog section.');
  }
}
