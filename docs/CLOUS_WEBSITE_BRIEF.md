# Clous — Web Sitesi İçerik & Veri Değiştirme Prompt'u (EN Primary + TR)

## AI Asistana Doğrudan Görev Talimatı / Direct Instructions for AI

Bu web sitesinin tasarımı, düzeni, renkleri ve fontları **zaten hazırdır**. Görevin yalnızca sitedeki mevcut yer tutucu (placeholder) veya rastgele yazılmış **tüm metinleri, başlıkları, kart/kutucuk içeriklerini, sayısal istatistikleri, tablo verilerini, kod/terminal örneklerini, SSS (FAQ) maddelerini, buton etiketlerini ve meta/SEO başlıklarını** aşağıda verilen **Clous** uygulamasına ait gerçek verilerle değiştirmektir.

### Kesin Kurallar / Strict Rules
1. **Tasarım, CSS, renk, font, spacing, animasyon, bileşen yapısı veya layout üzerinde HİÇBİR değişiklik yapma.** Yalnızca metin ve sayısal veri içeriklerini güncelle. *(Do NOT modify design, CSS, colors, fonts, spacing, animations, component structure, or layout — update text and numeric data ONLY.)*
2. **Sitenin ana dili İngilizce (EN) olacaktır.** Sitedeki tüm görünür içerikleri aşağıdaki **English (EN)** metinleriyle doldur. Eğer sitede Türkçe/İngilizce dil seçici (i18n) varsa, **Türkçe (TR)** karşılıklarını da birebir bağla.
3. Marka adını her yerde **Clous** (CLI komutlarında `clous`) olarak yaz.
4. Aşağıdaki sayısal verileri birebir kullan; uydurma veya abartılı yeni rakam ekleme.
5. Sitedeki mevcut kutucuk, kart veya sayaç sayısı aşağıdakinden az ya da fazlaysa, en önemli maddeleri seçerek mevcut yerleşimin karakter uzunluğuna (satır taşması olmayacak şekilde) uygun biçimde yerleştir.

---

## 1. Ürün Özeti / Product Overview

- **Brand Name:** Clous
- **Category (EN):** Real-Time Port Monitoring, Cryptographic Security Auditing & Forensic Process Inspection
- **Kategori (TR):** Gerçek Zamanlı Port İzleme, Kriptografik Güvenlik Denetimi ve Adli Süreç Analizi
- **Architecture:** Zero-dependency **Rust (Edition 2024)** CLI core + **Native macOS SwiftUI / AppKit** desktop app
- **Platforms:** CLI (`macOS`, `Linux`, `Windows`) · Desktop App (`macOS` — Apple Silicon & Intel native)
- **Privacy:** `100%` local & offline · Zero telemetry · No cloud dependency

---

## 2. Sayısal İstatistikler / Verified Metrics (KPI Cards & Counters)

Sitedeki tüm rastgele sayıları ve metrik kutucuklarını aşağıdaki doğrulanmış gerçek değerlerle değiştir:

| Value | Label (EN — Primary) | Short Description (EN) | Başlık (TR) | Kısa Açıklama (TR) |
|---|---|---|---|---|
| **`~30 ms`** | Instant Port Scan | Scans all active sockets in milliseconds | Anlık Port Taraması | Tüm aktif soketleri milisaniyeler içinde tarar |
| **`735 KB`** | Single Rust Binary | Sub-megabyte compiled native CLI core | Tek Dosya Rust CLI | 1 MB altında derlenmiş yüksek hızlı çekirdek |
| **`11 MB`** | Native macOS App | ~18x lighter than 200+ MB Electron tools | Native macOS Uygulaması | Electron tabanlı 200+ MB araçlara göre ~18x hafif |
| **`0`** | Zero Dependencies | Zero third-party crates or packages | Harici Bağımlılık | Hem Rust hem Swift tarafında sıfır 3. parti paket |
| **`500 ms`** | Real-Time Streaming | Configurable 500ms–5s live NDJSON telemetry | Canlı Telemetri Akışı | 500ms–5s ayarlanabilir anlık NDJSON akışı |
| **`0–100`** | Security Score | Full `codesign`, firewall & exposure audit in ~2s | Güvenlik Skoru | ~2 sn'de `codesign`, firewall ve maruziyet denetimi |
| **`12+`** | Core CLI Commands | 4 output formats (`table`, `json`, `csv`, `compact`) & CI/CD | CLI Komutu | 4 çıktı formatı ve CI/CD çıkış kapıları |
| **`100%`** | Local & Private | Zero telemetry — your data never leaves your machine | Lokal & Çevrimdışı | Sıfır telemetri, veriler makinenizden çıkmaz |
| **`13,201`** | Lines of Native Code | 5,900 lines Rust + 7,301 lines SwiftUI/AppKit | Satır Native Kod | 5.900 satır Rust + 7.301 satır SwiftUI/AppKit |

