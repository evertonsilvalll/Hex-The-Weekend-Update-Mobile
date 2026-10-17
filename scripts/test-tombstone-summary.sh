#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_build="$(mktemp -d /tmp/hex-tombstone-test.XXXXXX)"
trap 'rm -rf "$test_build"' EXIT

if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/javac" ]]; then
    java_compiler="$JAVA_HOME/bin/javac"
    java_runner="$JAVA_HOME/bin/java"
else
    java_compiler="javac"
    java_runner="java"
fi

"$java_compiler" -source 8 -target 8 -encoding UTF-8 -d "$test_build" \
    "$repo_root/android/src/com/hexmod/weekend/TombstoneSummary.java" \
    "$repo_root/tests/TombstoneSummaryTest.java"
"$java_runner" -cp "$test_build" TombstoneSummaryTest
