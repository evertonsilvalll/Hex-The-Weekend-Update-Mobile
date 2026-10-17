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
remaining libraries in `scripts/setup-android.sh`. It installs SDK 30, build
tools 30.0.3 and NDK 21.4.7075529, then uses Java 8 for Lime's Gradle 5.6.3.
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
