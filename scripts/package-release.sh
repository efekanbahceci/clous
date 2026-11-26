#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Clous"
VERSION="${1:-0.2.0}"
VERSION="${VERSION#v}"
BUILD_NUM="${2:-$(date +%Y%m%d%H)}"
UPDATE_REPO="${UPDATE_REPO:-efekanbahceci/clous}"

DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/${APP_NAME}.app"
DMG_PATH="$DIST_DIR/${APP_NAME}.dmg"
ZIP_PATH="$DIST_DIR/${APP_NAME}.zip"
CHECKSUM_PATH="$DIST_DIR/checksums.txt"
DMG_BG="$ROOT_DIR/assets/dmg-background.png"
VOLUME_ICON="$ROOT_DIR/assets/AppIcon.icns"

echo "==> Packaging ${APP_NAME} v${VERSION} (build ${BUILD_NUM}) for ${UPDATE_REPO}..."

# 1. Build & seal standalone .app bundle with embedded version + update repo
APP_VERSION="$VERSION" APP_BUILD="$BUILD_NUM" UPDATE_REPO="$UPDATE_REPO" \
    "$ROOT_DIR/scripts/build-macos-app.sh"

# 2. Create .zip archive for instant in-app Restart Update
echo "==> Creating ${APP_NAME}.zip (for automatic in-app Restart Update)..."
rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

# 3. Create custom-designed drag-to-Applications .dmg for website Download button
echo "==> Creating branded ${APP_NAME}.dmg installer window..."
rm -f "$DMG_PATH"
DMG_STAGE="$(mktemp -d)"
RW_DMG="$(mktemp -u /tmp/clous-rw-XXXXXX).dmg"
MOUNT_DIR=""

cleanup() {
    if [ -n "$MOUNT_DIR" ] && [ -d "$MOUNT_DIR" ]; then
        /usr/bin/hdiutil detach "$MOUNT_DIR" -force -quiet 2>/dev/null || true
    fi
    rm -rf "$DMG_STAGE" "$RW_DMG"
}
trap cleanup EXIT

/usr/bin/ditto "$APP_BUNDLE" "$DMG_STAGE/${APP_NAME}.app"
ln -s /Applications "$DMG_STAGE/Applications"

if [ -f "$DMG_BG" ]; then
    mkdir -p "$DMG_STAGE/.background"
    cp "$DMG_BG" "$DMG_STAGE/.background/background.png"
fi

if [ -f "$VOLUME_ICON" ]; then
    cp "$VOLUME_ICON" "$DMG_STAGE/.VolumeIcon.icns"
fi

VOL_NAME="${APP_NAME}"

# Create temporary writable DMG with headroom for Finder .DS_Store layout
/usr/bin/hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    -size 48m \
    "$RW_DMG" >/dev/null

# Attach writable DMG and style the Finder installer window
MOUNT_DIR="/Volumes/${VOL_NAME}"
if [ -d "$MOUNT_DIR" ]; then
    /usr/bin/hdiutil detach "$MOUNT_DIR" -force -quiet 2>/dev/null || true
fi

/usr/bin/hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR" "$RW_DMG" >/dev/null

# Mark custom volume icon flag if SetFile is available
if [ -f "$MOUNT_DIR/.VolumeIcon.icns" ] && command -v SetFile >/dev/null 2>&1; then
    SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
fi

# Apply Finder window bounds, hidden chrome, Retina background, and centered icon coordinates
if [ -f "$MOUNT_DIR/.background/background.png" ]; then
    /usr/bin/osascript <<EOF || true
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {220, 160, 880, 580}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 116
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.png"
        set position of item "${APP_NAME}.app" of container window to {180, 206}
        set position of item "Applications" of container window to {480, 206}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
fi

chmod -Rf go-w "$MOUNT_DIR" 2>/dev/null || true
sync
/usr/bin/hdiutil detach "$MOUNT_DIR" -quiet
MOUNT_DIR=""

# Convert to compressed read-only UDZO DMG
/usr/bin/hdiutil convert "$RW_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" >/dev/null

# 4. Generate SHA-256 checksums, unlimited-CDN latest.json, and Homebrew Cask (Casks/clous.rb)
echo "==> Generating SHA-256 checksums, latest.json, and Homebrew Casks/clous.rb..."
DMG_SHA256="$(/usr/bin/shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
ZIP_SHA256="$(/usr/bin/shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

(
    cd "$DIST_DIR"
    /usr/bin/shasum -a 256 "${APP_NAME}.dmg" "${APP_NAME}.zip" > "$CHECKSUM_PATH"
)

LATEST_JSON_PATH="$DIST_DIR/latest.json"
cat > "$LATEST_JSON_PATH" << EOF
{
  "version": "${VERSION}",
  "tag": "v${VERSION}",
  "name": "${APP_NAME} v${VERSION}",
  "zip_url": "https://github.com/${UPDATE_REPO}/releases/download/v${VERSION}/${APP_NAME}.zip",
  "dmg_url": "https://github.com/${UPDATE_REPO}/releases/download/v${VERSION}/${APP_NAME}.dmg",
  "zip_sha256": "${ZIP_SHA256}",
  "dmg_sha256": "${DMG_SHA256}",
  "release_url": "https://github.com/${UPDATE_REPO}/releases/tag/v${VERSION}"
}
EOF

CASK_DIR="$DIST_DIR/Casks"
CASK_PATH="$CASK_DIR/clous.rb"
mkdir -p "$CASK_DIR"
cat > "$CASK_PATH" << EOF
cask "clous" do
  version "${VERSION}"
  sha256 "${DMG_SHA256}"

  url "https://github.com/${UPDATE_REPO}/releases/download/v#{version}/${APP_NAME}.dmg"
  name "${APP_NAME}"
  desc "Zero-dependency Rust port monitor, security auditor, and forensic inspector"
  homepage "https://github.com/${UPDATE_REPO}"

  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  app "${APP_NAME}.app"
  binary "#{appdir}/${APP_NAME}.app/Contents/Resources/sierraport", target: "clous"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/${APP_NAME}.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Preferences/dev.clous.macos.plist",
  ]
end
EOF

INSTALL_SH_PATH="$DIST_DIR/install.sh"
cp "$ROOT_DIR/scripts/install.sh" "$INSTALL_SH_PATH"
chmod +x "$INSTALL_SH_PATH"

echo ""
echo "✓ Branded release artifacts ready for v${VERSION}:"
echo "  • DMG (Website Installer)     : $DMG_PATH"
echo "  • ZIP (In-App Restart Update) : $ZIP_PATH"
echo "  • CDN Manifest (No Rate Limit): $LATEST_JSON_PATH"
echo "  • One-Line Curl Installer     : $INSTALL_SH_PATH"
echo "  • SHA-256 Checksums           : $CHECKSUM_PATH"
echo "  • Homebrew Tap Cask           : $CASK_PATH"
echo ""
echo "Upload these 5 files to GitHub Release v${VERSION}:"
echo "  Clous.dmg · Clous.zip · latest.json · install.sh · checksums.txt"
echo ""
echo "Permanent Website Download URL:"
echo "  https://github.com/${UPDATE_REPO}/releases/latest/download/${APP_NAME}.dmg"
echo ""
echo "One-Line Curl Install Command:"
echo "  curl -fsSL https://github.com/${UPDATE_REPO}/releases/latest/download/install.sh | bash"
echo ""
echo "Homebrew Tap Install Command (after pushing dist/Casks/clous.rb to efekanbahceci/homebrew-tap):"
echo "  brew install --cask efekanbahceci/tap/clous"
