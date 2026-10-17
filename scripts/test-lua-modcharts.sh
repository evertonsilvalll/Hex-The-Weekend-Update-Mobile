#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Linux host test for the same LuaJIT binding linked into the Android build.
test_dir="$(mktemp -d /tmp/hex-lua-test.XXXXXX)"
trap 'rm -rf "$test_dir"' EXIT
cp source/LuaAssetLoader.hx tests/LuaAssetLoaderTest.hx "$test_dir/"
haxe -cp "$test_dir" -lib linc_luajit -main LuaAssetLoaderTest \
  -cpp "$test_dir/build" -D HXCPP_M64
"$test_dir/build/LuaAssetLoaderTest"
lua_library=""
while IFS= read -r candidate; do
  if [[ -f "$candidate/lib/lua/lib/Linux64/libluajit.a" ]]; then
    lua_library="$candidate"
    break
  fi
done < <(haxelib path linc_luajit)
: "${lua_library:?Install the pinned linc_luajit from setup-android.sh}"
cc -I "$lua_library/lib/lua/src" tests/lua-runner.c \
  "$lua_library/lib/lua/lib/Linux64/libluajit.a" -lm -ldl -o "$test_dir/lua-runner"
"$test_dir/lua-runner" tests/detected-modchart.lua