---

## 3. Hero Section Copy

### English (EN — Primary for Website)
- **Eyebrow Badge:** `735 KB Rust Core · 11 MB Native macOS · Zero Dependencies`
- **Headline (H1):** `See every port. Audit every risk. In 30 milliseconds.`
- **Alternative H1 (Dev-focused):** `Leave lsof behind. The new standard for port monitoring.`
- **Subtitle:** `Clous is a zero-dependency Rust CLI and native macOS desktop app for real-time port monitoring, cryptographic binary auditing, and forensic process inspection.`
- **Primary CTA:** `Download for macOS (11 MB)`
- **Secondary CTA:** `Explore CLI`
- **Trust Bar:** `100% Local Execution · Zero Telemetry · 0 External Dependencies · Apple Silicon Native · macOS, Linux & Windows`

### Türkçe (TR — Referans / Çoklu Dil Desteği İçin)
- **Üst Rozet:** `735 KB Rust Çekirdek · 11 MB Native macOS · Sıfır Bağımlılık`
- **Ana Başlık (H1):** `Portlarını gör. Riskleri yakala. Milisaniyeler içinde.`
- **Alternatif H1:** `lsof karmaşasına son. Port yönetiminde yeni standart.`
- **Alt Başlık:** `Clous; 735 KB saf Rust motoru ve native macOS arayüzüyle çalışan yeni nesil port izleme, kriptografik güvenlik denetimi ve süreç analiz aracıdır.`
- **Birincil CTA:** `macOS İçin İndir (11 MB)`
- **İkincil CTA:** `CLI Kurulumunu Gör`
- **Güven Şeridi:** `%100 Lokal Çalışır · Sıfır Telemetri · 0 Harici Bağımlılık · Apple Silicon Native · macOS, Linux & Windows`

---

## 4. Özellik Kartları / Feature Cards

### 1. Real-Time Port Streaming (`Live Watch`)
- **EN Title:** Real-Time Port Streaming & Live Charts
- **EN Body:** Scan every TCP/UDP and IPv4/IPv6 socket in `~30 ms`. Track opened and closed ports with live diff logs and interactive telemetry charts (`500ms–5s`).
- **TR Başlık:** Gerçek Zamanlı Port Akışı & Canlı Grafikler
- **TR Metin:** Tüm TCP/UDP ve IPv4/IPv6 soketlerini `~30 ms` içinde tarayın; açılan ve kapanan portları anlık fark (diff) günlüğü ve canlı grafiklerle (`500ms–5s`) izleyin.

### 2. Automated Security Audit (`0–100 Score`)
- **EN Title:** Cryptographic Binary & Exposure Auditing
- **EN Body:** Verify digital signatures (`codesign --verify --strict`), firewall posture, and `0.0.0.0` external exposure across every listener with `Standard`, `Strict`, and `Zero-Trust` profiles.
- **TR Başlık:** Otomatik Güvenlik Skoru ve Binary Doğrulama
- **TR Metin:** Dinleyen her sürecin dijital imzasını (`codesign --verify --strict`), güvenlik duvarı durumunu ve `0.0.0.0` maruziyetini `Standard`, `Strict` ve `Zero-Trust` profilleriyle puanlayın.

### 3. Forensic Process Inspector
- **EN Title:** One-Click Process Ancestry & Protocol Probe
- **EN Body:** Trace the full command line, parent process tree (PPID), memory footprint, active peer connections, and live HTTP/protocol banners behind any port in seconds.
- **TR Başlık:** Tek Tıkla Süreç Soy Ağacı ve Protokol Analizi
- **TR Metin:** Her portun arkasındaki sürecin tam komut satırını, üst süreç (PPID) soy ağacını, bellek kullanımını, eş bağlantılarını ve canlı HTTP/protokol başlıklarını saniyeler içinde inceleyin.

