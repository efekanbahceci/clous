#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="SierraPort"
BUNDLE_DIR="$ROOT_DIR/dist/${APP_NAME}.app"

echo "==> [1/3] Building Rust core binary (sierraport --release)..."
cd "$ROOT_DIR"
cargo build --release

echo "==> [2/3] Building native macOS SwiftUI app (SierraPortApp --release)..."
cd "$ROOT_DIR/macos/SierraPortApp"
if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi
swift build -c release

SWIFT_BIN="$ROOT_DIR/macos/SierraPortApp/.build/release/SierraPortApp"
RUST_BIN="$ROOT_DIR/target/release/sierraport"

echo "==> [3/3] Assembling ${BUNDLE_DIR}..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS" "$BUNDLE_DIR/Contents/Resources"

cp "$SWIFT_BIN" "$BUNDLE_DIR/Contents/MacOS/$APP_NAME"
cp "$RUST_BIN" "$BUNDLE_DIR/Contents/Resources/sierraport"
chmod +x "$BUNDLE_DIR/Contents/MacOS/$APP_NAME" "$BUNDLE_DIR/Contents/Resources/sierraport"

cat > "$BUNDLE_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>SierraPort</string>
    <key>CFBundleIdentifier</key>
    <string>dev.sierraport.macos</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SierraPort</string>
    <key>CFBundleDisplayName</key>
    <string>SierraPort</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo ""
echo "✓ Built standalone macOS app bundle:"
echo "  $BUNDLE_DIR"
echo ""
echo "Launch with:"
echo "  open \"$BUNDLE_DIR\""
