#!/usr/bin/env bash
set -euo pipefail

REPO="${CLOUS_REPO:-efekanbahceci/clous}"
APP_NAME="Clous"
ZIP_NAME="${APP_NAME}.zip"
LATEST_BASE="https://github.com/${REPO}/releases/latest/download"
ZIP_URL="${LATEST_BASE}/${ZIP_NAME}"
MANIFEST_URL="${LATEST_BASE}/latest.json"

echo "==> Installing ${APP_NAME} from github.com/${REPO}..."

if [ "$(uname -s)" != "Darwin" ]; then
    echo "Error: ${APP_NAME} desktop installer is for macOS only." >&2
    exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

EXPECTED_SHA=""
if /usr/bin/curl -fsSL "$MANIFEST_URL" -o "$WORK_DIR/latest.json" 2>/dev/null; then
    EXPECTED_SHA="$(/usr/bin/sed -n 's/.*"zip_sha256"[[:space:]]*:[[:space:]]*"\([0-9a-fA-F]\{64\}\)".*/\1/p' "$WORK_DIR/latest.json" | head -n 1)"
fi

echo "==> Downloading latest ${ZIP_NAME}..."
/usr/bin/curl -fSL --progress-bar "$ZIP_URL" -o "$WORK_DIR/$ZIP_NAME"

if [ -n "$EXPECTED_SHA" ]; then
    echo "==> Verifying SHA-256 checksum..."
    ACTUAL_SHA="$(/usr/bin/shasum -a 256 "$WORK_DIR/$ZIP_NAME" | awk '{print $1}')"
    if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
        echo "Error: SHA-256 mismatch! Expected $EXPECTED_SHA, got $ACTUAL_SHA." >&2
        exit 1
    fi
fi

echo "==> Extracting ${APP_NAME}.app..."
/usr/bin/ditto -x -k "$WORK_DIR/$ZIP_NAME" "$WORK_DIR/unpacked"

if [ ! -d "$WORK_DIR/unpacked/${APP_NAME}.app" ]; then
    echo "Error: ${APP_NAME}.app not found inside archive." >&2
    exit 1
fi

INSTALL_DIR="/Applications"
if [ ! -w "$INSTALL_DIR" ]; then
    INSTALL_DIR="$HOME/Applications"
    mkdir -p "$INSTALL_DIR"
fi

TARGET_APP="$INSTALL_DIR/${APP_NAME}.app"
echo "==> Installing to ${TARGET_APP}..."
/usr/bin/pkill -x "${APP_NAME}" 2>/dev/null || true
rm -rf "$TARGET_APP"
/usr/bin/ditto "$WORK_DIR/unpacked/${APP_NAME}.app" "$TARGET_APP"
/usr/bin/xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

# Link CLI binary as `clous` if a standard bin dir is writable
CLI_SRC="$TARGET_APP/Contents/Resources/sierraport"
CLI_LINKED=""
for BIN_DIR in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
    if [ -d "$BIN_DIR" ] && [ -w "$BIN_DIR" ]; then
        ln -sf "$CLI_SRC" "$BIN_DIR/clous"
        CLI_LINKED="$BIN_DIR/clous"
        break
    fi
done

echo ""
echo "✓ ${APP_NAME} installed successfully!"
echo "  • App : ${TARGET_APP}"
if [ -n "$CLI_LINKED" ]; then
    echo "  • CLI : ${CLI_LINKED}"
fi
echo ""
echo "Launch with:"
echo "  open \"${TARGET_APP}\""
