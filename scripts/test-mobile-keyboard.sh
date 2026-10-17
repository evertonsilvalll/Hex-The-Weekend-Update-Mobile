#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(mktemp -d /tmp/hex-mobile-keyboard.XXXXXX)"
trap 'rm -rf "$test_dir"' EXIT
# Neko exercises the same !web native key correction as Android without a window.
haxelib run lime display android -debug | sed \
  -e '/^-main /d' -e '/^-cpp /d' -e '/^-D android/d' \
  -e '/^--macro keep("Main")/d' > "$test_dir/keyboard.hxml"
haxe "$test_dir/keyboard.hxml" -D disable_cffi -D FLX_NO_DEBUG -cp tests -main MobileKeyboardEventTest -neko "$test_dir/keyboard.n"
neko "$test_dir/keyboard.n"
