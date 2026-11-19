# SierraPort

Terminal üzerinde çalışan, **Rust** ile yazılmış, sıfır harici bağımlılıklı, yüksek hızlı ve hafif port izleme ve analiz aracı.

## Neden Rust?
- **Yüksek hız ve düşük bellek tüketimi:** Linux üzerinde doğrudan `/proc/net/*` ve `/proc/<pid>/fd` okuyarak harici süreç başlatmadan milisaniyeler içinde çalışır.
- **Tek derlenmiş binary:** Kurulum veya runtime gerektirmez, LTO + `opt-level=3` ile optimize edilir.
- **Çapraz platform:** Linux (`/proc`), macOS (`lsof`) ve Windows (`netstat` + `tasklist`) desteği.

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

## Temel Komutlar

| Komut | Açıklama |
|---|---|
| `sierraport` / `sierraport list` | Dinleyen (LISTEN) portları listeler |
| `sierraport list --all` | Tüm bağlantı durumlarını (`ESTABLISHED`, `TIME_WAIT` vb.) listeler |
| `sierraport watch [-i 500]` | Canlı port izleme (açılan `+ OPEN` ve kapanan `- CLOSED` portları anlık gösterir) |
| `sierraport check <portlar> [host]` | Çok iş parçacıklı hızlı TCP port erişim testi (örn: `check 80,443,8000-8010`) |
| `sierraport who <port>` | Belirli bir portu kullanan süreçleri (PID, isim, komut satırı) gösterir |
| `sierraport kill <port> [-f] [-y]` | Portu tutan süreci güvenli şekilde sonlandırır |
| `sierraport stats` | Protokol, durum ve süreç bazlı soket istatistikleri |

### Faydalı Filtreler
- `-t, --tcp` / `-u, --udp` — Protokol filtresi
- `-p, --port <SPEC>` — Tekil port, liste veya aralık (`80,443` veya `3000-3010`)
- `--proc <NAME>` — Süreç adına veya komut satırına göre filtrele
- `--json` — Makine tarafından okunabilir JSON çıktısı
- `--no-color` — Renksiz düz çıktı