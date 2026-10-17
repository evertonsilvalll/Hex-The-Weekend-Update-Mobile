# Android port

This port targets Android 5.0+ (API 21), with ARMv7 and ARM64 native libraries.
The APK uses the package `com.hexmod.weekend` and landscape orientation.
It is a debug-signed build for sideloading/testing, not a Play Store release.

## GitHub Actions

After the branch is pushed, **Actions → Android APK** builds automatically.
Pull requests touching the port also build. Once the workflow is on the default
branch, **Run workflow** is available for manual builds.
Download **Hex-Weekend-Android-debug** from a successful run's artifacts, unzip
it and install the APK on an Android device. Artifacts expire after 14 days.
No signing secrets are required. Debug keys can differ between runners; when
an update reports a signature conflict, uninstall the old test build first
(this deletes its local progress).

The workflow pins Haxe 4.2.5, Lime 7.9.0, OpenFL 9.1.0, Flixel 4.11.0 and the
remaining libraries in `scripts/setup-android.sh`, including hxcpp 4.3.2.
It installs SDK 30, build tools 30.0.3 and NDK 21.4.7075529, then uses Java 8 for Lime's Gradle 5.6.3.
SDK installation runs with Java 17. These legacy versions match this engine;
do not update individual libraries without rebuilding and testing the port.

## Local build

Install Haxe 4.2.5 with Neko, Java 8, and the Android SDK/NDK versions above.
Initialize your haxelib directory, then run from the repository root:

```bash
bash scripts/setup-android.sh
haxelib run lime config ANDROID_SETUP true
haxelib run lime config ANDROID_SDK /path/to/android-sdk
haxelib run lime config ANDROID_NDK_ROOT /path/to/android-sdk/ndk/21.4.7075529
haxelib run lime config JAVA_HOME /path/to/jdk8
HXCPP_COMPILE_THREADS=2 haxelib run lime build android -debug
```

Alternatively, export `ANDROID_SDK`, `ANDROID_NDK_ROOT` and `JAVA_HOME`, then
run `bash scripts/build-android.sh`. This compiles locally without GitHub Actions
or a GitHub account. It uses the same pinned libraries and debug signing.

The APK is under `export/debug/android/bin/app/build/outputs/apk/debug/`.
The renderer override described in the original README is now checked in at
`source/flixel/graphics/tile/FlxDrawQuadsItem.hx`; do not manually patch haxelib.

## Touch controls

- Bottom: LEFT, DOWN, UP, RIGHT; simultaneous touches and sustained notes work
  through the same keyboard input handlers as desktop.
- Top: BACK, OK, PAUSE (uses the configured pause binding), SKIP (Space).
- Held touch inputs release when the app loses focus, changes state/substate,
  or resizes. Slide between direction pads to change held notes.

## Scope and device checks

Android skips native desktop video cutscenes and the Cooling video visualizer.
Lua modcharts, Discord RPC, filesystem mod loading and StepMania import remain
exclusive to desktop. The built-in Haxe song/stage logic and packaged music,
charts, menu data and dialogue are retained. This is not full desktop feature
parity. Large textures/audio can require substantial RAM.

Before distributing a build, verify on real ARMv7/ARM64 devices:

1. Cold launch, title/menu navigation, back/confirm and saved progress.
2. Story and freeplay song loading, dialogue, skipped cutscene transitions.
3. Two/four-note chords, holds, sliding, pause/resume and retry/game over.
4. Background/foreground while holding a note (no stuck input).
5. Cooling without its visualizer, shaders/camera effects, audio sync and FPS.

A passing compile is not evidence of device performance or touch latency.

## Android opening/menu atlases

Android packages the generated atlases in `assets/android/` at the original
asset IDs. The desktop/web originals are unchanged. Transparent borders are
trimmed and frames repacked with one pixel of padding; logical frame sizes,
offsets, names, order and visible pixels are preserved. No image is downscaled.

The two title atlases require about 39.3 MiB of decoded RGBA data instead of
128.1 MiB. The main menu atlas uses about 24.4 MiB instead of 45.8 MiB. Each
generated texture fits within 4096x4096. These are bitmap sizes, not a measured
process-memory total or confirmation that a reported device crash is resolved.
Gameplay character atlases remain unchanged and can still require much more RAM.

