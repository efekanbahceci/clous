#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/Clous.app"
BUNDLE_ID="dev.clous.macos"

# Çalışan Clous örneğini kapat
pkill -x Clous 2>/dev/null || true

if [[ "${1:-}" == "--full" ]]; then
    # Tüm uygulama ayarlarını (tema, kısayol, profil, allowlist) sıfırla
    defaults delete "$BUNDLE_ID" 2>/dev/null || true
    echo "✓ Tüm Clous ayarları sıfırlandı (tam ilk kurulum modu)."
else
    # Yalnızca ilk kurulum sihirbazı bayrağını sıfırla
    defaults delete "$BUNDLE_ID" sierraport_setup_wizard_done_v2 2>/dev/null || true
    echo "✓ İlk kurulum sihirbazı sıfırlandı."
fi

# Uygulamayı başlat
open -n "$APP_BUNDLE"
echo "→ Clous ilk açılış ekranıyla başlatıldı."
