#!/usr/bin/env bash
# fetch-gmp.sh — compila o GMP 6.3.0 (fonte oficial LGPL) sem root.
# Saída: third_party/gmp/<triplet>/include + lib/libgmp.a
# Nunca commitamos o binário (gitignore); o CI usa libgmp-dev do sistema.
set -euo pipefail
cd "$(dirname "$0")/.."

GMP_VER="6.3.0"
TRIPLET="${1:-$(uname -m)-$(uname | tr '[:upper:]' '[:lower:]')}"
OUT="third_party/gmp/${TRIPLET}"
BUILD_ROOT="$(mktemp -d)"
trap 'rm -rf "$BUILD_ROOT"' EXIT

echo ">> Baixando GMP ${GMP_VER}..."
for URL in "https://gmplib.org/download/gmp/gmp-${GMP_VER}.tar.xz" \
           "https://ftp.gnu.org/gnu/gmp/gmp-${GMP_VER}.tar.xz"; do
  if curl -fsSL -o "$BUILD_ROOT/gmp.tar.xz" "$URL"; then break; fi
done

echo ">> Extraindo e compilando (leva ~2-5 min)..."
tar -xf "$BUILD_ROOT/gmp.tar.xz" -C "$BUILD_ROOT"
cd "$BUILD_ROOT/gmp-${GMP_VER}"
./configure --prefix="$PWD/../../install" \
  --disable-shared --enable-static --with-pic --disable-assembly \
  CFLAGS="-O2 -fPIC" > /dev/null 2>&1
make -j"$(nproc)" > /dev/null 2>&1
make install > /dev/null 2>&1

cd -
rm -rf "$OUT"
mv "$BUILD_ROOT/install" "$OUT" 2>/dev/null || { echo "! falha no mv"; exit 1; }

echo ">> OK: $OUT/lib/libgmp.a + $OUT/include/gmp.h"
