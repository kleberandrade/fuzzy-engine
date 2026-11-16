#!/usr/bin/env bash
# Validate the release locally. This script never uploads the package.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v dart >/dev/null
command -v flutter >/dev/null

dart pub get --no-example
dart format --output=none --set-exit-if-changed lib test example benchmark
dart analyze --fatal-infos
dart test
dart doc
(
  cd example
  flutter pub get
  flutter analyze --no-pub
  flutter test --no-pub
  flutter build web --no-pub
)
flutter pub get
flutter pub publish --dry-run

echo 'Release checks passed. No package was uploaded.'
echo 'Review the dry-run file list and CI before running: flutter pub publish'