### 4. Native macOS & Global Quick Launcher
- **EN Title:** Keyboard-First Native macOS Experience
- **EN Body:** Built in pure SwiftUI with zero Electron bloat. Summon the system-wide Quick Launcher from anywhere, monitor live counts in the Menu Bar, and navigate 100% by keyboard (`⌘K`, `⌘1–4`, `Tab`, `⏎`).
- **TR Başlık:** Klavye Öncelikli Native macOS Deneyimi
- **TR Metin:** Electron ağırlığı olmadan saf SwiftUI ile geliştirildi. Sistem geneli kısayolla her ekrandan açılan Quick Launcher, Menü Çubuğu canlı durum göstergesi ve tam klavye navigasyonu (`⌘K`, `⌘1–4`, `Tab`, `⏎`).

### 5. Snapshot, Drift Detection & CI/CD Gates
- **EN Title:** Baseline Snapshots & Drift Prevention
- **EN Body:** Save expected port baselines (`snapshot save`), catch unauthorized drift (`diff --fail-on-drift`), and block risky exposures in CI/CD pipelines with `--strict` exit codes.
- **TR Başlık:** Anlık Görüntü & Port Kayması Tespiti (CI/CD)
- **TR Metin:** Beklenen port durumunu JSON olarak kaydedin (`snapshot save`), sapmaları yakalayın (`diff --fail-on-drift`) ve `--strict` çıkış kodlarıyla CI/CD hattınızda güvensiz portları engelleyin.

### 6. Zero Dependencies & Cross-Platform Core
- **EN Title:** Zero External Packages, Maximum Reliability
- **EN Body:** `0` third-party dependencies in both Rust and Swift. Reads `/proc/net/*` directly on Linux and native system APIs on macOS and Windows — eliminating supply-chain risk.
- **TR Başlık:** 0 Harici Paket, Maksimum Güvenilirlik
- **TR Metin:** Hem Rust hem Swift tarafında 0 harici paket içerir. Linux'ta doğrudan `/proc/net/*`, macOS ve Windows'ta yerel sistem araçlarıyla sıfır tedarik zinciri riskiyle çalışır.

---

## 5. Karşılaştırma Tablosu / Comparison Table ("Why Clous?")

### English (EN — Primary)
| Feature | Legacy (`lsof` / `netstat`) | Electron-Based Tools | **Clous** |
|---|---|---|---|
| **Binary / App Size** | System tool (no UI) | 150 – 300 MB | **735 KB CLI · 11 MB macOS App** |
| **Scan Latency** | Manual flags required | 200 – 800 ms | **~30 ms** |
| **External Dependencies** | Varies | Hundreds of packages | **0 Dependencies** |
| **Security & Signature Audit** | None | Limited or none | **0–100 Score + `codesign` + Zero-Trust** |
| **Live Stream & Drift** | None | Limited | **500 ms Stream + `snapshot` / `diff`** |
| **Desktop UX** | Raw terminal text | Heavy browser engine | **Native SwiftUI + Global Quick Launcher** |

### Türkçe (TR)
| Kriter | Geleneksel (`lsof` / `netstat`) | Electron Tabanlı Araçlar | **Clous** |
|---|---|---|---|
| **Boyut** | Sistem aracı (arayüz yok) | 150 – 300 MB | **735 KB CLI · 11 MB macOS App** |
| **Tarama Hızı** | Manuel bayrak gerektirir | 200 – 800 ms | **~30 ms** |
| **Harici Bağımlılık** | Değişken | Yüzlerce paket | **0 Bağımlılık** |
| **Güvenlik Denetimi** | Yok | Kısıtlı veya yok | **0–100 Skor + `codesign` + Zero-Trust** |
| **Canlı İzleme & Drift** | Yok | Kısıtlı | **500 ms Akış + `snapshot` / `diff`** |
| **Masaüstü Arayüzü** | Ham metin | Ağır tarayıcı motoru | **Native SwiftUI + Global Quick Launcher** |

---

## 6. Terminal / Kod Bloğu Örnekleri / CLI Showcase

