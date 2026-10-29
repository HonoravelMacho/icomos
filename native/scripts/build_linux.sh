#!/usr/bin/env bash
# build_linux.sh — compila libicomos_engine.so (Linux desktop)
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_DIR="icomos_engine/build-linux"
cmake -S icomos_engine -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release "$@"
cmake --build "$BUILD_DIR" -j"$(nproc)"

# copia para onde o app Flutter Linux procura
mkdir -p ../app/linux/lib && cp -f "$BUILD_DIR"/libicomos_engine.so* ../app/linux/lib/
echo ">> OK: $BUILD_DIR/libicomos_engine.so"
