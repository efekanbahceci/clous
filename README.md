# SierraPort

Terminal üzerinde çalışan, **Rust** ile yazılmış, **sıfır harici bağımlılıklı**, yüksek hızlı ve gelişmiş port izleme, güvenlik denetimi ve ağ analiz sistemi.

## Neden Rust & Sıfır Bağımlılık?
- **Yüksek hız ve düşük bellek tüketimi:** Linux üzerinde doğrudan `/proc/net/*` ve `/proc/<pid>/*` okuyarak sıfır alt süreçle milisaniyeler içinde çalışır; macOS üzerinde `lsof` + toplu (batched) `ps` zenginleştirmesi ile kullanıcı, bellek (RSS), PPID ve tam komut satırını tek seferde toplar.
- **Tek derlenmiş binary:** Kurulum veya runtime gerektirmez, LTO + `opt-level=3` + `strip` ile optimize edilir.
- **Çapraz platform:** Linux (`/proc`), macOS (`lsof` + `ps`) ve Windows (`netstat` + `tasklist`) desteği.

## Kurulum / Derleme

```bash
cargo build --release
# Derlenen binary:
./target/release/sierraport --help
```

İsteğe bağlı olarak sisteme kurmak için:
```bash
cargo install --path .
```

## Komutlar

| Komut | Açıklama |
|---|---|
| `sierraport` / `sierraport list` | Dinleyen portları bind kapsamı (`LOCAL`, `LAN`, `ALL(*)`, `PUBLIC`) ve runtime etiketleriyle listeler |
| `sierraport watch [-i 500]` | Canlı port izleme (açılan `+ OPEN` / kapanan `- CLOSED` akışı, `--log <dosya>` JSONL kayıt, `--alert-new`) |
| `sierraport inspect <port> [--probe]` | Derin adli inceleme: süreç soyağacı (ancestry), bellek/kullanıcı, aktif peer bağlantıları ve canlı banner/HTTP probu |
| `sierraport audit [--strict]` | Güvenlik ve soket sağlığı denetimi (0–100 skor, `A-F` notu, dışa açık veritabanı / legacy protokol / `CLOSE_WAIT` sızıntı tespiti) |
| `sierraport snapshot save <dosya>` | Mevcut port durumunu JSON baseline snapshot olarak kaydeder |
| `sierraport diff <dosya> [--fail-on-drift]` | Canlı sistem ile kaydedilmiş baseline arasındaki sapmaları (`+ ADDED`, `- REMOVED`, `~ CHANGED`) tespit eder |
| `sierraport check <portlar> [host]` | Çok iş parçacıklı TCP port tarama, `--banner` ile protokol/banner tespiti (HTTP, SSH, Redis, SMTP/FTP, MySQL, TLS), `--open-only` |
| `sierraport free [--range 3000-9999] [-n 3]` | Belirtilen aralıkta boş ve bağlanabilir TCP portları bulur (`--plain` script dostu) |
| `sierraport wait <port> [host]` | Bir portun açılmasını (`--until open`) veya kapanmasını (`--until closed`) bekler (CI/CD ve dev otomasyonu) |
| `sierraport who <port>` | Belirli bir portu kullanan süreçleri hızlıca gösterir |
| `sierraport kill <hedef> [-f] [-y] [--wait]` | Port/aralık, `--pid <PID>` veya `--proc <AD>` ile süreç sonlandırır ve `--wait` ile portun serbest kaldığını doğrular |
| `sierraport stats` | Protokol, soket durumu, bind kapsamı ve en çok soket kullanan süreçler için ASCII çubuk grafikli istatistikler |

## Filtreleme, Sıralama ve Çıktı Biçimleri
- `-l, --listen` / `-a, --all` — Yalnızca dinleyenler veya tüm durumlar
- `-t, --tcp` / `-u, --udp` / `-4, --ipv4` / `-6, --ipv6` — Protokol ve IP ailesi filtreleri
- `--exposed` — Yalnızca dışa açık (`0.0.0.0`, `::`, `*`, public IP) portlar
- `--state <DURUM>` — Belirli soket durumu (örn. `ESTABLISHED`, `CLOSE_WAIT`, `TIME_WAIT`)
- `--user <AD>` — Süreç sahibi kullanıcıya göre filtrele
- `-p, --port <SPEC>` — Tekil port, liste veya aralık (`80,443` veya `3000-3010`)
- `--proc <AD>` — Süreç adına veya tam komut satırına göre filtrele
- `-s, --sort <port|pid|process|state|proto|mem>` ve `-r, --desc` — Sıralama
- `-w, --wide` — Geniş tablo (`USER`, `MEM`, `COMMAND` sütunları)
- `--format <table|json|csv|compact>` (kısayollar: `--json`, `--csv`, `--compact`)
- `--no-color` — Renksiz düz çıktı

## Örnek Kullanımlar

```bash
# Geniş görünümde bellek kullanımına göre sıralı dinleyen portlar
sierraport list --wide --sort mem --desc

# Güvenlik ve soket sağlığı denetimi (CI için katı mod)
sierraport audit --strict

# 5432 portunu süreç soyağacı ve canlı banner probu ile derinlemesine incele
sierraport inspect 5432 --probe

# Yerel portları tara, yalnızca açık olanların banner'larını göster
sierraport check 1-1024 127.0.0.1 --open-only --banner

# Baseline snapshot al ve daha sonra sapma (drift) kontrolü yap
sierraport snapshot save baseline.json
sierraport diff baseline.json --fail-on-drift

# Script içinde boş port bul ve servisin ayağa kalkmasını bekle
PORT=$(sierraport free --range 8000-8999 --plain)
sierraport wait "$PORT" --until open --timeout 15000
```
