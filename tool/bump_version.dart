import 'dart:io';
import 'versioning.dart';

/// Run from repository root after writing Unreleased notes. Never commits or tags.
void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/bump_version.dart patch|minor|major');
    exitCode = 64;
    return;
  }
  final spec = File('pubspec.yaml');
  final changelog = File('CHANGELOG.md');
  final result = prepareRelease(
      spec.readAsStringSync(), changelog.readAsStringSync(), args.single);
  spec.writeAsStringSync(result.pubspec);
  changelog.writeAsStringSync(result.changelog);
  stdout.writeln(
      'Prepared ${result.version}. Review, commit and push v${result.version} to publish after CI.');
}
