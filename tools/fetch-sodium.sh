#!/usr/bin/env bash
# fetch-sodium.sh — compila libsodium 1.0.20 (fonte MIT oficial) sem root.
# Saída: third_party/sodium/<triplet>/include + lib/libsodium.a
# Nunca comitamos o binário (gitignore); o CI usa o pacote lib sodium-dev.
set -euo pipefail
cd "$(dirname "$0")/.."

SOD_VER="1.0.20"
TRIPLET="${1:-linux-$(uname -m)}"
OUT="third_party/sodium/${TRIPLET}"
BUILD_ROOT="$(mktemp -d)"
trap 'rm -rf "$BUILD_ROOT"' EXIT

echo ">> Baixando libsodium ${SOD_VER}..."
SRC_TGZ="$BUILD_ROOT/sod.tar.gz"
for URL in "https://download.libsodium.org/libsodium/releases/libsodium-${SOD_VER}-stable.tar.gz" \
           "https://github.com/jedisct1/libsodium/releases/download/${SOD_VER}-RELEASE/libsodium-${SOD_VER}.tar.gz"; do
  if curl -fsSL -o "$SRC_TGZ" "$URL"; then break; fi
done

echo ">> Extraindo e compilando (~1-3 min)..."
tar -zxf "$SRC_TGZ" -C "$BUILD_ROOT"
cd "$BUILD_ROOT"/libsodium-*
./configure --prefix="$BUILD_ROOT/install" \
  --disable-shared --enable-static --with-pic \
  CFLAGS="-O2 -fPIC" > /dev/null 2>&1
make -j"$(nproc)" > /dev/null 2>&1
make install > /dev/null 2>&1

cd -
rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"
mv "$BUILD_ROOT/install" "$OUT"

echo ">> OK: $OUT/lib/libsodium.a + $OUT/include/sodium.h"
