#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="SierraPort"
VERSION="${1:-0.2.0}"
VERSION="${VERSION#v}"
BUILD_NUM="${2:-$(date +%Y%m%d%H)}"
UPDATE_REPO="${UPDATE_REPO:-efekanbahceci/SierraPort}"

DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/${APP_NAME}.app"
DMG_PATH="$DIST_DIR/${APP_NAME}.dmg"
ZIP_PATH="$DIST_DIR/${APP_NAME}.zip"
CHECKSUM_PATH="$DIST_DIR/checksums.txt"

echo "==> Packaging ${APP_NAME} v${VERSION} (build ${BUILD_NUM}) for ${UPDATE_REPO}..."

# 1. Build standalone .app bundle with embedded version + update repo
APP_VERSION="$VERSION" APP_BUILD="$BUILD_NUM" UPDATE_REPO="$UPDATE_REPO" \
    "$ROOT_DIR/scripts/build-macos-app.sh"

# 2. Create .zip archive for instant in-app Restart Update
echo "==> Creating ${APP_NAME}.zip (for automatic in-app Restart Update)..."
rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

# 3. Create drag-to-Applications .dmg for website Download button
echo "==> Creating ${APP_NAME}.dmg (for website Download button)..."
rm -f "$DMG_PATH"
DMG_STAGE="$(mktemp -d)"
trap 'rm -rf "$DMG_STAGE"' EXIT
/usr/bin/ditto "$APP_BUNDLE" "$DMG_STAGE/${APP_NAME}.app"
ln -s /Applications "$DMG_STAGE/Applications"

/usr/bin/hdiutil create \
    -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

# 4. Generate SHA-256 checksums for cryptographic verification by UpdateManager
echo "==> Generating SHA-256 checksums..."
(
    cd "$DIST_DIR"
    /usr/bin/shasum -a 256 "${APP_NAME}.dmg" "${APP_NAME}.zip" > "$CHECKSUM_PATH"
)

echo ""
echo "✓ Release artifacts ready for v${VERSION}:"
echo "  • DMG (Website Download): $DMG_PATH"
echo "  • ZIP (In-App Update)   : $ZIP_PATH"
echo "  • SHA-256 Checksums     : $CHECKSUM_PATH"
echo ""
echo "Publish to GitHub Releases (triggers 'Restart Update' in all installed apps):"
echo "  gh release create \"v${VERSION}\" \"$DMG_PATH\" \"$ZIP_PATH\" \"$CHECKSUM_PATH\" \\"
echo "    --repo \"${UPDATE_REPO}\" \\"
echo "    --title \"${APP_NAME} v${VERSION}\" \\"
echo "    --generate-notes"
echo ""
echo "Permanent Website Download URL (always serves the latest DMG):"
echo "  https://github.com/${UPDATE_REPO}/releases/latest/download/${APP_NAME}.dmg"