To regenerate or verify, use Python 3.9+ and Pillow 11.3.0 in a local virtualenv:

```bash
python3 -m venv export/atlas-tools
export/atlas-tools/bin/pip install Pillow==11.3.0
export/atlas-tools/bin/python scripts/optimize-android-atlases.py
export/atlas-tools/bin/python scripts/optimize-android-atlases.py --verify
```

Generation verifies every frame against its original in logical sprite space,
including transparent margins and offsets. A normal Android build needs no
Python dependency because the generated assets are checked in.

## Startup regression check

Run `bash scripts/test-startup-bindings.sh` with the pinned Haxe/Neko libraries
installed. It exercises the real controls constructor with fresh, legacy,
custom and partial save data, before title-screen audio initialization.
Missing volume binding strings must receive defaults without replacing saved
custom bindings so the controls constructor never parses null key names.
Android also performs asset cleanup, state loading and transitions on the main
thread because those operations touch renderer resources. The loading screen
may pause briefly while preparing the next menu or song.

## Diagnostic startup launcher

The test APK opens a Java-only screen before loading Lime/SDL or the game.
Tap **Iniciar jogo** to launch. If the game closes, reopen the app, tap
**Copiar relatório**, and paste the report into the support conversation.
This is an investigation build, not confirmation that the device crash is fixed.

The report stays local until the user copies it. It includes the APK version,
device/Android version, supported ABIs, current process bitness, actual memory
page size, RAM totals, and the last completed startup checkpoint. Once Haxe
starts, it also records OpenGL renderer/version/maximum texture size and uncaught
OpenFL errors without suppressing their normal handling. Java loader errors
are saved before SDL displays its own error dialog.

On Android 11+, app-only process exit history may identify a native crash,
low-memory kill, Java exception or ANR. The latest exit can belong to an older
APK, so compare its timestamp with the recorded attempt. On Android 12+, when
the OS provides a native tombstone, a bounded decoder extracts the signal,
abort/cause and up to 12 frames from the crashing thread. It skips memory dumps,
logs and other threads. Missing or malformed traces are reported as unavailable;
there is no logcat permission or automatic upload. OS records and individual
checkpoints do not establish a root cause by themselves.

The ARM64 game library requests 16 KiB ELF load-segment alignment with the
pinned NDK. Verify the resulting ELF and all packaged native libraries after
building. This addresses a linker alignment deficiency; Android 16 alone does
not establish that a particular device uses 16 KiB pages, and alignment alone
does not establish complete runtime compatibility.

Run `bash scripts/test-tombstone-summary.sh` with Java 8+ to exercise synthetic
native reports, out-of-order fields, excluded threads, malformed input and size
limits. These host tests do not execute Android's launcher or native renderer.

## ARM64 garbage collector runtime

The native crash report from APK 2342 resolved to `BitmapData.__Mark` visiting
an invalid `__textureContext` pointer while an image allocation triggered GC.
The device reported 4 KiB pages and a working OpenGL context. This locates the
failure in managed-object traversal; it does not prove that `Title_Enter` is
corrupt or that Android killed the app for low memory.

The port now pins hxcpp **4.3.2**, which includes upstream fix
[e772513](https://github.com/HaxeFoundation/hxcpp/commit/e77251367c876b6bbe2d7117c6647d2b0bb8ec76):
use `setjmp` to capture ARM64 registers and keep the captured stack frame alive
until collection completes. hxcpp 4.2.1 predates both changes. Updating only a
compiler define would omit the stack-frame lifetime fix. Other Haxe/Lime/OpenFL
versions remain pinned. `AndroidStartup` also clears hxcpp's inferred 64-bit host
flag for ARMv7: Lime 7.9 supplies `HXCPP_ARMV7` without an explicit `HXCPP_M32`.
ARM64 retains its 64-bit compiler flags. Run setup again before rebuilding an
existing checkout.

`bash scripts/test-native-gc-roots.sh` builds a native host regression using the
pinned runtime's own `TestBigStack` fixture and the `setjmp` capture path used
on ARM64. It retains many recursive references
across allocations and forced collections, then checks their self-references.
The script sets low collection thresholds and uses bounded passes. A passing
host test and Android compile do not confirm that the device crash is fixed;
keep the diagnostic launcher and validate the updated APK on the affected phone.
