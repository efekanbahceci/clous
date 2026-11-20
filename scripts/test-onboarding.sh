#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/SierraPort.app"
BUNDLE_ID="dev.sierraport.macos"

# Çalışan SierraPort örneğini kapat
pkill -x SierraPort 2>/dev/null || true

if [[ "${1:-}" == "--full" ]]; then
    # Tüm uygulama ayarlarını (tema, kısayol, profil, allowlist) sıfırla
    defaults delete "$BUNDLE_ID" 2>/dev/null || true
    echo "✓ Tüm SierraPort ayarları sıfırlandı (tam ilk kurulum modu)."
else
    # Yalnızca ilk kurulum sihirbazı bayrağını sıfırla
    defaults delete "$BUNDLE_ID" sierraport_setup_wizard_done_v2 2>/dev/null || true
    echo "✓ İlk kurulum sihirbazı sıfırlandı."
fi

# Uygulamayı başlat
open -n "$APP_BUNDLE"
echo "→ SierraPort ilk açılış ekranıyla başlatıldı."
