#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(mktemp -d /tmp/hex-dialogue.XXXXXX)"
trap 'rm -rf "$test_dir"' EXIT
haxelib run lime display android -debug | sed \
  -e '/^-main /d' -e '/^-cpp /d' -e '/^-D android/d' \
  -e '/^--macro keep("Main")/d' > "$test_dir/test.hxml"
haxe "$test_dir/test.hxml" -D disable_cffi -cp tests -main HexDialogueTextTest -neko "$test_dir/test.n"
neko "$test_dir/test.n"
