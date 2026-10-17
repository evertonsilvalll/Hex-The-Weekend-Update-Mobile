#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

test_dir="$(mktemp -d /tmp/hex-gc-roots.XXXXXX)"
trap 'rm -rf "$test_dir"' EXIT
hxcpp_info="$(haxelib path hxcpp)"
hxcpp_path="$(awk '/^[^-]/ { print; exit }' <<< "$hxcpp_info")"
hxcpp_version="$(sed -n 's/^-D hxcpp=//p' <<< "$hxcpp_info")"
if [[ "$hxcpp_version" != "4.3.2" || ! -f "$hxcpp_path/test/haxe/gc/TestBigStack.hx" ]]; then
    printf 'Install the pinned hxcpp 4.3.2 runtime with scripts/setup-android.sh first.\n' >&2
    exit 1
fi
printf 'Testing hxcpp %s\n' "$hxcpp_version"
haxe -cp tests -cp "$hxcpp_path/test/haxe" -main NativeGcRootsTest \
    -cpp "$test_dir/native" -D HXCPP_GC_BIG_BLOCKS
HXCPP_MINIMUM_WORKING_MEMORY=1048576 \
HXCPP_MINIMUM_FREE_SPACE=1048576 \
HXCPP_TARGET_FREE_SPACE=1 "$test_dir/native/NativeGcRootsTest"
