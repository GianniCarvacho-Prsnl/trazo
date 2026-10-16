#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/module-cache"

swift build -c release --disable-sandbox --cache-path .build/cache --config-path .build/configuration --security-path .build/security --manifest-cache local
APP_DIR="$PROJECT_DIR/build/Trazo.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp .build/release/Trazo "$APP_DIR/Contents/MacOS/Trazo"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
codesign --force --sign - --identifier dev.trazo.capture "$APP_DIR"
printf '\nAplicación creada: %s\n' "$APP_DIR"