### English (EN — Primary)
```bash
# List externally exposed listening ports in ~30 ms
clous list --exposed

# Run a 0-100 security audit with strict binary signature verification
clous audit --strict

# Inspect process ancestry, peers, and live HTTP banner on port 3000
clous inspect 3000 --probe

# Real-time port monitoring with 500ms refresh and open/close diff log
clous watch -i 500

# Save a baseline snapshot and fail CI if port drift is detected
clous snapshot save baseline.json && clous diff baseline.json --fail-on-drift

# Safely terminate the process occupying port 8080
clous kill 8080 --wait
```

### Türkçe (TR)
```bash
# Dışa açık dinleyen portları ~30 ms'de listele
clous list --exposed

# 0-100 güvenlik skoru ve kriptografik binary imza denetimi
clous audit --strict

# 3000 portunun süreç soy ağacını ve canlı HTTP başlığını incele
clous inspect 3000 --probe

# 500ms aralıkla canlı port izleme ve açık/kapalı fark günlüğü
clous watch -i 500

# Port temelini kaydet ve sapma (drift) kontrolü yap
clous snapshot save baseline.json && clous diff baseline.json --fail-on-drift

# 8080 portunu işgal eden süreci güvenle sonlandır
clous kill 8080 --wait
```

---

## 7. Sıkça Sorulan Sorular / FAQ

### English (EN — Primary)
1. **Does Clous really have zero external dependencies?**
   Yes. Both `Cargo.toml` (Rust core) and `Package.swift` (macOS SwiftUI app) contain zero third-party packages. Every scanner, JSON serializer, and UI component is built natively from scratch.
2. **Does Clous send my port or network data to any server?**
   Never. Clous runs 100% locally and offline with zero telemetry, zero analytics, and zero cloud connections.
3. **Why native Rust and SwiftUI instead of Electron?**
   A port monitor shouldn't consume 300 MB of RAM. The Clous CLI is just `735 KB`, the full macOS desktop app is `11 MB`, and scans complete in `~30 ms`.
4. **Which operating systems are supported?**
   The desktop app is built natively for macOS (Apple Silicon & Intel). The `clous` CLI supports **macOS, Linux, and Windows**.
5. **Can I use Clous in CI/CD pipelines?**
   Yes. Use `--json`, `--csv`, or `--compact` output alongside `audit --strict`, `diff --fail-on-drift`, and `wait <port>` directly in automated workflows.

### Türkçe (TR)
1. **Clous gerçekten 0 harici bağımlılıkla mı çalışıyor?**
   Evet. Hem `Cargo.toml` (Rust çekirdeği) hem `Package.swift` (macOS SwiftUI uygulaması) sıfır üçüncü parti paket içerir.
2. **Ağ veya port verilerim herhangi bir sunucuya gönderiliyor mu?**
   Hayır. Clous %100 lokal ve çevrimdışı çalışır; sıfır telemetri ve sıfır bulut bağlantısı içerir.
3. **Neden Electron yerine native Rust ve SwiftUI?**
   Bir port izleme aracının kendisi 300 MB RAM tüketmemelidir. Clous CLI yalnızca `735 KB`, macOS uygulaması `11 MB` boyutundadır ve `~30 ms` içinde tarama yapar.
4. **Hangi işletim sistemlerini destekliyor?**
   Masaüstü uygulaması macOS için native olarak geliştirilmiştir; `clous` CLI aracı ise **macOS, Linux ve Windows** üzerinde tam destekle çalışır.
5. **CI/CD süreçlerinde kullanılabilir mi?**
   Evet. `--json`, `--csv`, `--compact` formatları ile `audit --strict`, `diff --fail-on-drift` ve `wait <port>` komutları doğrudan otomasyon hatlarına entegre edilebilir.

---

## 8. Meta / SEO Etiketleri (Sadece Metin)

- **Page Title (EN — Primary):** `Clous — 30ms Port Monitoring, Security Audit & Native macOS App`
- **Meta Description (EN — Primary):** `Real-time port monitoring, 0-100 cryptographic security auditing, and forensic process inspection in ~30 ms. 735 KB zero-dependency Rust CLI + 11 MB native macOS app.`
- **Page Title (TR):** `Clous — 30ms Port İzleme, Güvenlik Denetimi ve Native macOS Uygulaması`
- **Meta Description (TR):** `735 KB sıfır bağımlılıklı Rust CLI ve 11 MB native macOS uygulamasıyla ~30 ms'de gerçek zamanlı port izleme, 0-100 güvenlik denetimi ve adli süreç analizi.`
