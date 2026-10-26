#!/usr/bin/env bash
# Downloads the official prebuilt Android binaries of Aether, verifies SHA-256,
# and packs them as libaether.so so Android lets the app execute them.
set -euo pipefail

BASE="https://github.com/CluvexStudio/Aether/releases/latest/download"
OUT=android/app/src/main/jniLibs
TMP=$(mktemp -d)

for pair in "arm64:arm64-v8a" "armv7:armeabi-v7a"; do
  name=${pair%%:*}; abi=${pair##*:}
  tarball="aether-android-$name.tar.gz"
  curl -fsSL "$BASE/$tarball" -o "$TMP/$tarball"
  curl -fsSL "$BASE/$tarball.sha256" -o "$TMP/$tarball.sha256"

  expected=$(awk '{print $1}' "$TMP/$tarball.sha256")
  actual=$(sha256sum "$TMP/$tarball" | awk '{print $1}')
  [ "$expected" = "$actual" ] || { echo "Checksum mismatch for $tarball" >&2; exit 1; }

  mkdir -p "$TMP/$name" "$OUT/$abi"
  tar -xzf "$TMP/$tarball" -C "$TMP/$name"
  bin=$(find "$TMP/$name" -type f -name 'aether' | head -n1)
  [ -n "$bin" ] || { echo "aether binary not found inside $tarball" >&2; exit 1; }
  cp "$bin" "$OUT/$abi/libaether.so"
  chmod 755 "$OUT/$abi/libaether.so"
  echo "packed $abi"
done
