#!/bin/bash

# Kullanıcı CTRL+C (durdurma) tuşuna bastığında arka plandaki tüm işlemleri (tunnel dahil) kapat
trap 'echo -e "\n🛑 Sistem kapatılıyor..."; kill $(jobs -p) 2>/dev/null; exit' INT TERM EXIT

echo "======================================================="
echo "🚀 Clous Geliştirici Ortamı Başlatılıyor..."
echo "======================================================="

# Arka planda gizlice 3 saniye bekleyip tüneli çalıştıracak bir zamanlayıcı başlatıyoruz
(
  sleep 3
  echo -e "\n🌐 Next.js hazırlandı! Cloudflare Tunnel aktif ediliyor (clous.dev)...\n"
  cloudflared tunnel --url http://localhost:3000 --http-host-header clous.dev run clous
) &

echo "⚡ Next.js sunucusu başlatılıyor..."
# Next.js her zamanki gibi ön planda (ana ekranda) çalışmaya devam etsin
pnpm --filter web run dev
