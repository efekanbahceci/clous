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

> **Not:** Bundan sonraki tüm geliştirmeler aynı formatta (**Gün, Tarih — Saat (TRT) · Commit Kodu** + değişiklik detayları ve kullanım analizi) bu dosyaya kaydedilecektir.
