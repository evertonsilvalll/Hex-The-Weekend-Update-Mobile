#!/usr/bin/env bash
set -euo pipefail

# Set these paths to installed toolchains; no GitHub account or CI is needed.
: "${ANDROID_SDK:?Set ANDROID_SDK to the Android SDK directory}"
: "${ANDROID_NDK_ROOT:?Set ANDROID_NDK_ROOT to NDK 21.4.7075529}"
: "${JAVA_HOME:?Set JAVA_HOME to a Java 8 JDK directory}"
export ANDROID_SETUP=true
export HXCPP_COMPILE_THREADS="${HXCPP_COMPILE_THREADS:-2}"

cd "$(dirname "$0")/.."
haxelib run lime build android -debug
