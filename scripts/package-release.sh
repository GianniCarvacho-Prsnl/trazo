#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--skip-build" ) ]]; then
    printf 'Uso: bash scripts/package-release.sh [--skip-build]\n' >&2
    exit 1
fi
if [[ "${1:-}" != "--skip-build" ]]; then
    bash scripts/build-app.sh
fi

APP_DIR="$PROJECT_DIR/build/Trazo.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
BUILT_VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")
if [[ "$VERSION" != "$BUILT_VERSION" ]]; then
    printf 'La versión compilada no coincide con Resources/Info.plist. Vuelve a compilar.\n' >&2
    exit 1
fi
ARCHITECTURES=$(lipo -archs "$APP_DIR/Contents/MacOS/Trazo")
case "$ARCHITECTURES" in
    arm64) ARCHITECTURE=arm64 ;;
    x86_64) ARCHITECTURE=x86_64 ;;
    "arm64 x86_64"|"x86_64 arm64") ARCHITECTURE=universal ;;
    *) printf 'Arquitectura no reconocida: %s\n' "$ARCHITECTURES" >&2; exit 1 ;;
esac

codesign --verify --deep --strict "$APP_DIR"
RELEASE_DIR="$PROJECT_DIR/build/releases"
mkdir -p "$RELEASE_DIR"
ARCHIVE_NAME="Trazo-v${VERSION}-macos-${ARCHITECTURE}.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$RELEASE_DIR/$ARCHIVE_NAME"
cd "$RELEASE_DIR"
shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
printf '\nRelease preparada:\n%s\n%s\n' "$RELEASE_DIR/$ARCHIVE_NAME" "$RELEASE_DIR/$ARCHIVE_NAME.sha256"
