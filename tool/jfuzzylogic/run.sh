#!/usr/bin/env bash
# Build the pinned upstream test dependency outside the Dart package.
set -euo pipefail
cd "$(dirname "$0")/../.."
JFUZZY_TEMP=$(mktemp -d)
trap 'rm -rf "$JFUZZY_TEMP"' EXIT
JFUZZY_COMMIT=1f421d1b176b39cd7d08fa8f4d712d733abf1116
JFUZZY_SHA=7a30a415f48be4c679c25871e03507a475dddaccfdd5a9d3d46695171cc488a0
curl --fail --location --retry 3 "https://codeload.github.com/pcingola/jFuzzyLogic/zip/$JFUZZY_COMMIT" -o "$JFUZZY_TEMP/source.zip"
if command -v sha256sum >/dev/null; then
  JFUZZY_ACTUAL=$(sha256sum "$JFUZZY_TEMP/source.zip" | cut -d ' ' -f 1)
else
  JFUZZY_ACTUAL=$(shasum -a 256 "$JFUZZY_TEMP/source.zip" | cut -d ' ' -f 1)
fi
if [ "$JFUZZY_ACTUAL" != "$JFUZZY_SHA" ]; then
  echo 'jFuzzyLogic archive checksum mismatch.' >&2
  exit 1
fi
unzip -q "$JFUZZY_TEMP/source.zip" -d "$JFUZZY_TEMP"
JFUZZY_SOURCE="$JFUZZY_TEMP/jFuzzyLogic-$JFUZZY_COMMIT"
mkdir "$JFUZZY_TEMP/classes"
find "$JFUZZY_SOURCE/src" -name '*.java' > "$JFUZZY_TEMP/sources.txt"
"${JFUZZY_JAVAC:-javac}" --release 8 -cp "$JFUZZY_SOURCE/lib/*" -d "$JFUZZY_TEMP/classes" @"$JFUZZY_TEMP/sources.txt"
JFUZZY_CP="$JFUZZY_TEMP/classes:$JFUZZY_SOURCE/lib/*"
"${JFUZZY_JAVAC:-javac}" --release 8 -cp "$JFUZZY_CP" -d "$JFUZZY_TEMP/classes" tool/jfuzzylogic/FclProbe.java
dart run tool/export_fcl_cases.dart > "$JFUZZY_TEMP/cases.json"
JFUZZY_ARGS=("$JFUZZY_TEMP/cases.json" "${JFUZZY_JAVA:-java}" "$JFUZZY_CP")
if [ -n "${JFUZZY_REFERENCE_OUT:-}" ]; then
  JFUZZY_ARGS+=("$JFUZZY_REFERENCE_OUT")
fi
python3 tool/jfuzzylogic/compare.py "${JFUZZY_ARGS[@]}"
