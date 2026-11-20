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

> **Not:** Bundan sonraki tüm geliştirmeler aynı formatta (**Gün, Tarih — Saat (TRT) · Commit Kodu** + değişiklik detayları ve kullanım analizi) bu dosyaya kaydedilecektir.
