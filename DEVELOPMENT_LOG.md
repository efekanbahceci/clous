# SierraPort — Geliştirme Yolu, Mühendislik Günlüğü ve Kullanım Analizi

Bu doküman, **SierraPort** projesinin ilk sürümünden itibaren geçirdiği tüm mimari evrimi, yapılan her geliştirmenin **teknik amacını**, **bireysel geliştiriciler** ve **kurumsal ekipler (DevSecOps, SRE, SOC, IT Güvenlik)** için ürettiği somut değeri kronolojik ve sistematik olarak kayıt altına alır.

---

## Kronolojik Zaman Çizelgesi ve GitHub Kayıtları

| Faz | Gün & Tarih | Saat (TRT) | Git Commit | Geliştirme Özeti |
|---|---|---|---|---|
| **Başlangıç** | Perşembe, 19 Kasım 2026 | `14:48` | `cd81280` | Initial commit (depo kurulumu) |
| **Faz 1** | Perşembe, 19 Kasım 2026 | `14:59` | `eea6881` | Çekirdek Rust CLI (`v0.1.0`) — `list`, `watch`, `check`, `who`, `kill`, `stats` |
| **Bakım** | Cuma, 20 Kasım 2026 | `13:41` | `600994b` | `display.rs` import düzenlemesi |
| **Faz 2** | Cuma, 20 Kasım 2026 | `13:53` | `bb9de39` | Gelişmiş port analiz, `audit`, `inspect`, `snapshot`/`diff`, `free`, `wait` (`v0.2.0`) |
| **Faz 3** | Cuma, 20 Kasım 2026 | `14:00` – `14:16` | `6007630`, `d06a727` | Titremesiz In-Place `watch` TUI, `DOCS.md`, İngilizce `README.md` ve Apple-stili SVG banner'lar |
| **Faz 4** | Cuma, 20 Kasım 2026 | `14:32` | `87104ac` | Native macOS `SierraPort.app` (SwiftUI + Rust `stream` NDJSON + Menu Bar Extra) |
| **Faz 5** | Cuma, 20 Kasım 2026 | `15:20` | `cca4b1a` | Katlanabilir Terminal Deck, dinamik Swift Charts, `#111110` Dark/Light tema, `sierraport-preview.png` |
| **Faz 6** | Cuma, 20 Kasım 2026 | `15:33` | `8143ede` | Yeni Nesil Güvenlik & Binary Güven Denetim Motoru (`codesign`, Firewall Posture, Deep Probe, Allowlist, Export MD) |

---

## İçindekiler

