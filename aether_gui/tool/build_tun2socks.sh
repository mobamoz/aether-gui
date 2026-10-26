#!/usr/bin/env bash
# Builds hev-socks5-tunnel (tun2socks) for Android with the NDK preinstalled on GitHub runners.
# Set HEV_REF to a release tag to pin the version.
set -euo pipefail

NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
[ -n "$NDK" ] || { echo "ANDROID_NDK_HOME is not set" >&2; exit 1; }

ROOT=$(pwd)
W=$(mktemp -d)
mkdir -p "$W/jni"
git clone --recursive --shallow-submodules --depth 1 ${HEV_REF:+--branch "$HEV_REF"} \
  https://github.com/heiher/hev-socks5-tunnel "$W/jni/hev-socks5-tunnel"
echo 'include $(call all-subdir-makefiles)' > "$W/jni/Android.mk"

cd "$W"
"$NDK/ndk-build" NDK_PROJECT_PATH=. APP_BUILD_SCRIPT=jni/Android.mk \
  APP_ABI="arm64-v8a armeabi-v7a" APP_PLATFORM=android-24 NDK_LIBS_OUT="$W/libs" -j"$(nproc)"

for abi in arm64-v8a armeabi-v7a; do
  mkdir -p "$ROOT/android/app/src/main/jniLibs/$abi"
  cp "$W/libs/$abi/libhev-socks5-tunnel.so" "$ROOT/android/app/src/main/jniLibs/$abi/"
done
echo "tun2socks built"
