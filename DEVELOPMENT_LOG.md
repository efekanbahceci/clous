# SierraPort — Geliştirme Kayıtları ve Kullanım Analizi

Bu doküman, **SierraPort** projesinde yapılan tüm geliştirmeleri **gün, tarih, saat ve GitHub commit/push kodu** bazında kronolojik olarak kayıt altına alır; her değişikliğin teknik detaylarını, amacını ve bireysel/kurumsal kullanım değerini belgeler.

---

## Kronolojik Zaman Çizelgesi ve GitHub Kayıtları

| Gün & Tarih | Saat (TRT) | GitHub Commit | Geliştirme Özeti |
|---|---|---|---|
| Perşembe, 19 Kasım 2026 | `14:48` | `cd81280` | İlk depo kurulumu (`Initial commit`) |
| Perşembe, 19 Kasım 2026 | `14:59` | `eea6881` | Çekirdek Rust CLI (`v0.1.0`) — `list`, `watch`, `check`, `who`, `kill`, `stats` |
| Cuma, 20 Kasım 2026 | `13:41` | `600994b` | `display.rs` import düzenlemesi |
| Cuma, 20 Kasım 2026 | `13:53` | `bb9de39` | Gelişmiş port analiz, `audit`, `inspect`, `snapshot`/`diff`, `free`, `wait` (`v0.2.0`) |
| Cuma, 20 Kasım 2026 | `14:00` – `14:16` | `6007630`, `d06a727` | Titremesiz In-Place `watch` TUI, `DOCS.md`, İngilizce `README.md` ve Apple-stili SVG banner'lar |
| Cuma, 20 Kasım 2026 | `14:32` | `87104ac` | Native macOS `SierraPort.app` (SwiftUI + Rust `stream` NDJSON + Menu Bar Extra) |
| Cuma, 20 Kasım 2026 | `15:20` | `cca4b1a` | Katlanabilir Terminal Deck, dinamik Swift Charts, `#111110` Dark/Light tema, `sierraport-preview.png` |
| Cuma, 20 Kasım 2026 | `15:33` | `8143ede` | Yeni Nesil Güvenlik & Binary Güven Denetim Motoru (`codesign`, Firewall Posture, Deep Probe, Allowlist, Export MD) |
| Cuma, 20 Kasım 2026 | `15:42` | *(push bekliyor)* | Terminal Deck öneksiz çalıştırma ve İngilizce öncelikli akıllı komut çözümleyici |
| Cuma, 20 Kasım 2026 | `15:50` | *(push bekliyor)* | Katı komut doğrulama, Apple Shake hata animasyonu ve Türkçe/İngilizce ilişkili komut öneri motoru |
| Cuma, 20 Kasım 2026 | `15:54` | *(push bekliyor)* | Klavye-öncelikli (`Tab` / `Shift+Tab` / `↑↓` / `⏎` / `Esc` / `⌘1–4`) mouse'suz gezinme optimizasyonu |
| Cuma, 20 Kasım 2026 | `15:59` | *(push bekliyor)* | Sonuç tablosu içi `Tab` / `↑↓` gezinme, otomatik kaydırma ve tek `Enter` ile Forensic Inspector açma |
| Cuma, 20 Kasım 2026 | `16:03` | *(push bekliyor)* | Tekil satır seçim düzeltmesi (`selectedRowKey`) ve `inspect` duplicate UDP soket tekilleştirmesi |
| Cuma, 20 Kasım 2026 | `20:01` | *(push bekliyor)* | Resmi Ghostty-stili Terminal Çerçeveli SierraPort Uygulama Logosu (`AppIcon.icns`, Sidebar, Command Deck ve Menu Bar entegrasyonu) |
| Cuma, 20 Kasım 2026 | `20:04` | *(push bekliyor)* | `#0B24AC` Kobalt Mavi Degrade Uygulama İkonu — terminal çerçevesi kaldırıldı, şeffaf beyaz maskot büyütüldü (`AppIcon.icns` güncellendi) |
| Cuma, 20 Kasım 2026 | `20:05` | *(push bekliyor)* | Uygulama ikonu ana rengi `#121846` derin gece laciverdi degradeye (`#1F296E → #121846 → #080B24`) güncellendi |
| Cuma, 20 Kasım 2026 | `20:07` | *(push bekliyor)* | Uygulama ikonu ana rengi `#082452` derin okyanus mavisi degradeye (`#123C82 → #082452 → #031129`) güncellendi |
| Cuma, 20 Kasım 2026 | `20:14` | *(push bekliyor)* | Raycast/Spotlight Tarzı Sistem Geneli Global Kısayol, Yüzen Hızlı Başlatıcı (`NSPanel`) ve Motion İlk Kurulum (Onboarding) Ekranı |
| Cuma, 20 Kasım 2026 | `20:23` | *(push bekliyor)* | Raycast Tasarım Sistemi & Tipografi (`SierraFont`: Inter / SF Pro + JetBrains Mono / SF Mono, üst ışık kenarlıklı `raycastCard`, alt aksiyon çubuğu ve safir vurgu rengi) |
| Cuma, 20 Kasım 2026 | `20:30` | *(push bekliyor)* | Gerçek Inter v4.1 Font Paketi Gömülmesi, Yüzen Başlatıcı Çerçeve/Geri Dönüş Düzeltmeleri, Beyaz Maskot İkonu ve Canlı Port Önerileri |
| Cuma, 20 Kasım 2026 | `21:21` | *(push bekliyor)* | Kısayol Ayarlama Sayfası için Slow-Motion Termal Gradyan (`ThermalGradientBackground`) ve Buzlu Cam Kart UI |
| Cuma, 20 Kasım 2026 | `21:26` | *(push bekliyor)* | Kısmi Çapraz Termal Tutulma Gradyanı (`ThermalEclipseBackground` + Film Greni) ve Tek Seferlik 3 Adımlı İlk Kurulum Sihirbazı (Tema → Güvenlik Profili → Kısayol) |
| Cuma, 20 Kasım 2026 | `21:28` | *(push bekliyor)* | İlk Kurulum Test Betiği (`scripts/test-onboarding.sh`) — tek komutla ilk açılış simülasyonu ve `--full` tam sıfırlama |
| Cuma, 20 Kasım 2026 | `21:34` | *(push bekliyor)* | 60/120fps GPU `Canvas` Slow-Motion Termal Gradyan, Akıcı Yönlü Adım Geçişleri, `Enter (⏎)` İlerleme Kısayolu ve Canlı Light Mode Mavi Termal Palet |
| Cumartesi, 21 Kasım 2026 | `10:07` | *(push bekliyor)* | `macos/SierraPortApp/` klasörünün `.gitignore` kapsamına alınması ve Git indeksinden (`--cached`) çıkarılması |
| Cumartesi, 21 Kasım 2026 | `10:15` | *(push bekliyor)* | Apple Liquid Glass Arayüz Sistemi: Yüzen Cam Kenar Çubuğu, Terminal Deck Derin Safir Degrade Arka Plan, 20pt Yumuşak Pencere Çerçevesi ve Eşit Ölçülü Cam Kartlar |
| Cumartesi, 21 Kasım 2026 | `10:19` | *(push bekliyor)* | Native macOS Pencere Çerçevesi / Trafik Işıkları Düzeltmesi ve Mavi Degradenin Yalnızca Boş Terminal Deck ile Sınırlandırılması |
| Cumartesi, 21 Kasım 2026 | `10:25` | *(push bekliyor)* | Trafik Işıklarının Yüzen Kenar Çubuğu İçine Hizalanması, Light Mode Gölgelerinin Hafifletilmesi ve Dinamik Cam Satır Gezinme Çubuğu |
| Cumartesi, 21 Kasım 2026 | `10:30` | *(push bekliyor)* | Gemini Stili `MacTrafficLightsView`, Katlanabilir Sol Menü (`sidebar.left` / `⌘\`) ve Geniş Tıklama Alanlı `TactileGlassButtonStyle` |
| Cumartesi, 21 Kasım 2026 | `10:34` | *(push bekliyor)* | Apple Design Skill (HIG) Revizyonu: `Reduce Motion`/`Reduce Transparency`/`Increase Contrast`, Yerel macOS Menü Çubuğu Komutları, 10pt Tipografi Tabanı ve VoiceOver Etiketleri |
| Cumartesi, 21 Kasım 2026 | `10:50` | *(push bekliyor)* | Türkçe Teknik Analiz, Mimari ve Gelecek Yol Haritası Sunum Raporu (`docs/SierraPort-Teknik-Analiz-Raporu.pdf`, 7 sayfa) |
| Cumartesi, 21 Kasım 2026 | `11:10` | *(push bekliyor)* | Grafik Motoru Düzeltmesi: Monotonik `historySeq` + `streamGeneration` Koruması, Etkileşimli Metrik Seçici (`All/Active/Exposed/Scan ms`) ve Hover İzleme |
| Cumartesi, 21 Kasım 2026 | `11:16` | *(push bekliyor)* | Tam Sistem Hata Taraması & 7 Düzeltme: Eşzamanlı Pipe Okuma, `NSLock` Akış Tamponu, Çıkışta Alt Süreç Temizliği, Güvenlik Profili Kalıcılığı, Quick Launcher Tıklama ve Clippy Sıfırlama |
| Cumartesi, 21 Kasım 2026 | `11:40` | *(push bekliyor)* | Güvenlik Denetimi İyileştirmeleri (8 Doğrulanmış Bulgu + Sertleştirme): `codesign --verify --strict`, POSIX Tek-Tırnak `remediation_cmd`, `ZeroTrust` LAN Denetimi, `O_NOFOLLOW`/`0o600` Dosya Güvenliği, ANSI/NDJSON/JSONL/Markdown Kaçışı ve `#if DEBUG` İkili Arama |
| Cumartesi, 21 Kasım 2026 | `11:44` | *(push bekliyor)* | Skill Klasörlerinin Tek Çatı Altında (`.agents/skills/`) Birleştirilmesi ve 10 Yinelemeli Symlink Klasörünün Temizlenmesi |
| Cumartesi, 21 Kasım 2026 | `15:05` | *(push bekliyor)* | Kapalı Sol Menü Trafik Işıkları Cam Kapsülü Düzeltmesi, `14pt` Büyütülmüş Pencere Düğmeleri ve `22pt` Yumuşak Pencere Köşeleri |
| Cumartesi, 21 Kasım 2026 | `15:09` | *(push bekliyor)* | Apple HIG Pencere Üst Kenar Kırpma & Çift Çerçeve Düzeltmesi (`fullSizeContentView` + Kök `.ignoresSafeArea()`) |
| Cumartesi, 21 Kasım 2026 | `15:11` | *(push bekliyor)* | Kapalı Sol Menü Üst Çubuğunun Doğal macOS Başlık Hizasına Yukarı Çekilmesi (`top: 6pt`, `height: 30pt`) |
| Cumartesi, 21 Kasım 2026 | `15:14` | *(push bekliyor)* | Sabit Konumlu `MacTrafficLightsView` Overlay — Sol Menü Açık/Kapalı Durumda Birebir Aynı `(x: 20, y: 18)` Piksel Hizası |
| Cumartesi, 21 Kasım 2026 | `15:18` | *(push bekliyor)* | Kapalı Sol Menü `sidebar.left` Düğmesinin Trafik Işıklarıyla Aynı Üst Overlay Satırına (`y = 25pt` merkez) Hizalanması |
| Cumartesi, 21 Kasım 2026 | `15:22` | *(push bekliyor)* | Terminal Deck & Sol Menü Başlığında Monokrom Maskot Logosu (`SierraMascotMarkView` — Dark: Beyaz, Light: Siyah) ve Sol Menü Metninin Kaldırılması |
| Pazartesi, 23 Kasım 2026 | `21:36` | *(push bekliyor)* | Apple HIG Crimson Tema Paleti (`#EB0020` Ana Renk, `#1A0003` Dark Arka Plan, `#FFFFFF` Light Arka Plan + Liquid Glass, Grafikler ve Onboarding Uyumu) |
| Pazartesi, 23 Kasım 2026 | `21:40` | *(push bekliyor)* | Nötr Karanlık Zemin (`#07080A`) ve Dengeli `#EB0020` Vurgu Optimizasyonu (Aşırı Kırmızı Tonların Kaldırılması) |
| Salı, 24 Kasım 2026 | `11:09` | *(push bekliyor)* | Terminal Deck Tüm CLI Komut Kartları İçin Slow-Motion Akıcı Açılma Animasyonu (`SlowMotionBlockReveal` + `timingCurve(0.22, 1, 0.36, 1)`) |
| Salı, 24 Kasım 2026 | `11:21` | *(push bekliyor)* | Sıfır Maliyetli & Sıfır Bağımlılıklı GitHub Releases Canlı Güncelleme Sistemi (`UpdateManager.swift`, `Restart Update` Butonu, `package-release.sh` DMG/ZIP/SHA-256) |
| Salı, 24 Kasım 2026 | `11:27` | *(push bekliyor)* | Tam Marka Geçişi (**Clous**) & GitHub Repo Bağlantısının `efekanbahceci/clous` Olarak Güncellenmesi (`Clous.app`, `Clous.dmg`, `Clous.zip`, CLI & UI) |
| Salı, 24 Kasım 2026 | `12:45` | *(push bekliyor)* | Alt Durum Kartında `"Rust Core Ready"` Yerine Dinamik Sürüm Göstergesi (`Clous v<CFBundleShortVersionString>`) |
| Salı, 24 Kasım 2026 | `12:59` | *(push bekliyor)* | Yeni `#07080A → #EB0020` Degrade Masaüstü İkonu (`AppIcon.icns`), `codesign --deep` Paket Mühürleme ("Bozuk" Hatası Düzeltmesi) ve Özel Tasarımlı Retina `Clous.dmg` Kurulum Penceresi |
| Salı, 24 Kasım 2026 | `13:04` | *(push bekliyor)* | Düz `#07080A` Zemin + `#EB0020` Maskotlu Masaüstü İkonu ve Metinsiz Kırmızı Degrade `Clous.dmg` Kurulum Ekranı |

---

## Perşembe, 19 Kasım 2026 — `14:59` · Commit: `eea6881` (Başlangıç: `cd81280` — `14:48`)
### Çekirdek Rust CLI Altyapısı (`v0.1.0`)
**Etkilenen Modüller:** `src/main.rs`, `src/cli.rs`, `src/models.rs`, `src/commands.rs`, `src/display.rs`, `src/scanner/{linux,macos,windows}.rs`

- Sıfır harici bağımlılıklı (saf Rust `std`) çapraz platform port izleme CLI aracı oluşturuldu.
- Linux'ta doğrudan `/proc/net/*` okuma, macOS'ta `lsof`, Windows'ta `netstat` + `tasklist` desteği kuruldu.
- Temel `list`, `watch`, `check`, `who`, `kill`, `stats` komutları eklendi.
- **Amaç:** `lsof`, `netstat`, `ss` gibi işletim sistemine göre değişen karmaşık komutların yerine tek, tutarlı, yüksek hızlı ve bağımlılıksız bir temel oluşturmak.

---

## Cuma, 20 Kasım 2026 — `13:53` · Commit: `bb9de39`
### Gelişmiş Port Analiz, Denetim ve Otomasyon Motoru (`v0.2.0`)
**Etkilenen Modüller:** `src/audit.rs`, `src/snapshot.rs`, `src/models.rs`, `src/scanner/mod.rs`, `src/scanner/macos.rs`, `src/scanner/linux.rs`, `src/display.rs`, `src/cli.rs`, `src/commands.rs`

- **Zengin Süreç Metadata'sı:** macOS'ta tek seferlik toplu (batched) `ps`, Linux'ta `/proc/<pid>/status` üzerinden `user`, `ppid`, `memory_kb` (RSS) ve tam `cmdline` eklendi.
- **Bind Kapsamı Sınıflandırması (`BindScope`):** Her soket `LOCAL`, `LAN`, `ALL(*)` veya `PUBLIC` olarak otomatik etiketlendi.
- **Runtime / Container Etiketleme:** `[container]`, `[database]`, `[proxy/web]`, `[js/ts]`, `[python]`, `[jvm]` bağlam etiketleri eklendi.
- **Yeni Komutlar:**
  - `inspect <port> [--probe]`: Süreç soyağacı (ancestry), aktif peer bağlantıları ve canlı protokol/banner probu (HTTP, SSH, Redis, SMTP/FTP, MySQL, TLS).
  - `audit [--strict]`: 0–100 güvenlik skoru, dışa açık veritabanı ve `CLOSE_WAIT`/`TIME_WAIT` soket sızıntı tespiti.
  - `snapshot save` & `diff [--fail-on-drift]`: Baseline JSON kaydı ve canlı sistem sapma (drift) analizi.
  - `free` & `wait`: Boş port bulucu ve CI/CD port hazır/kapalı bekleyici.
- **Çoklu Çıktı & Sıralama:** `--format table|json|csv|compact`, `--wide`, `--sort port|pid|process|state|proto|mem`, `--exposed`, `--state`, `--user`, ASCII bar grafikli `stats`.
- **Kullanım Değeri:** Bireysel geliştiriciler için `EADDRINUSE` çözümü, dinamik boş port tahsisi ve servis bekleme; kurumlar ve SRE ekipleri için baseline drift kontrolü ve CI/CD otomasyonu.

---

## Cuma, 20 Kasım 2026 — `14:00` – `14:16` · Commit: `6007630`, `d06a727`
### Titremesiz Yerinde Canlı İzleme (In-Place TUI) & Kapsamlı Dokümantasyon
**Etkilenen Modüller:** `src/commands.rs`, `src/display.rs`, `DOCS.md`, `README.md`, `assets/sierraport-banner-{dark,light}.svg`

- `watch` komutu **Alternate Screen Buffer (`\x1b[?1049h`)**, imleç gizleme (`\x1b[?25l`), atomik tek-yazım (`\x1b[H` + `\x1b[K` + `\x1b[J`) ve temiz `SIGINT` (`Ctrl+C`) geri yüklemesiyle gerçek bir titremesiz TUI paneline dönüştürüldü.
- Türkçe teknik rehber (`DOCS.md`), İngilizce kapsamlı `README.md` ve Apple UI tasarım diline uygun şeffaf arka planlı Dark/Light adaptif SVG marka banner'ları eklendi.

---

## Cuma, 20 Kasım 2026 — `14:32` · Commit: `87104ac`
### Native macOS Masaüstü Uygulaması (`SierraPort.app`: SwiftUI + Rust Core)
**Etkilenen Modüller:** `src/commands.rs` (`stream` NDJSON), `macos/SierraPortApp/Sources/SierraPortApp/*`, `scripts/build-macos-app.sh`

- Rust çekirdeğine satır bazlı JSON olay akışı sağlayan `sierraport stream -i <ms>` eklendi (~30ms tarama gecikmesi).
- Ghostty mimarisi (sistem dili çekirdek + native macOS arayüz) örnek alınarak sıfır harici Swift bağımlılıklı **2.6 MB** boyutunda native **`SierraPort.app`** inşa edildi.
- 4 ana modül: **Terminal Deck**, **Live Watch**, **Security Audit**, **Analytics** (native Swift Charts) + sağdan açılan **Forensic Inspector** + **macOS Menu Bar Extra**.

---

## Cuma, 20 Kasım 2026 — `15:20` · Commit: `cca4b1a`
### Dinamik UI/UX, Katlanabilir Terminal Deck ve `#111110` Adaptif Tema Sistemi
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{Theme,ContentView,VisualBlocks,ViewModel,Models,SierraPortApp}.swift`, `assets/sierraport-preview.png`

- **Katlanabilir Komut Blokları:** Terminal Deck'teki her komut bloğu tıklanarak tek satıra katlanıp tekrar açılabilir; yeni komut çalıştırıldığında eskiler otomatik katlanır, yeni blok `NEW` rozeti ve camgöbeği vurguyla odaklanır.
- **Boş Durum Karşılama Ekranı (Command Deck Hero):** Komut yokken Apple minimalist marka başlığı, açıklayıcı bilgi metni ve ortalanmış daraltılmış komut giriş kutusu.
- **Düzen ve Grafik Hatalarının Giderilmesi:** Duplicate `ForEach` ID kaynaklı üst üste binme hataları giderildi; `BindingCardView` tıklanarak tam komut satırını açacak ve kopyalayacak şekilde yeniden tasarlandı; Swift Charts `Live Socket Activity` sparkline ve `SectorMark` donut grafikleri düzeltildi.
- **`#111110` Adaptif Tema Sistemi (`Theme.swift`):** Dark (`#111110`), Light (`#F6F6F4`) ve System temaları arasında anlık geçiş + `NSWindow` çerçeve senkronizasyonu.
- GitHub README için alt kısmı yumuşak Gaussian blur ve kosinüs şeffaf degrade ile kaybolan `assets/sierraport-preview.png` oluşturuldu.

---

## Cuma, 20 Kasım 2026 — `15:33` · Commit: `8143ede`
### Yeni Nesil Güvenlik & Binary Güven Denetim Motoru
**Etkilenen Modüller:** `src/audit.rs`, `src/cli.rs`, `src/commands.rs`, `src/display.rs`, `macos/SierraPortApp/Sources/SierraPortApp/{Models,ViewModel,VisualBlocks,ContentView}.swift`

#### Teknik Değişiklikler
1. **macOS İkili Dosya İmza & Köken Doğrulaması (`codesign` + Yol Analizi):** Dinleyen her çalıştırılabilir dosya `APPLE SIGNED`, `DEVELOPER ID`, `AD-HOC` veya `UNSIGNED` şeklinde sınıflandırıldı; `/tmp`, `/var/tmp`, `~/Downloads`, `~/Desktop` gibi geçici yollardan çalışan dinleyicilere **`CRITICAL — TRUST-SUSP-PATH`** alarmı eklendi.
2. **Sistem Savunma Duruşu (`Host Defense Posture`):** macOS Application Firewall (`socketfilterfw --getglobalstate`) ve Stealth Mode (`--getstealthmode`) durumu canlı okunarak skora ve Audit üst şeridine yansıtıldı.
3. **Aktif Güvenlik Probu (`--deep` / Deep Probe):** Şifresiz Redis (`+PONG` → **`CRITICAL — AUTH-NONE`**) ve açık HTTP banner/sürüm sızıntıları (`INFO-BANNER`) gerçek zamanlı doğrulandı.
4. **Güvenlik Profilleri & Kalıcı Risk Kabul (Allowlist):** `Developer`, `Strict` ve `Zero-Trust` profilleri + bulguları kalıcı olarak sessize alıp geri alma (`Accept Risk`).
5. **Müdahale Playbook'u & Markdown Uyumluluk Raporu (`Export MD`):** Her bulguya tek tıkla kopyalanabilir çözüm komutu (`socketfilterfw`, `pfctl`, `redis-cli`, `sierraport kill`) ve zaman damgalı Markdown rapor dışa aktarımı.

#### Bireysel ve Kurumsal Kullanım Alanları
- **Bireysel Kullanıcılar / Geliştiriciler:** Ortak Wi-Fi'da unutulmuş dışa açık DB/dev sunucusu kontrolü, şüpheli/imzasız veya `/tmp` kaynaklı arka kapı (backdoor) tespiti, Docker'da şifresiz açık bırakılan Redis yakalama, gürültüsüz `Accept Risk` yönetimi.
- **Kurumlar (DevSecOps, SRE, SOC, IT Güvenlik):** SOC 2 / ISO 27001 iş istasyonu uyumluluğu ve **`Export MD`** denetim kanıtı üretimi, CI/CD güvenlik kapısı (`--profile strict --deep --strict`), Zero-Trust + Code-Signature ile tehdit avcılığı ve tedarik zinciri saldırı tespiti, standartlaştırılmış tek tıkla müdahale playbook'ları.

---

## Cuma, 20 Kasım 2026 — `15:42` · Commit: *(push bekliyor)*
### Terminal Deck Öneksiz Çalıştırma ve İngilizce Öncelikli Akıllı Komut Çözümleyici
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{Models,ViewModel,ContentView}.swift`

- Terminal Deck komut satırında `sierraport` öneki zorunluluğu kaldırıldı; blok başlıklarındaki gereksiz `sierraport ` öneki temizlendi.
- İngilizce öncelikli kısayollar (`close 3000`, `stop 3000`, `5000`, `exposed`, `memory`, `free port`, `security scan`, `strict audit`, `zero trust`, `live`, `analytics`) doğrudan ilgili CLI komutlarına çevrilip başlıkta şeffaf biçimde (`close 3000 → kill 3000 -y --wait`) gösterilir.

---

## Cuma, 20 Kasım 2026 — `15:50` · Commit: *(push bekliyor)*
### Katı Komut Doğrulama, Apple Shake Hata Animasyonu ve Türkçe/İngilizce Öneri Motoru
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{ViewModel,ContentView}.swift`

- Geçersiz komut veya Türkçe ifade girildiğinde boş `"No matching sockets"` kartı açılması engellendi.
- **Apple-Stili Shake Animasyonu (`ShakeEffect`) & Kırmızı Hata Göstergesi:** Bilinmeyen komutlarda metin kutusu yatay sallanır, kırmızı kenarlık ve hata mesajı gösterir.
- **Çift Dilli & Yazım Hatasına Dayanıklı (Levenshtein) Öneri Motoru:** Türkçe ifadeler (`3000 kapat`, `güvenlik tara`, `dışa açık`, `bellek`, `boş port`) ve İngilizce yazım hataları (`audt`, `lsit`, `stts`) doğrudan çalıştırılmaz; altta ilişkili geçerli İngilizce CLI komutları (`DID YOU MEAN?`) tek tıkla seçilmek üzere listelenir.

---

## Cuma, 20 Kasım 2026 — `15:54` · Commit: *(push bekliyor)*
### Klavye-Öncelikli (`Tab` / `Shift+Tab` / `↑↓` / `⏎` / `Esc` / `⌘1–4`) Mouse'suz Gezinme Optimizasyonu
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{ViewModel,ContentView}.swift`

- Komut satırındayken `Tab` / `↓` ile alttaki öneri komutları arasında ileri, `Shift+Tab` / `↑` ile geri gezinme ve `Enter` ile anında çalıştırma eklendi.
- `Esc` tuşu sırasıyla öneri odağını, hata uyarısını, açık Inspector'ı veya metin kutusunu temizler.
- Global mouse'suz sekme kısayolları eklendi: `⌘1` (Terminal Deck), `⌘2` (Live Watch), `⌘3` (Security Audit), `⌘4` (Analytics), `⌘K`, `⌘R`, `⌥⌘I`.

---

## Cuma, 20 Kasım 2026 — `15:59` · Commit: *(push bekliyor)*
### Sonuç Tablosu İçi `Tab` / `↑↓` Gezinme ve Tek `Enter` ile Derin İnceleme
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{ViewModel,VisualBlocks,ContentView}.swift`

- Bir komut çalıştırıldıktan sonra (ör. `list --exposed`, `list`, `audit`) metin kutusu boşken `Tab` veya `↓` tuşuna basıldığında odak doğrudan açık sonucun satırlarına iner (`focusedResultIndex`), `ScrollViewReader` otomatik kaydırma yapar.
- Odaklanılan satırda `Enter` ile sağdan **Forensic Inspector** açılır; `Esc` ile Inspector kapatıldığında satır odağı korunur, böylece hemen `Tab` ile bir sonraki porta geçilebilir.

---

## Cuma, 20 Kasım 2026 — `16:03` · Commit: *(push bekliyor)*
### Tekil Satır Seçim Düzeltmesi ve Duplicate UDP Soket Tekilleştirmesi
**Etkilenen Modüller:** `src/commands.rs`, `macos/SierraPortApp/Sources/SierraPortApp/{ViewModel,VisualBlocks,ContentView}.swift`

- **Tekil Satır Vurgulama (`selectedRowKey`):** Satır seçimi port numarası yerine her satıra özgü benzersiz `"\(tableId)-\(idx)"` anahtarına taşındı; aynı portu paylaşan birden fazla UDP satırından (ör. `UDP6 5353`) birine tıklandığında artık yalnızca o tek satır seçili olur.
- **Inspector Duplicate Soket Tekilleştirmesi:** `src/commands.rs` (`run_inspect`) içinde aynı `(protocol, local, remote, state, pid)` bilgisine sahip özdeş macOS `lsof` soket kopyaları tekilleştirildi.

---

## Cuma, 20 Kasım 2026 — `20:01` · Commit: *(push bekliyor)*
### Resmi Ghostty-Stili Terminal Çerçeveli Uygulama Logosu ve macOS İkon Entegrasyonu
**Etkilenen Modüller:** `assets/sierraport-mark.png`, `assets/sierraport-app-icon.png`, `assets/AppIcon.icns`, `scripts/build-macos-app.sh`, `macos/SierraPortApp/Sources/SierraPortApp/{Theme,SierraPortApp,ContentView}.swift`

- **Ultra Yüksek Kaliteli Maskot Ayıklama (`assets/sierraport-mark.png`):** Gönderilen maskot görselindeki siyah arka plan yumuşak `smoothstep` luminans maskesiyle pikselleşme ve koyu kenar halesi olmadan tamamen kesilerek `1024×1024` şeffaf `#F5F5F4` vektör keskinliğinde marka işaretine dönüştürüldü.
- **Ghostty Tarzı Terminal Çerçeveli Uygulama İkonu (`assets/sierraport-app-icon.png` & `assets/AppIcon.icns`):** Dışta antrasit/titanyum macOS squircle çerçeve (`#333330 → #111110`), üstte sade 3 pencere noktası ve ince ayırıcı çizgi, içte gömülü mat siyah terminal ekranının merkezinde SierraPort maskotu olacak şekilde 10 çözünürlüklü resmi macOS `.icns` paketi üretildi (`16px` – `512px@2x`).
- **Uygulama Geneli Entegrasyon:** `CFBundleIconFile = AppIcon` (Dock, Finder, Spotlight, `⌘+Tab`), Sidebar başlığı, Command Deck karşılama ekranı ve macOS Menü Çubuğu (otomatik Dark/Light uyumlu `isTemplate` maskot ikonu) tek bir resmi marka kimliği altında birleştirildi.

---

## Cuma, 20 Kasım 2026 — `20:04` · Commit: *(push bekliyor)*
### `#0B24AC` Kobalt Mavi Degrade Uygulama İkonu Güncellemesi
**Etkilenen Modüller:** `assets/sierraport-app-icon.png`, `assets/AppIcon.icns`, `dist/SierraPort.app`

- **Yeni Ana Tema Rengi (`#0B24AC`):** Terminal çerçevesi kaldırılarak macOS squircle içerisine `#1D3DE2 → #0B24AC → #051264` kobalt mavi degrade ve yumuşak üst ışık yansıması uygulandı.
- **Büyütülmüş Şeffaf Beyaz Maskot:** Şeffaf beyaz SierraPort maskotu `688×688` (squircle genişliğinin ~%74'ü) boyutuna büyütülüp ince derinlik gölgesiyle tam merkeze yerleştirildi; tüm `16px`–`512px@2x` macOS `.icns` katmanları ve `dist/SierraPort.app` paketi yenilendi.

---

## Cuma, 20 Kasım 2026 — `20:05` · Commit: *(push bekliyor)*
### `#121846` Gece Laciverdi Degrade Uygulama İkonu Güncellemesi
**Etkilenen Modüller:** `assets/sierraport-app-icon.png`, `assets/AppIcon.icns`, `dist/SierraPort.app`

- Uygulama ikonunun arka plan degradeleri `#1F296E → #121846 → #080B24` derin gece laciverdi tonlarına güncellendi; `AppIcon.icns` ve `dist/SierraPort.app` yeniden paketlendi.

---

## Cuma, 20 Kasım 2026 — `20:07` · Commit: *(push bekliyor)*
### `#082452` Derin Okyanus Mavisi Degrade Uygulama İkonu Güncellemesi
**Etkilenen Modüller:** `assets/sierraport-app-icon.png`, `assets/AppIcon.icns`, `dist/SierraPort.app`

- Uygulama ikonunun arka plan degradeleri `#123C82 → #082452 → #031129` derin okyanus mavisi tonlarına güncellendi; `AppIcon.icns` ve `dist/SierraPort.app` yeniden paketlendi.

---

## Cuma, 20 Kasım 2026 — `20:14` · Commit: *(push bekliyor)*
### Raycast / Spotlight Tarzı Sistem Geneli Kısayol, Yüzen Hızlı Başlatıcı ve Motion Onboarding
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{GlobalHotkeyManager,QuickLauncherPanel,ShortcutOnboardingView,SierraPortApp,ContentView}.swift`

- **Sistem Geneli macOS Global Kısayol (`GlobalHotkeyManager.swift`):** Apple Carbon `RegisterEventHotKey` API'si ile harici bağımlılık ve Accessibility izni gerektirmeden macOS genelinde her uygulama ve Space üzerinden çalışan özel kısayol kaydı eklendi.
- **Raycast-Stili Motion İlk Kurulum Ekranı (`ShortcutOnboardingView.swift`):** İlk açılışta (ve istendiğinde Sidebar'daki **Quick Launch** düğmesinden tekrar) kademeli spring animasyonlar, `#082452` ortam ışığı, 3 boyutlu dokunsal tuş başlıkları (`TactileKeycapView`), canlı tuş kombinasyonu kaydedici (`NSEvent` monitor) ve hazır şablonlar (`⌥ Space`, `⌃ Space`, `⌘ ⇧ P`, `⌥ P`) ile kısayol tanımlanır.
- **Yüzen Spotlight/Raycast Hızlı Başlatıcı (`QuickLauncherPanel.swift`):** Belirlenen kısayola hangi uygulamada olunursa olunsun basıldığında ekranın üst-ortasında kenarlıksız yüzen `NSPanel` açılır; kullanıcı `Tab`/`↑↓`/`Enter` ile doğrudan komut çalıştırıp port tablosu, güvenlik skoru veya forensic inspect sonuçlarını anında panel içinde görür ve `Esc` (veya dışarı tıklama) ile kapatır.

---

## Cuma, 20 Kasım 2026 — `20:23` · Commit: *(push bekliyor)*
### Raycast Tasarım Sistemi ve Tipografi Güncellemesi (`SierraFont` & Raycast UI)
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{Theme,ContentView,QuickLauncherPanel,VisualBlocks}.swift`

- **Raycast Tipografi Sistemi (`SierraFont`):** Raycast'in kullandığı açık lisanslı **Inter** (SIL OFL) ve **JetBrains Mono** fontlarını sistemde yüklüyse otomatik algılayan, yüklü değilse Apple'ın native **SF Pro** ve **SF Mono** tipografisiyle hukuki açıdan %100 güvenli biçimde eşleşen tipografi katmanı kuruldu.
- **Raycast Yüzey ve Kart Dili (`raycastCard` & `RaycastKeycap`):** Kartlara ve yüzen başlatıcıya ince üst cam ışık kenarlığı (`topSpecular`), `#082452` uygulama ikonuyla uyumlu safir mavi odak vurgusu (`SierraTheme.accent`) ve Raycast'in ikonik nötr satır seçim dolgusu (`selectionFill`) eklendi.
- **Kalıcı Alt Aksiyon Çubuğu (`raycastFooterBar`):** Ana pencerenin altına Raycast tarzı dokunsal tuş başlıklarıyla (`⏎`, `Tab`, `⌥⌘I`, `Quick Launch`) durum ve kısayol çubuğu yerleştirildi.

---

## Cuma, 20 Kasım 2026 — `20:30` · Commit: *(push bekliyor)*
### Gerçek Inter v4.1 Font Paketi, Quick Launcher Çerçeve/Odak Düzeltmeleri ve Beyaz Maskot İkonu
**Etkilenen Modüller:** `assets/fonts/Inter-*.ttf`, `scripts/build-macos-app.sh`, `macos/SierraPortApp/Sources/SierraPortApp/{Theme,SierraPortApp,ShortcutOnboardingView,QuickLauncherPanel}.swift`

- **Gerçek Gömülü `Inter` v4.1 Fontu (SIL OFL 1.1):** Resmi `Inter-Regular`, `Inter-Medium`, `Inter-SemiBold` ve `Inter-Bold` `.ttf` dosyaları doğrudan `SierraPort.app/Contents/Resources/Fonts/` içine gömülüp `CTFontManagerRegisterFontsForURL` ile açılışta kaydedildi; tüm uygulama gerçek Raycast **Inter** tipografisiyle çalışır.
- **Yüzen Başlatıcı Bozuk Kenarlık Düzeltmesi:** `NSPanel` pencere gölgesiyle çakışan iç padding ve çift SwiftUI gölgesi kaldırıldı; `NSHostingView` katmanı şeffaf ve `cornerRadius: 16` ile temizce kırpılarak pürüzsüz tek parça 1px kenarlık sağlandı.
- **Ana Uygulamaya Geri Dönüş Düzeltmesi:** `NSApp.windows` içinde gizli Menu Bar penceresi yerine gerçek ana pencere (`$0.canBecomeMain && !($0 is FloatingLauncherPanel)`) seçilerek `Esc` veya **Open App** ile ana pencereye her zaman sorunsuz dönülmesi sağlandı.
- **Dinamik Quick Launcher & Saf Beyaz Maskot:** Kısayol açılışında gecikmesiz metin odaklaması, yazarken canlı port eşleştirme, `Tab`/`↑↓` + `Enter` akışı ve hem Onboarding hem Quick Launcher'da mavi kare yerine yalnızca şeffaf beyaz maskot (`SierraMascotMarkView`) kullanıldı.

---

## Cuma, 20 Kasım 2026 — `21:21` · Commit: *(push bekliyor)*
### Kısayol Sayfası için Slow-Motion Termal Gradyan Arka Planı (`ThermalGradientBackground`)
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/ShortcutOnboardingView.swift`

- **Slow-Motion Termal Gradyan (`TimelineView` + 4 Katmanlı Termal Küre):** Uygulamanın `#111110` koyu tema ve `#082452` derin okyanus mavisi kimliğiyle uyumlu 4 termal renk katmanı (Derin Safir `#082452 → #1647A8`, Sıcak Termal Mercan/Amber `#E6672A → #B8352B`, Termal Mor Köprü `#562EA6` ve Termal Camgöbeği `#1692B8`) 60fps akıcılıkla ağır çekim yörünge hareketiyle dönecek şekilde eklendi.
- **Buzlu Cam Kart & Okunabilirlik:** Kısayol kayıt kartı `.ultraThinMaterial` + yarı saydam `SierraTheme.surface` cam yüzeyi ve hafif kontrast tülü ile hem Dark hem Light temada yüksek okunabilirlik sunacak şekilde yenilendi.

---

## Cuma, 20 Kasım 2026 — `21:26` · Commit: *(push bekliyor)*
### Kısmi Çapraz Termal Tutulma Gradyanı ve Tek Seferlik 3 Adımlı İlk Kurulum Sihirbazı
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/ShortcutOnboardingView.swift`, `macos/SierraPortApp/Sources/SierraPortApp/SierraPortApp.swift`

- **Kısmi Çapraz Termal Tutulma Gradyanı (`ThermalEclipseBackground` + `ProceduralGrain`):** Referans termal görsellerden ilhamla, ekranın tamamını tekdüze boyamak yerine yaklaşık %65–72'sine yayılan ve sağ üst / köşelerde sakin karanlık negatif alan bırakan ağır çekim çapraz eliptik termal yay tasarlandı. Derin safir (`#082452 → #0052D4`), elektrik camgöbeği (`#00B4FF`), termal menekşe-magenta (`#5B2CC6 → #D9308A`), güneş amberi (`#F58A29`) ve önbellekli organik film greni dokusu birleştirildi.
- **Tek Seferlik 3 Adımlı İlk Kurulum Sihirbazı (`SetupStep`):** Uygulama ilk kez açıldığında kullanıcıya yalnızca **bir kez** sorulacak 3 adımlı kurulum akışı eklendi:
  1. **Tema Seçimi (Appearance):** Canlı mini pencere önizlemeli `Dark (#111110)`, `Light (#F6F6F4)` ve `System` seçenekleri (seçim anında tema önizlenir).
  2. **Güvenlik Denetim Profili (Security Posture):** `Developer`, `Strict` ve `Zero-Trust` varsayılan denetim profili seçimi.
  3. **Global Kısayol (Quick Launcher Shortcut):** İkili kısayol kaydedici (`TactileKeycapView` + hazır seçenekler).
- **Tekrar Sormama Garantisi:** Tamamlandığında `@AppStorage("sierraport_setup_wizard_done_v2")` bayrağı kalıcı olarak kaydedilir ve sonraki açılışlarda doğrudan ana uygulama başlar; kullanıcı ileride kısayolunu değiştirmek isterse sol menüdeki **Quick Launch** düğmesi doğrudan Kısayol adımını açar.
- **Kullanım Değeri:** Bireysel geliştiriciler ve kurumsal ekipler uygulamayı ilk kurulumda 10 saniye içinde kendi tema, güvenlik sıkılığı ve sistem geneli kısayol tercihlerine göre kişiselleştirip doğrudan kullanıma geçebilir.

---

## Cuma, 20 Kasım 2026 — `21:28` · Commit: *(push bekliyor)*
### İlk Kurulum (Onboarding) Test Betiği (`scripts/test-onboarding.sh`)
**Etkilenen Modüller:** `scripts/test-onboarding.sh`

- Uygulamanın `dev.sierraport.macos` kullanıcı tercihlerindeki `sierraport_setup_wizard_done_v2` bayrağını sıfırlayıp çalışan örneği kapatarak `SierraPort.app` uygulamasını sanki ilk kez açılıyormuş gibi başlatan çalıştırılabilir test betiği eklendi.
- `--full` parametresi verildiğinde tema, güvenlik profili, kısayol ve tüm `UserDefaults` kayıtlarını sıfırlayarak tam sıfırdan kurulum testi yapılmasını sağlar.

---

## Cuma, 20 Kasım 2026 — `21:34` · Commit: *(push bekliyor)*
### 60/120fps GPU `Canvas` Slow-Motion Termal Gradyan, `Enter (⏎)` Kısayolu ve Light Mode Mavi Palet
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/ShortcutOnboardingView.swift`

- **Yüksek Kare Hızı & Gerçek Slow-Motion (`Canvas(rendersAsynchronously: true)`):** Önceki kare hızını düşüren 4 katmanlı Gaussian `.blur(radius: 50)` ve her karede yeniden çizilen gren/material yükü kaldırıldı; yerine sıfır blur maliyetli, doğrudan GPU üzerinde çizilen yumuşak çok duraklı eliptik `RadialGradient` katmanları ve ağır çekim (`t * 0.034–0.048`) süzülme hareketi getirildi. Gren dokusu `TimelineView` dışına alınarak statik katman haline getirildi.
- **Taze ve Yönlü Adım Geçişleri:** İleri/geri yön algılayan (`isMovingForward`) kayma + hafif ölçek + opaklık spring geçişleri (`.spring(response: 0.36, dampingFraction: 0.88)`) ile tema, güvenlik profili ve kısayol adımları arasında sıfır takılmalı geçiş sağlandı.
- **Enter (`⏎`) ile İlerleme Kısayolu:** `NSEvent` yerel klavye dinleyicisi ile özel kısayol kaydı aktif değilken `Enter` / `Return` tuşuna basıldığında doğrudan bir sonraki adıma geçilmesi (son adımda kurulumu tamamlaması) ve ana butonlarda `⏎` tuş rozeti gösterilmesi eklendi.
- **Light Mode Canlı Mavi Termal Degrade:** Açık tema seçildiğinde arka planın soluklaşmasına yol açan tam ekran örtü kaldırıldı; `#F5F6F8` porselen zemin üzerinde net ve canlı görünen derin okyanus safiri (`#082452 → #0E52D8`), elektrik gök mavisi (`#00A8FF → #38BDF8`), kraliyet kobalt-indigo (`#1D4ED8`) ve buzul camgöbeği (`#06B6D4`) termal paleti eklendi.

---

## Cumartesi, 21 Kasım 2026 — `10:07` · Commit: *(push bekliyor)*
### `macos/SierraPortApp/` Klasörünün GitHub Dışına Alınması (`.gitignore`)
**Etkilenen Modüller:** `.gitignore`

- `macos/SierraPortApp/` klasörü `.gitignore` dosyasına eklendi.
- Daha önce Git tarafından takip edilen 11 dosya `git rm -r --cached macos/SierraPortApp` ile yerel diskteki dosyalara dokunulmadan Git indeksinden çıkarıldı; bir sonraki commit & push sonrasında `macos/SierraPortApp/` GitHub deposunda görünmeyecek.

---

## Cumartesi, 21 Kasım 2026 — `10:15` · Commit: *(push bekliyor)*
### Apple Liquid Glass Arayüz Sistemi, Yüzen Cam Kenar Çubuğu ve Terminal Deck Safir Degrade
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{Theme,SierraPortApp,ContentView,VisualBlocks}.swift`

- **Yumuşatılmış Pencere Çerçevesi (`20pt` Sürekli Köşe):** `WindowThemeSync` ve ana pencere katmanında `cornerRadius: 20` (`.continuous`) ile keskin pencere köşeleri yumuşatıldı ve dış çerçeveye ince ışık yansımalı cam kenarlık eklendi.
- **Yüzen Apple Cam Kenar Çubuğu (`floatingGlassSidebar`):** Sol menü çubuğu pencere kenarlarından 8pt içeride duran, `18pt` yuvarlatılmış, `.ultraThinMaterial` + `sidebarGlassFill` saydam cam paneline dönüştürüldü; aktif sekme kapsül (`Capsule`) cam hapı ve alt kontrol kutuları (Quick Launch, Tema, Rust Core) eşit yükseklik ve köşe yarıçaplarıyla hizalandı.
- **Terminal Deck Derin Safir Degrade Arka Planı (`TerminalAmbientBackdrop`):** Koyu temada `#0A0B0E` zemin üzerinde alt-orta bölgeden yayılan derin gece safiri/lacivert (`#1A3B9C → #0D2264 → #08143A`), açık temada ise ferah gök-safir parlamalı arka plan eklendi.
- **Eşit & Uyumlu Cam Kutular (`raycastCard`, `KpiPill`, Quick Commands):** Uygulama genelindeki tüm kartlar, KPI kutuları (`minHeight: 68`), komut bloğu kartları (`cornerRadius: 16`), üst durum kapsülleri, alt aksiyon çubuğu ve 2 sütunlu eşit genişlik/yükseklik (`40pt`) hızlı komut kutuları tek tip Apple buzlu cam opaklığı ve parlak üst kenarlık (specular rim) ile birleştirildi.

---

## Cumartesi, 21 Kasım 2026 — `10:19` · Commit: *(push bekliyor)*
### Native macOS Pencere Çerçevesi Düzeltmesi ve Boş Terminal Deck Degrade Sınırlandırması
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{Theme,SierraPortApp,ContentView}.swift`

- **Pencere Çerçevesi & Trafik Işıkları Düzeltmesi:** `NSThemeFrame` (`window.contentView?.superview`) üzerindeki bozucu katman kırpması, `isOpaque = false` ve boş `.windowToolbarStyle(.unified)` çakışması kaldırıldı; pencere doğal macOS yuvarlatılmış çerçevesine ve hatasız kapat/küçült/büyüt düğmelerine kavuşturuldu. Yüzen cam kenar çubuğu `.ignoresSafeArea(.container, edges: .top)` ile üst çubukla kusursuz hizalandı.
- **Yalnızca Boş Terminal Deck'te Safir Degrade:** `TerminalAmbientBackdrop` sadece `vm.selectedTab == .terminal && vm.blocks.isEmpty` durumunda (henüz komut çalıştırılmamışken) görünür hale getirildi; komut girildiğinde ve **Live Watch**, **Security Audit**, **Analytics** sekmelerinde klasik düz `#111110` / `#F6F6F4` tema rengine dönülür.

---

## Cumartesi, 21 Kasım 2026 — `10:25` · Commit: *(push bekliyor)*
### Trafik Işıkları Konumlandırması, Light Mode Gölge Optimizasyonu ve Dinamik Cam Gezinme Çubuğu
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{Theme,ContentView}.swift`

- **Trafik Işıkları Yüzen Kenar Çubuğu İçine Hizalandı:** `WindowThemeSync.Coordinator` üzerinden macOS `closeButton` / `miniaturizeButton` / `zoomButton` düğmeleri pencere yeniden boyutlandırma ve odak değişimlerinde dahi yüzen cam kenar çubuğunun sol üst köşesinin içine (`x: 18/38/58`, `topInset: 14pt`) oturacak şekilde konumlandırıldı; marka başlığı `42pt` üst boşlukla sıfır çakışmayla hizalandı.
- **Light Mode Neredeyse Sıfır Arka Gölge:** `SierraTheme.cardShadow` (Light Mode'da `%3` opaklık, `radius: 3, y: 1`) ve net `1px` `glassBorderTop`/`glassBorderBottom` kenarlıkları eklenerek beyaz temada kutuların etrafını karartan koyu gölgeler kaldırıldı.
- **Dinamik Apple Glass Satır Gezinme Çubuğu:** Aktif Terminal Deck üstündeki uyumsuz `Tab / ↓ browse rows` metni kaldırılıp yerine `RaycastKeycap` tuş rozetli (`[Tab] Browse N rows` / `[⏎] Inspect · [Esc] Back`) cam kapsülü ve kompakt cam aksiyon kapsülü (Expand / Collapse / Clear) yerleştirildi.

---

## Cumartesi, 21 Kasım 2026 — `10:30` · Commit: *(push bekliyor)*
### Gemini Stili Trafik Işıkları, Katlanabilir Sol Menü (`⌘\`) ve Dinamik Tıklanabilir Butonlar
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{Theme,ContentView,ShortcutOnboardingView}.swift`

- **Gemini Stili `MacTrafficLightsView`:** macOS'un 28pt'lik dar başlık çubuğuna sıkışan sistem düğmeleri gizlenip yerine yüzen cam kenar çubuğunun sol üstüne tam hizalanan, grup hover simgeli (`×`, `−`, `+`) ve geniş `16×16pt` tıklama alanlı `MacTrafficLightsView` eklendi.
- **Katlanabilir Sol Menü Çubuğu (`sidebar.left` & `⌘\`):** Sol menünün sağ üstüne arama (`magnifyingglass`) ve menüyü kapatma (`sidebar.left`) düğmeleri eklendi; menü kapatıldığında sağ çalışma alanı tam genişliğe açılır ve sol üstte trafik ışıklarıyla birlikte yeniden açma düğmesi belirir.
- **Tıklanabilirlik & Dinamik Buton Hissi (`TactileGlassButtonStyle` + `WindowDragArea`):** Tıklamaları yutan `window.isMovableByWindowBackground = true` kapatıldı; pencere sürükleme yalnızca üst boş çubuğa (`WindowDragArea`) taşındı. Tüm menü, araç çubuğu, tema ve hızlı komut butonları hover vurgusu, basma ölçek animasyonu (`0.96`) ve tam çerçeveli geniş tıklama alanıyla (`contentShape`) güncellendi.

---

## Cumartesi, 21 Kasım 2026 — `10:34` · Commit: *(push bekliyor)*
### Apple Design Skill (macOS HIG) Uyum Revizyonu
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{Theme,SierraPortApp,ContentView,ShortcutOnboardingView}.swift`

- **Sistem Erişilebilirlik Durumları (`liquid-glass.md`, `accessibility.md`, `motion.md`):**
  - `ThermalEclipseBackground`, macOS **Hareketi Azalt (`accessibilityReduceMotion`)** açıkken sürekli `TimelineView` animasyonunu durdurup sakin statik kareye geçer.
  - `RaycastCardModifier` ve yüzen cam kenar çubuğu, **Saydamlığı Azalt (`accessibilityReduceTransparency`)** açıkken opak yüzeylere döner; **Kontrastı Artır (`colorSchemeContrast == .increased`)** modunda kenarlık kontrastını güçlendirir.
- **Yerel macOS Menü Çubuğu Komutları (`designing-for-macos.md`):** `SierraPortDesktopApp` içine `.commands` ile **Navigate** (`Terminal Deck ⌘1`, `Live Watch ⌘2`, `Security Audit ⌘3`, `Analytics ⌘4`, `Toggle Forensic Inspector ⌥⌘I`) ve **Actions** (`Open Quick Launcher`, `Refresh Metrics ⌘R`, `Configure Global Shortcut…`) menüleri eklendi.
- **macOS 10pt Tipografi Tabanı & VoiceOver Etiketleri (`accessibility.md`):** 10pt altındaki mikro etiketler (`8.5pt`, `9.5pt`) macOS HIG tabanı olan `10pt`'ye yükseltildi; yalnızca simge içeren tüm butonlara `.accessibilityLabel(...)` eklendi.
- **Ölçülü Dinamik Buton Geri Bildirimi (`motion.md`, `pointing-devices.md`):** Sık kullanılan butonlarda aşırı zıplama olmadan `0.98` hafif basma ölçeği ve `0.10s` anlık hover tepkisi uygulandı (`Reduce Motion` açıkken animasyon sıfırlanır).

---

## Cumartesi, 21 Kasım 2026 — `10:50` · Commit: *(push bekliyor)*
### Türkçe Teknik Analiz, Mimari ve Yol Haritası PDF Raporu
**Etkilenen Modüller:** `docs/SierraPort-Teknik-Analiz-Raporu.pdf`

- `technical-writing` yönergelerine uygun, tüm metrikleri doğrudan kaynak kod ve derleme çıktılarından doğrulanmış 7 sayfalık Türkçe teknik analiz ve müşteri sunum PDF raporu oluşturuldu.
- Kapak sayfası, yönetici özeti, rakip karşılaştırması, vektörel SVG sistem mimarisi diyagramı, modül/satır dağılımı, CLI ve güvenlik denetim motoru analizi, yerel macOS uygulaması ve Apple HIG uyumu, mimari ödünleşimler/kısıtlar, bireysel/kurumsal değer önerileri ile kısa/orta/uzun vadeli gelecek öngörüleri yer alır.

---

## Cumartesi, 21 Kasım 2026 — `11:10` · Commit: *(push bekliyor)*
### Canlı Grafik Motoru Düzeltmesi ve Etkileşimli Analitik Grafikleri
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{ViewModel,ContentView,VisualBlocks}.swift`

- **Seçenek Değişiminde Grafik Bozulma Kök Nedeni Giderildi:** `500ms / 1s / 2s / 5s` aralığı veya `All States` değiştirildiğinde yeni başlayan `sierraport stream` alt sürecinin `tick` sayacını `1`'den sıfırlaması nedeniyle X ekseninin ters dönüp çökmesi (`minTick > maxTick`) sorunu, kesin artan `historySeq` sayacı ve eski alt süreç satırlarını eleyen `streamGeneration` belirteciyle tamamen çözüldü. Aralık değişiminde grafik kesintisiz devam eder; `All States` değişiminde ölçek temizce sıfırlanır.
- **Etkileşimli Canlı Grafik (`LiveSparklineView`):** Grafik başlığına anlık geçişli `All / Active / Exposed / Scan ms` metrik seçici hapları, fare ile grafik üzerinde gezindikçe dikey kılavuz çizgisi (`RuleMark`) + anlık zaman/değer okuması (`onContinuousHover`) ve en güncel noktada canlı uç işaretçisi (`PointMark`) eklendi.
- **Analitik Kartları (`StatsVisualView`):** Tüm grafik kartları tek tip Apple Liquid Glass `.raycastCard(cornerRadius: 16)` çerçevesine, 10pt minimum HIG tipografisine ve akıcı değer geçiş animasyonlarına kavuşturuldu.

---

## Cumartesi, 21 Kasım 2026 — `11:16` · Commit: *(push bekliyor)*
### Tam Sistem Hata Taraması (`diagnosing-bugs`) ve 7 Teknik Hata Düzeltmesi
**Etkilenen Modüller:** `src/audit.rs`, `src/scanner/macos.rs`, `macos/SierraPortApp/Sources/SierraPortApp/{Bridge,ViewModel,QuickLauncherPanel}.swift`

- **Pipe Deadlock Düzeltmesi (`Bridge.swift`):** `stdout` ve `stderr` akışları eşzamanlı (`DispatchGroup`, ayrı `runSync` içinde Swift 6 uyumlu) okunarak 64 KB üstü çıktılarda kilitlenme riski ortadan kaldırıldı ve dosya tanımlayıcıları (`close()`) temizlendi.
- **Akış Tamponu Eşzamanlılık & Sızıntı Düzeltmesi (`Bridge.swift`):** `startStream` içindeki `buffer` `NSLock` ile korundu, 4 MB üst sınır eklendi ve `terminationHandler` ile kapanışta `readabilityHandler` temizlendi.
- **Yetim Alt Süreç Koruması (`ViewModel.swift`):** `NSApplication.willTerminateNotification` dinleyicisi eklenerek uygulama kapatıldığında `sierraport stream` arka plan sürecinin anında sonlandırılması garanti altına alındı.
- **Güvenlik Profili Kalıcılığı (`ViewModel.swift`):** İlk kurulumda veya Audit sekmesinde seçilen `auditProfile` artık `UserDefaults` (`sierraport_audit_profile`) üzerinden kalıcı olarak saklanır.
- **Quick Launcher Tıklama & Pencere Geri Getirme (`QuickLauncherPanel.swift`):** `isMovableByWindowBackground = false` yapılarak tıklama yutulması giderildi; `orderFrontRegardless()` ile ana pencereye dönüş sağlamlaştırıldı.
- **Rust Clippy Sıfır Uyarı (`src/audit.rs`, `src/scanner/macos.rs`):** `collapsible_if` ve `type_complexity` (`PsAncestryEntry`) uyarıları giderilerek `cargo clippy --all-targets -- -D warnings` sıfır uyarıyla geçildi.

---

## Cumartesi, 21 Kasım 2026 — `11:40` · Commit: *(push bekliyor)*
### Güvenlik Denetimi Bulgularının Düzeltilmesi ve Sistem Sertleştirmesi
**Etkilenen Modüller:** `src/{audit,commands,display,main,snapshot}.rs`, `src/scanner/{mod,macos}.rs`, `macos/SierraPortApp/Sources/SierraPortApp/{Bridge,Models,ViewModel}.swift`

- **İkili Güven Doğrulaması & AirPlay Muafiyeti (`src/audit.rs`):** `verify_binary_signature` artık önce `/usr/bin/codesign --verify --strict` ile kriptografik imza doğrulaması yapar ve çıkış kodunu denetler (`/System/` ön ek kısayolu kaldırıldı); `is_suspicious_path` yolları kanonikleştirip `/private/var/tmp/` dizinini de kapsar; `is_apple_airplay` gerçek `/System/Library/CoreServices/ControlCenter.app/` yolunu şart koşar.
- **Zero-Trust LAN Denetimi & Kabuk Kaçışı (`src/audit.rs`):** `ZeroTrust` ve `Strict` profillerinde `BindScope::Lan` dinleyicileri de kapsam dahiline alındı; `TRUST-UNSIGNED` `remediation_cmd` yolları POSIX tek-tırnak (`shell_single_quote`) ile kaçışlandı.
- **Terminal / NDJSON / JSONL / Markdown Kaçışı (`src/scanner/mod.rs`, `src/display.rs`, `src/commands.rs`, `ViewModel.swift`):** HTTP `Server:` başlığı ve `Host:` isteği kontrol karakterlerinden arındırıldı; `sanitize_terminal` ile `diff` ve `inspect` çıktıları korundu; `run_stream` ve `run_watch --log` tam RFC 8259 `json_escape` kullanacak şekilde düzeltildi; `exportAuditMarkdown` Markdown/tablo kaçışı eklendi.
- **Dosya Güvenliği, Mutlak Sistem Yolları & PID Koruması (`src/snapshot.rs`, `src/commands.rs`, `src/scanner/{mod,macos}.rs`, `Bridge.swift`, `Models.swift`):** `save_snapshot`, `load_snapshot` (16 MiB sınır + `is_file()`) ve `append_log_line` `O_NOFOLLOW` + `0o600` ile sertleştirildi; `/usr/sbin/lsof`, `/bin/ps`, `/usr/bin/codesign`, `/bin/kill` mutlak yollarına geçildi; `kill` için `pid <= 1`, `self-PID` ve boş `--proc` koruması eklendi; `Bridge.locateBinary` CWD araması `#if DEBUG` içine alındı; `AuditFinding.allowlistKey` `endpoint` alanını kapsayacak şekilde genişletildi ve `/tmp/sierraport_base.json` önerisi `~/sierraport_base.json` olarak güncellendi.
- **Regresyon Testleri (`src/main.rs`):** 2 yeni güvenlik regresyon testi eklendi (toplam `9/9` test).

---

## Cumartesi, 21 Kasım 2026 — `11:44` · Commit: *(push bekliyor)*
### Skill Klasörlerinin Tek Çatı Altında (`.agents/skills/`) Toplanması
**Etkilenen Modüller:** `.gitignore`, `.agents/skills/`

- Proje kökünde `npx skills` tarafından oluşturulan ve tamamı `.agents/skills/` dizinine işaret eden 10 yinelemeli symlink klasörü (`.augment`, `.autohand`, `.bob`, `.claude`, `.commandcode`, `.continue`, `.cortex`, `.goose`, `.kimchi`, `/skills`) silinip Git indeksinden çıkarıldı.
- Tüm 16 skill yalnızca tek kanonik klasör olan `.agents/skills/` altında korundu (Antigravity'nin skill keşif mekanizması kesintisiz çalışmaya devam eder) ve yinelemeli symlink klasörleri `.gitignore` dosyasına eklendi.

---

## Cumartesi, 21 Kasım 2026 — `15:05` · Commit: *(push bekliyor)*
### Kapalı Kenar Çubuğu Trafik Işıkları Düzeltmesi, `14pt` Pencere Düğmeleri ve `22pt` Yumuşak Çerçeve
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{Theme,SierraPortApp,ContentView}.swift`

- **Kapalı Sol Menü Trafik Işıkları Hizalaması (`ContentView.swift`):** Sol menü kapatıldığında `WindowDragArea`'nın trafik ışıklarını sıkıştırması `layoutPriority(-1)` + `.fixedSize()` ile giderildi; trafik ışıkları ve kenar çubuğu açma düğmesi üst sağdaki haplarla uyumlu tek bir `34pt` yüksekliğinde yüzen Apple Glass kapsülüne alındı.
- **Daha Büyük Pencere Düğmeleri (`Theme.swift`):** `MacTrafficLightsView` kırmızı/sarı/yeşil düğmeleri `12pt → 14pt` (tıklama alanı `18×18pt`, hover simgeleri `8pt`) olarak büyütüldü.
- **Yumuşatılmış Pencere Köşeleri (`SierraPortApp.swift`, `Theme.swift`):** `NSThemeFrame`'e dokunmadan şeffaf pencere zemini üzerinde `22pt` sürekli (`continuous`) yuvarlatılmış çerçeve ve ince `1px` cam kenarlık eklendi.

---

## Cumartesi, 21 Kasım 2026 — `15:09` · Commit: *(push bekliyor)*
### Pencere Üst Çubuk Kırpması ve Çift Çerçeve Düzeltmesi (Apple HIG)
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{SierraPortApp,Theme,ContentView}.swift`

- **Üst 28pt Boşluk & Kesilen Kontroller Düzeltildi:** Kök `ZStack` üzerindeki `.clipShape` 28pt güvenli alanın altından başladığı için üst kenardaki trafik ışıkları ve durum haplarını yarıdan kesiyor ve üstte şeffaf boşluk bırakıyordu. Kök `ZStack`'e `.ignoresSafeArea()` eklenip çakışan ikinci `.clipShape`/`.overlay` çerçevesi kaldırıldı.
- **Native macOS Pencere Kompozisyonu (`Theme.swift`):** `window.styleMask.insert(.fullSizeContentView)` + opak tema eşleşmeli zeminle macOS'un kendi donanım hızlandırmalı yuvarlatılmış pencere çerçevesi ve gölgesi tek parça, sıfır kırpma ve maksimum GPU verimliliğiyle çalışacak hale getirildi.

---

## Cumartesi, 21 Kasım 2026 — `15:11` · Commit: *(push bekliyor)*
### Kapalı Sol Menü Üst Çubuğunun Doğal Pencere Hizasına Yükseltilmesi
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/ContentView.swift`

- `topFloatingToolbar` üst boşluğu `14pt → 6pt`, yatay boşluğu `16pt → 12pt` ve kapalı sol menü trafik ışıkları kapsül yüksekliği `34pt → 30pt` olarak sıkılaştırıldı; sol menü kapalıyken pencere düğmeleri doğrudan doğal macOS pencere üst kenarına hizalanır.

---

## Cumartesi, 21 Kasım 2026 — `15:14` · Commit: *(push bekliyor)*
### Sol Menü Açık/Kapalı Sabit Konumlu Trafik Işıkları (`overlay(alignment: .topLeading)`)
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/ContentView.swift`

- `MacTrafficLightsView` tek bir kalıcı `.overlay(alignment: .topLeading)` katmanına (`x: 20pt, y: 18pt`) sabitlendi; sol menü açılıp kapatıldığında kırmızı/sarı/yeşil pencere düğmeleri 1 piksel bile yerinden oynamadan daima birebir aynı yükseklik ve yatay hizada kalır.

---

## Cumartesi, 21 Kasım 2026 — `15:18` · Commit: *(push bekliyor)*
### Kapalı Sol Menü Düğmesinin Trafik Işıklarıyla Aynı Satıra Hizalanması
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/ContentView.swift`

- Sol menü kapalıyken (`!isSidebarVisible`) görünen `sidebar.left` düğmesi, `topFloatingToolbar` içinden çıkarılıp doğrudan `MacTrafficLightsView` ile aynı `.overlay(alignment: .topLeading)` içindeki sabit `26pt` yükseklikli (`top: 12pt`, dikey merkez `y = 25pt`) `HStack(alignment: .center, spacing: 12)` satırına taşındı.
- Böylece hem trafik ışıkları sol menü açılıp kapandığında 1 piksel bile kaymıyor (`y = 18pt`), hem de sol menü açma düğmesi aşağı düşmeden trafik ışıklarının hemen yanında tam aynı yatay eksende hizalanıyor.
- `topFloatingToolbar` sol tarafında yalnızca `118pt` tıklama geçirmeyen bir boşluk bırakılarak `WindowDragArea` sürükleme alanının overlay düğmesinin tıklamasını engellemesi önlendi.

---

## Cumartesi, 21 Kasım 2026 — `15:22` · Commit: *(push bekliyor)*
### Terminal Deck ve Sol Menü Başlığında Monokrom Maskot Logosu
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{Theme,ContentView}.swift`

- `SierraMascotMarkView` bileşeni `@Environment(\.colorScheme)` ile açıkça **Dark Mod'da saf beyaz (`.white`), Light Mod'da saf siyah (`.black`)** olacak şekilde güncellendi.
- **Terminal Deck (`emptyTerminalHeroView`):** `SierraPort` başlığının üzerindeki mavi kareli uygulama ikonu (`SierraAppIconView`) yerine yalın monokrom maskot (`SierraMascotMarkView(size: 72)`) yerleştirildi.
- **Sol Menü Başlığı:** Sol menü üstündeki `SierraPort` / `PORT MONITOR` yazıları ve mavi kareli ikon kaldırılarak yerine yalnızca temaya duyarlı monokrom maskot (`SierraMascotMarkView(size: 32)`) bırakıldı.

---

## Pazartesi, 23 Kasım 2026 — `21:36` · Commit: *(push bekliyor)*
### Apple HIG Crimson Tema Paleti (`#EB0020` / `#1A0003` Dark / `#FFFFFF` Light)
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{Theme,SierraPortApp,QuickLauncherPanel,ShortcutOnboardingView,ContentView,VisualBlocks}.swift`

- **Yeni Renk Sistemi (`Theme.swift`):** Eski mavi/safir tema yerine yüklenen Crimson renk skalası (`#FFE6E9` → `#EB0020` → `#1A0003`) uygulandı. Dark Mod ana tuvali ve pencere arka planı birebir **`#1A0003`**, Light Mod ana tuvali ve pencere arka planı saf **`#FFFFFF`**, ana marka vurgu rengi **`#EB0020`** (`accent`) ve yüksek kontrastlı metin/grafik tonu (`accentBright`: Dark `#FF5C72`, Light `#D1001C`) olarak tanımlandı (Apple HIG `color.md` & `dark-mode.md` kontrast standartlarına uygun).
- **Liquid Glass, Ambient & Onboarding Uyumu:** `glassFill`, `glassFillElevated`, `sidebarGlassFill`, `selectionFill`, `TerminalAmbientBackdrop` ve `ThermalEclipseBackground` (GPU slow-motion gradyan) UX/UI düzenini hiç bozmadan yeni Crimson paletine uyarlandı.
- **Sistem Kontrolleri ve Grafikler:** Kök pencere, `MenuBarView` ve `QuickLauncherPanel` üzerinde `.tint(SierraTheme.accent)` tanımlandı; `ContentView` komut çubuğu, çipler, canlı port tabloları ve `LiveSparklineView` grafikleri eski camgöbeği/mavi yerine `#EB0020` / `accentBright` vurgularına geçirildi.

---

## Pazartesi, 23 Kasım 2026 — `21:40` · Commit: *(push bekliyor)*
### Nötr Karanlık Zemin (`#07080A`) ve Dengeli `#EB0020` Vurgu Optimizasyonu
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{Theme,ShortcutOnboardingView,ContentView,VisualBlocks}.swift`

- **Nötr `#07080A` Zemin ve Saf Cam Yüzeyler (`Theme.swift`):** Dark Mod ana arka planı ve pencere zemini saf nötr **`#07080A`**, kenar çubuğu `#0C0D10`, kart yüzeyleri `#111317`, tüm kenarlıklar, seçimler ve Liquid Glass katmanları kırmızı tondan arındırılmış saf nötr cam olarak güncellendi. Light Mod saf `#FFFFFF` korundu.
- **Ölçülü `#EB0020` Kullanımı (Apple HIG):** Kırmızı ton yalnızca ana odak noktalarında (birincil `Run`/`Continue` butonları, aktif komut çubuğu odak halkası, `❯` istemi, canlı grafik çizgisi ve aktif aksiyonlar) bırakıldı; port tablosu numaraları, öneri çipi ikonları, özet kapsülleri ve `TCP/UDP` göstergeleri sakin nötr tipografiye (`.primary` / `.secondary`) çekildi; `TerminalAmbientBackdrop` ortam ışığı çok hafif bir fısıltı (`0.13` Dark / `0.38` blush Light) seviyesine indirildi.

---

## Salı, 24 Kasım 2026 — `11:09` · Commit: *(push bekliyor)*
### Terminal Deck Tüm Komut Kartları İçin Slow-Motion Açılma Animasyonu
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/ContentView.swift`

- **Yumuşak Slow-Motion Eğrisi (`blockExpandAnimation`):** `stats`, `list`, `audit`, `inspect`, `probe`, `diff`, `free` ve ham çıktı dahil Terminal Deck'teki tüm CLI komut kartlarının açılma/kapanma animasyonu sert `.spring(response: 0.28)` yerine `0.62 sn` süreli yumuşak yavaşlamalı `.timingCurve(0.22, 1.0, 0.36, 1.0)` eğrisine geçirildi (Expand All / Collapse All ve chevron ikonu dahil).
- **İçerik Süzülme Katmanı (`SlowMotionBlockReveal`):** Kart genişlerken grafik, tablo ve metriklerin başlığın üstüne taşmadan (`.clipped()`) yumuşakça süzülmesi için `0.68 sn` süreli kademeli opaklık (`0 → 1`), dikey kayma (`-10pt → 0`) ve mikro ölçek (`0.985 → 1.0`) geçişi eklendi; macOS `Reduce Motion` ayarına tam uyumlu.

---

## Salı, 24 Kasım 2026 — `11:21` · Commit: *(push bekliyor)*
### Sıfır Maliyetli GitHub Releases Canlı Güncelleme Sistemi (`Restart Update`)
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{UpdateManager,SierraPortApp,ContentView}.swift`, `scripts/{build-macos-app,package-release}.sh`

- **0 Bağımlılıklı Native Güncelleyici (`UpdateManager.swift`):** Harici kütüphane olmadan (`Foundation` + Apple `CryptoKit`) GitHub Releases API (`releases/latest`) üzerinden açılışta ve her 6 saatte bir yeni sürüm denetler; yalnızca güvenilir HTTPS GitHub adreslerinden indirir, `checksums.txt` varsa SHA-256 doğrulaması yapar, hem `.zip` (`ditto`) hem `.dmg` (`hdiutil`) paketlerini destekler ve rollback korumalı atomik değişimle uygulamayı otomatik yeniden başlatır.
- **Otomatik `Restart Update` Butonu (`ContentView.swift` & `SierraPortApp.swift`):** GitHub'da daha yeni bir sürüm yayınlandığında üst araç çubuğunda otomatik olarak **`Restart Update · vX.Y.Z`** düğmesi belirir; ayrıca macOS `Actions` menüsüne manuel **Check for Updates…** komutu eklendi.
- **Tek Komutla DMG/ZIP Yayın Paketleyici (`scripts/package-release.sh`):** `./scripts/package-release.sh <sürüm>` komutuyla sürüm gömülü `.app`, web sitesi için sürükle-bırak `.dmg`, uygulama içi güncelleme için `.zip` ve `checksums.txt` dosyalarını tek seferde üretir.

---

## Salı, 24 Kasım 2026 — `11:27` · Commit: *(push bekliyor)*
### Tam Marka Geçişi: Clous & `efekanbahceci/clous` GitHub Entegrasyonu
**Etkilenen Modüller:** `scripts/{build-macos-app,package-release,test-onboarding}.sh`, `macos/SierraPortApp/Sources/SierraPortApp/{UpdateManager,SierraPortApp,ContentView,ShortcutOnboardingView,ViewModel}.swift`, `src/{display,commands,audit,cli,main,scanner/mod}.rs`

- **GitHub & Canlı Güncelleme Bağlantısı:** `git remote origin` adresi `https://github.com/efekanbahceci/clous.git`, `UpdateManager` varsayılan deposu ve `Info.plist` (`ClousUpdateRepo`) `efekanbahceci/clous` olarak güncellendi.
- **Uygulama Paketi & Dağıtım:** Paket adı `Clous.app` (`dev.clous.macos`), kurulum imajı `dist/Clous.dmg`, güncelleme arşivi `dist/Clous.zip` ve kalıcı web sitesi indirme bağlantısı `https://github.com/efekanbahceci/clous/releases/latest/download/Clous.dmg` olarak güncellendi.
- **Tüm UI ve CLI Metinleri:** Terminal Deck ana başlığı, Menü Çubuğu, İlk Kurulum Sihirbazı, Markdown güvenlik raporu dışa aktarımı, Rust CLI başlıkları (`Clous Live Watch`, `Clous Deep Inspect`, `clous --help`) ve komut örnekleri tamamen **Clous** markasına geçirildi. `cargo test` (9/9) ve tam release paketleme hatasız doğrulandı.

---

## Salı, 24 Kasım 2026 — `12:45` · Commit: *(push bekliyor)*
### Alt Durum Kartında Dinamik Sürüm Göstergesi
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/ContentView.swift`

- Kenar çubuğu alt durum kartındaki `"Rust Core Ready"` metni, `Info.plist` üzerinden dinamik okunan **`Clous v\(updateManager.currentVersion)`** (ör. `Clous v0.2.0`) sürüm göstergesiyle değiştirildi; her yeni güncellemede sürüm numarası otomatik olarak güncellenir.

---

## Salı, 24 Kasım 2026 — `12:59` · Commit: *(push bekliyor)*
### Yeni Degrade Masaüstü İkonu, `codesign` Paket Mühürleme ve Özel Tasarımlı DMG Kurulum Penceresi
**Etkilenen Modüller:** `assets/{sierraport-app-icon.png,AppIcon.icns,dmg-background.png}`, `scripts/{build-macos-app,package-release}.sh`

- **Yeni Tema İkonu (`AppIcon.icns` + `sierraport-app-icon.png`):** `#07080A` derin siyah zeminden `#47000A → #A30016 → #EB0020` kırmızı marka paletine yumuşak degrade geçişli, saf beyaz maskotlu 1024×1024 macOS squircle ikon ve 10 boyutlu Retina `.icns` paketi üretildi.
- **"Bozuk (Damaged)" Hatası Kök Neden Düzeltmesi (`build-macos-app.sh`):** Derleme sonrası ikili dosya `Info.plist=not bound` ve `Sealed Resources=none` (mühürsüz) kaldığı için macOS tarafından bozuk işaretleniyordu. Derleme hattına `codesign --force --sign -` (gömülü Rust çekirdeği) + `codesign --force --deep --sign -` (`Clous.app`) + `codesign --verify --deep --strict` doğrulaması eklendi (`Identifier=dev.clous.macos`, `Info.plist entries=14`, `Sealed Resources version=2`).
- **Özel Tasarımlı Retina DMG Penceresi (`package-release.sh` + `assets/dmg-background.png`):** `1320×840` (`@2x` 144 DPI) `#07080A` + `#EB0020` oklu özel kurulum arka planı, `.VolumeIcon.icns`, gizli araç çubuğu ve tam hizalı `Clous.app → Applications` sürükle-bırak yerleşimiyle profesyonel `dist/Clous.dmg` oluşturuldu.

---

## Salı, 24 Kasım 2026 — `13:04` · Commit: *(push bekliyor)*
### Düz Siyah + `#EB0020` Maskot İkonu ve Metinsiz Kırmızı Degrade DMG Ekranı
**Etkilenen Modüller:** `assets/{sierraport-app-icon.png,AppIcon.icns,dmg-background.png}`, `scripts/package-release.sh`

- **Masaüstü İkonu:** Degrade kaldırılarak düz `#07080A` siyah arka plan üzerinde birebir **`#EB0020`** marka kırmızısı Clous maskotu üretildi (`AppIcon.icns` ve `sierraport-app-icon.png`).
- **DMG Kurulum Penceresi:** Üstteki `"Clous"` ve alt metinler tamamen kaldırıldı; yalnızca `#07080A → #47000A → #EB0020` kırmızı degrade zemin, ortalanmış cam bırakma alanları ve sade beyaz ok ile `Clous.app → Applications` (`y = 206`) düzeni paketlendi.

---

> **Not:** Bundan sonraki tüm geliştirmeler aynı formatta (**Gün, Tarih — Saat (TRT) · Commit Kodu** + değişiklik detayları ve kullanım analizi) bu dosyaya kaydedilecektir.