1. [Faz 1 — Çekirdek Rust CLI Altyapısı (v0.1.0)](#faz-1--çekirdek-rust-cli-altyapısı-v010)
2. [Faz 2 — Gelişmiş Port Analiz, Denetim ve Otomasyon Motoru (v0.2.0)](#faz-2--gelişmiş-port-analiz-denetim-ve-otomasyon-motoru-v020)
3. [Faz 3 — Titremesiz Yerinde Canlı İzleme (In-Place TUI) & Kapsamlı Dokümantasyon](#faz-3--titremesiz-yerinde-canlı-izleme-in-place-tui--kapsamlı-dokümantasyon)
4. [Faz 4 — Native macOS Masaüstü Uygulaması (`SierraPort.app`: SwiftUI + Rust Core)](#faz-4--native-macos-masaüstü-uygulaması-sierraportapp-swiftui--rust-core)
5. [Faz 5 — Dinamik UI/UX, Katlanabilir Terminal Deck ve `#111110` Adaptif Tema Sistemi](#faz-5--dinamik-uiux-katlanabilir-terminal-deck-ve-111110-adaptif-tema-sistemi)
6. [Faz 6 — Yeni Nesil Güvenlik & Binary Güven Denetim Motoru (Code-Signature, Firewall Posture, Deep Probe, Policy & Raporlama)](#faz-6--yeni-nesil-güvenlik--binary-güven-denetim-motoru)

---

## Faz 1 — Çekirdek Rust CLI Altyapısı (v0.1.0)
**Zaman:** Perşembe, 19 Kasım 2026 — `14:59` (TRT / UTC+3)  
**Git Commit:** `eea6881` (Başlangıç: `cd81280` — `14:48`)  
**Etkilenen Modüller:** `src/main.rs`, `src/cli.rs`, `src/models.rs`, `src/commands.rs`, `src/display.rs`, `src/scanner/{linux,macos,windows}.rs`

### Ne Yapıldı?
- Sıfır harici bağımlılıklı (saf Rust `std`) çapraz platform port izleme CLI aracı oluşturuldu.
- Linux'ta doğrudan `/proc/net/*` okuma, macOS'ta `lsof`, Windows'ta `netstat` + `tasklist` desteği kuruldu.
- Temel `list`, `watch`, `check`, `who`, `kill`, `stats` komutları eklendi.

### Neden Yapıldı?
- `lsof`, `netstat`, `ss` gibi işletim sistemine göre değişen karmaşık komutların yerine tek, tutarlı, yüksek hızlı ve bağımlılıksız bir temel oluşturmak.

---

## Faz 2 — Gelişmiş Port Analiz, Denetim ve Otomasyon Motoru (v0.2.0)
**Zaman:** Cuma, 20 Kasım 2026 — `13:53` (TRT / UTC+3)  
**Git Commit:** `bb9de39`  
**Etkilenen Modüller:** `src/audit.rs`, `src/snapshot.rs`, `src/models.rs`, `src/scanner/mod.rs`, `src/scanner/macos.rs`, `src/scanner/linux.rs`, `src/display.rs`, `src/cli.rs`, `src/commands.rs`

### Ne Yapıldı?
- **Zengin Süreç Metadata'sı:** macOS'ta tek seferlik toplu (batched) `ps`, Linux'ta `/proc/<pid>/status` üzerinden `user`, `ppid`, `memory_kb` (RSS) ve tam `cmdline` eklendi.
- **Bind Kapsamı Sınıflandırması (`BindScope`):** Her soket `LOCAL`, `LAN`, `ALL(*)` veya `PUBLIC` olarak otomatik etiketlendi.
- **Runtime / Container Etiketleme:** `[container]`, `[database]`, `[proxy/web]`, `[js/ts]`, `[python]`, `[jvm]` bağlam etiketleri eklendi.
- **Yeni Komutlar:**
  - `inspect <port> [--probe]`: Süreç soyağacı (ancestry), aktif peer bağlantıları ve canlı protokol/banner probu (HTTP, SSH, Redis, SMTP/FTP, MySQL, TLS).
  - `audit [--strict]`: 0–100 güvenlik skoru, dışa açık veritabanı ve `CLOSE_WAIT`/`TIME_WAIT` soket sızıntı tespiti.
  - `snapshot save` & `diff [--fail-on-drift]`: Baseline JSON kaydı ve canlı sistem sapma (drift) analizi.
  - `free` & `wait`: Boş port bulucu ve CI/CD port hazır/kapalı bekleyici.
- **Çoklu Çıktı & Sıralama:** `--format table|json|csv|compact`, `--wide`, `--sort port|pid|process|state|proto|mem`, `--exposed`, `--state`, `--user`, ASCII bar grafikli `stats`.

### Kullanım Değerleri
- **Bireysel Geliştirici:** `EADDRINUSE` çakışmalarını saniyeler içinde çözme (`who`, `kill --wait`), test script'lerinde dinamik boş port tahsisi (`free --plain`), Docker/DB açılışını bekleme (`wait`).
- **Kurumlar / SRE:** Sunucu baseline'ı alıp (`snapshot save`) yetkisiz port veya süreç değişimlerini otomatik yakalama (`diff --fail-on-drift`).

---

## Faz 3 — Titremesiz Yerinde Canlı İzleme (In-Place TUI) & Kapsamlı Dokümantasyon
**Zaman:** Cuma, 20 Kasım 2026 — `14:00` – `14:16` (TRT / UTC+3)  
**Git Commit:** `6007630` (`14:00`), `d06a727` (`14:16`)  
**Etkilenen Modüller:** `src/commands.rs`, `src/display.rs`, `DOCS.md`, `README.md`, `assets/sierraport-banner-{dark,light}.svg`

### Ne Yapıldı?
- `watch` komutu **Alternate Screen Buffer (`\x1b[?1049h`)**, imleç gizleme (`\x1b[?25l`), atomik tek-yazım (`\x1b[H` + `\x1b[K` + `\x1b[J`) ve temiz `SIGINT` (`Ctrl+C`) geri yüklemesiyle gerçek bir titremesiz TUI paneline dönüştürüldü.
- Türkçe teknik rehber (`DOCS.md`), İngilizce kapsamlı `README.md` ve Apple UI tasarım diline uygun şeffaf arka planlı Dark/Light adaptif SVG marka banner'ları eklendi.

### Neden Yapıldı?
- Terminal geçmişini (scrollback) kirletmeden `htop`/`btop` kalitesinde canlı izleme sağlamak ve projeyi açık kaynak standartlarında dokümante etmek.

---

## Faz 4 — Native macOS Masaüstü Uygulaması (`SierraPort.app`: SwiftUI + Rust Core)
**Zaman:** Cuma, 20 Kasım 2026 — `14:32` (TRT / UTC+3)  
**Git Commit:** `87104ac`  
**Etkilenen Modüller:** `src/commands.rs` (`stream` NDJSON), `macos/SierraPortApp/Sources/SierraPortApp/*`, `scripts/build-macos-app.sh`

### Ne Yapıldı?
- Rust çekirdeğine satır bazlı JSON olay akışı sağlayan `sierraport stream -i <ms>` eklendi (~30ms tarama gecikmesi).
- Ghostty mimarisi (sistem dili çekirdek + native macOS arayüz) örnek alınarak sıfır harici Swift bağımlılıklı **2.6 MB** boyutunda native **`SierraPort.app`** inşa edildi.
- 4 ana modül: **Terminal Deck** (komut yazıp görsel kart + Raw/Visual geçişi), **Live Watch** (canlı KPI + olay akışı), **Security Audit**, **Analytics** (native Swift Charts) + sağdan açılan **Forensic Inspector** + **macOS Menu Bar Extra**.

### Neden Yapıldı?
- CLI hızından ve gücünden ödün vermeden, karmaşık port/süreç/güvenlik verilerini tek bakışta anlaşılır, tıklanabilir ve görsel bir macOS deneyimine taşımak.

---

## Faz 5 — Dinamik UI/UX, Katlanabilir Terminal Deck ve `#111110` Adaptif Tema Sistemi
**Zaman:** Cuma, 20 Kasım 2026 — `15:20` (TRT / UTC+3)  
**Git Commit:** `cca4b1a`  
**Etkilenen Modüller:** `macos/SierraPortApp/Sources/SierraPortApp/{Theme,ContentView,VisualBlocks,ViewModel,Models,SierraPortApp}.swift`, `assets/sierraport-preview.png`

### Ne Yapıldı?
- **Katlanabilir Komut Blokları:** Terminal Deck'teki her komut bloğu tıklanarak tek satıra katlanıp tekrar açılabilir; yeni bir örnek komuta tıklandığında eskiler otomatik katlanır, yeni blok `NEW` rozeti ve camgöbeği vurguyla odaklanır.
- **Boş Durum Karşılama Ekranı (Command Deck Hero):** Komut yokken Apple minimalist marka başlığı, açıklayıcı bilgi metni ve ortalanmış daraltılmış komut giriş kutusu.
- **Düzen ve Grafik Hatalarının Giderilmesi:** Duplicate `ForEach` ID kaynaklı üst üste binme hataları giderildi; `BindingCardView` tıklanarak tam komut satırını açacak ve kopyalayacak şekilde yeniden tasarlandı; Swift Charts'ta ayrı `series:` tanımları ile `Live Socket Activity` sparkline ve `SectorMark` donut grafikleri düzeltildi.
- **`#111110` Adaptif Tema Sistemi (`Theme.swift`):** Dark (`#111110`), Light (`#F6F6F4`) ve System temaları arasında anlık geçiş + `NSWindow` çerçeve senkronizasyonu.
- GitHub README için alt kısmı yumuşak Gaussian blur ve kosinüs şeffaf degrade ile kaybolan `assets/sierraport-preview.png` oluşturuldu.

---

## Faz 6 — Yeni Nesil Güvenlik & Binary Güven Denetim Motoru
**Zaman:** Cuma, 20 Kasım 2026 — `15:33` (TRT / UTC+3)  
**Git Commit:** `8143ede`  
**Etkilenen Modüller:** `src/audit.rs`, `src/cli.rs`, `src/commands.rs`, `src/display.rs`, `macos/SierraPortApp/Sources/SierraPortApp/{Models,ViewModel,VisualBlocks,ContentView}.swift`

### Ne Yapıldı?
1. **macOS İkili Dosya İmza & Köken Doğrulaması (`codesign` + Yol Analizi):**
   - Dinleyen her benzersiz çalıştırılabilir dosya `codesign -dv --verbose=2` ile doğrulanarak `APPLE SIGNED`, `DEVELOPER ID`, `AD-HOC` veya `UNSIGNED` şeklinde sınıflandırıldı.
   - `/tmp`, `/private/tmp`, `/var/tmp`, `~/Downloads`, `~/Desktop` gibi geçici/şüpheli dizinlerden çalışan dinleyicilere **`CRITICAL — TRUST-SUSP-PATH`** alarmı eklendi.
2. **Sistem Savunma Duruşu (`Host Defense Posture`):**
   - macOS Application Firewall (`socketfilterfw --getglobalstate`) ve Stealth Mode (`--getstealthmode`) durumu canlı okunarak skora ve Audit üst şeridine yansıtıldı.
3. **Aktif Güvenlik Probu (`--deep` / Deep Probe):**
   - Dışa açık TCP portlara güvenli aktif prob gönderilerek şifresiz Redis (`+PONG` → **`CRITICAL — AUTH-NONE`**) ve açık HTTP banner/sürüm sızıntıları (`INFO-BANNER`) gerçek zamanlı doğrulandı.
4. **Güvenlik Profilleri & Kalıcı Risk Kabul (Allowlist):**
   - `Developer`, `Strict` ve `Zero-Trust` profilleri eklendi.
   - Kullanıcıların bilinen ve kasıtlı portları **`Accept Risk`** ile kalıcı allowlist'e alıp skoru anlık güncellemesi ve istediğinde geri alması sağlandı.
5. **Müdahale Playbook'u & Markdown Uyumluluk Raporu (`Export MD`):**
   - Her bulguya kopyalanabilir gerçek çözüm komutu (`remediation_cmd`: `socketfilterfw`, `pfctl`, `redis-cli`, `sierraport kill` vb.) eklendi.
   - Tek tıkla zaman damgalı Markdown güvenlik denetim raporu dışa aktarma eklendi.

### Neden Yapıldı? (Rakiplerden Farkı Nedir?)
Standart port monitörleri (`lsof`, `netstat`, Activity Monitor vb.) yalnızca *"hangi port açık?"* sorusunu yanıtlar. Bu güncelleme ile SierraPort şu 4 kritik soruyu aynı anda yanıtlayan **uçtan uca bir yerel saldırı yüzeyi (Attack Surface) denetçisine** dönüştü:
1. *"Bu portu dinleyen uygulama gerçekten kriptografik olarak imzalı ve güvenilir bir dizinden mi çalışıyor?"*
2. *"Bu servis dışarıya gerçekten kimlik doğrulamasız yanıt veriyor mu?"*
3. *"İşletim sisteminin kendi güvenlik duvarı (Firewall & Stealth Mode) beni koruyor mu?"*
4. *"Bu riski tam olarak hangi komutla kapatabilirim ve denetim kanıtını ekibe nasıl raporlarım?"*

---

### Bireysel Kullanıcılar ve Geliştiriciler Bunu Ne İçin Kullanır?

| Durum / Senaryo | SierraPort Security Audit Nasıl Yardımcı Olur? |
|---|---|
| **Kafe / Havalimanı / Ortak Wi-Fi Güvenliği** | `Developer` veya `Zero-Trust` profiliyle bilgisayarda `0.0.0.0` üzerinde unutulmuş bir veritabanı (PostgreSQL, Redis, MongoDB) veya geliştirme sunucusu olup olmadığını ve macOS Firewall'un açık olup olmadığını tek bakışta kontrol eder. |
| **Şüpheli Yazılım / Zararlı Arka Kapı (Backdoor) Kontrolü** | İnternetten indirilen bir araç, npm/pip paketi veya crack'li yazılım arka planda gizli bir port açtıysa, **Binary Code-Signature Trust** tablosunda `UNSIGNED` veya **`TRUST-SUSP-PATH` (`/tmp`, `~/Downloads`)** uyarısıyla anında yakalanır. |
| **Docker / Yerel Geliştirme Hijyeni** | Docker Compose ile yanlışlıkla `0.0.0.0:6379` olarak dışa açılmış şifresiz bir Redis'i **Deep Probe** ile `+PONG` yanıtından yakalar ve hazır `redis-cli CONFIG SET bind 127.0.0.1` çözümünü tek tıkla kopyalatır. |
| **Gürültüsüz Çalışma** | macOS `ControlCenter` veya kasıtlı yerel servisleri `Accept Risk` ile allowlist'e alarak yalnızca gerçek tehditlere odaklanır. |

---

### Kurumlar (DevSecOps, SRE, SOC ve IT Güvenlik Ekipleri) Bunu Ne İçin Kullanır?

| Kurumsal Alan | Somut Kullanım Senaryosu |
|---|---|
| **Geliştirici İş İstasyonu Güvenlik Uyumluluğu (Endpoint Hardening)** | Kurum içi MacBook filolarında (SOC 2, ISO 27001, GDPR uyumluluğu için) çalışanların cihazlarında Firewall'un açık olduğu, imzasız servislerin dışa açık dinlemediği ve veritabanlarının loopback dışına sızmadığı `sierraport audit --profile strict` ile doğrulanır; **`Export MD`** ile denetim kanıtı (audit artifact) saklanır. |
| **CI/CD ve Staging Güvenlik Kapısı (Security Gate)** | Dağıtım sonrası (post-deploy) test ortamlarında `sierraport audit --profile strict --deep --strict` çalıştırılarak şifresiz açık bırakılan bir servis veya yanlış bind konfigürasyonu varsa pipeline otomatik durdurulur (`exit code 1`). |
| **Olay Müdahalesi ve Tehdit Avcılığı (Incident Response / Threat Hunting)** | Şüpheli bir ağ aktivitesinde SOC analisti `Zero-Trust + Deep Probe` çalıştırarak imzasız/ad-hoc çalışan tüm dinleyicileri, çalıştıkları dosya yollarını ve dışarıya verdikleri banner bilgilerini saniyeler içinde toplar ve raporlar. |
| **Tedarik Zinciri Saldırı Tespiti (Supply-Chain Defense)** | Geliştirici makinelerinde bir bağımlılık güncellemesi sonrası `/tmp` veya kullanıcı dizininden sessizce port dinlemeye başlayan zararlı binary'leri **Code-Signature & Origin Trust** katmanıyla ilk anda fark eder. |
| **Hızlı Müdahale Standartlaştırması (Playbook Automation)** | Her bulgunun yanında hazır `pfctl` / `socketfilterfw` / `sierraport kill` müdahale komutlarının bulunması, genç mühendislerin veya IT destek ekiplerinin hatasız ve hızlı aksiyon almasını sağlar. |

---

> **Not:** Bu dosya, bundan sonraki tüm SierraPort geliştirmelerinde yeni fazlar eklendikçe güncel tutulacaktır.
