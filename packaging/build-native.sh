#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIRECTORY="$PROJECT_ROOT/build/native"
INSTALL_DIRECTORY="$PROJECT_ROOT/src/poptools/native"
CONFIGURATION="${1:-Release}"

command -v cmake >/dev/null 2>&1 || {
    echo "CMake was not found. Install CMake and a Qt 6.10+ C++ SDK compatible with PySide6." >&2
    exit 1
}

QT_PREFIX="${QT_ROOT_DIR:-}"
if [[ -z "$QT_PREFIX" ]]; then
    QMAKE="$(command -v qmake6 || command -v qmake || true)"
    [[ -n "$QMAKE" ]] && QT_PREFIX="$($QMAKE -query QT_INSTALL_PREFIX)"
fi
[[ -n "$QT_PREFIX" ]] || {
    echo "Qt 6 C++ SDK was not found. Set QT_ROOT_DIR or add qmake to PATH." >&2
    exit 1
}

mkdir -p "$BUILD_DIRECTORY" "$INSTALL_DIRECTORY"
cmake -S "$PROJECT_ROOT/native" -B "$BUILD_DIRECTORY" \
    -DCMAKE_BUILD_TYPE="$CONFIGURATION" \
    -DCMAKE_PREFIX_PATH="$QT_PREFIX"
cmake --build "$BUILD_DIRECTORY" --config "$CONFIGURATION" --parallel
ctest --test-dir "$BUILD_DIRECTORY" --build-config "$CONFIGURATION" --output-on-failure
cmake --install "$BUILD_DIRECTORY" --config "$CONFIGURATION" --prefix "$INSTALL_DIRECTORY"

echo "Native terminal installed at $INSTALL_DIRECTORY"
