#!/usr/bin/env bash
set -euo pipefail

# Keep this legacy Kade Engine source on its compatible HaxeFlixel API.
haxelib install lime 7.9.0 --quiet
haxelib install openfl 9.1.0 --quiet
haxelib install flixel 4.11.0 --quiet
haxelib install flixel-addons 2.11.0 --quiet
haxelib install flixel-ui 2.4.0 --quiet
haxelib install hscript 2.4.0 --quiet
haxelib install actuate 1.9.0 --quiet
haxelib install hxcpp 4.3.2 --quiet

# Android-capable LuaJIT binding, pinned for reproducible native libraries.
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit.git daf0664aee99aa8b8d6bdd1eda993a1c3a399067

# Transitive installs may change the selected versions: select them explicitly.
haxelib set lime 7.9.0
haxelib set openfl 9.1.0
haxelib set flixel 4.11.0
haxelib set flixel-addons 2.11.0
haxelib set flixel-ui 2.4.0
haxelib set hscript 2.4.0
haxelib set actuate 1.9.0
haxelib set hxcpp 4.3.2
