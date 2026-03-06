#!/usr/bin/env bash
# Test import_ozempic with each major analyzer version (6–11).
# Ensures analysis and tests work across analyzer releases.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OVERRIDES="$ROOT/pubspec_overrides.yaml"
OVERRIDES_BAK="$ROOT/pubspec_overrides.yaml.bak"

# One version per major branch supported by pubspec (>=6.0.0 <12.0.0).
# 6.x: pub get fails (_macros SDK dep). 7.x: API incompat (Element2, etc).
VERSIONS=(8.4.1 9.0.0 10.2.0 11.0.0)

restore_overrides() {
  if [[ -f "$OVERRIDES_BAK" ]]; then
    mv "$OVERRIDES_BAK" "$OVERRIDES"
  elif [[ -f "$OVERRIDES" ]]; then
    rm "$OVERRIDES"
  fi
}

trap restore_overrides EXIT

run_test() {
  local version=$1
  echo ""
  echo "========================================"
  echo "Testing analyzer $version"
  echo "========================================"

  # Write override pinning analyzer
  cat > "$OVERRIDES" << EOF
dependency_overrides:
  analyzer: "$version"
EOF

  # Resolve dependencies
  cd "$ROOT" && dart pub get

  # Analyze and run tests
  cd "$ROOT" && dart analyze --fatal-infos --fatal-warnings
  dart test

  echo "✓ analyzer $version: analyze and tests passed"
}

# Backup original overrides if present
if [[ -f "$OVERRIDES" ]]; then
  cp "$OVERRIDES" "$OVERRIDES_BAK"
fi

echo "Testing import_ozempic with analyzer versions: ${VERSIONS[*]}"
for v in "${VERSIONS[@]}"; do
  run_test "$v"
done

restore_overrides
trap - EXIT

echo ""
echo "All analyzer versions passed!"
