#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(mktemp -d /tmp/hex-mobile-controls.XXXXXX)"
trap 'rm -rf "$test_dir"' EXIT
# Isolate the pure input model from source/import.hx's game-wide asset imports.
cp source/MobileTouchModel.hx "$test_dir/"
haxe -cp "$test_dir" -cp tests -main MobileTouchModelTest --interp
# Exercise persistence calls against the project's actual FlxSave API on Neko.
haxelib run lime display android -debug | sed \
  -e '/^-main /d' -e '/^-cpp /d' -e '/^-D android/d' \
  -e '/^--macro keep("Main")/d' > "$test_dir/settings.hxml"
haxe "$test_dir/settings.hxml" -D disable_cffi -cp tests -main MobileControlSettingsTest -neko "$test_dir/settings.n"
neko "$test_dir/settings.n"
