# AutoScriptPsiphon

Versi **Psiphon-only** dari `AutoScriptVPN-AIO`. Basis: `Psiphon-Labs/psiphon-tunnel-core` (GPL-3.0).

## Kenapa tulis ulang, bukan pangkas repo lama
115 dari 131 file `*.sh` di `AutoScriptVPN-AIO` bukan shell script — itu **ELF x86-64 hasil `shc`** (compiled, stripped, 0 string berguna), dan tidak jalan di aarch64. Sumbernya tidak bisa dibaca atau diedit, jadi "buang fitur lain" tidak mungkin.

## Isi paket
| File | Baris | Fungsi |
| --- | --- | --- |
| `install.sh` | 150 | Go (kalau perlu) -> clone -> build `psiphond` -> generate config -> systemd service |
| `menu.sh` | 60 | start/stop/restart, log, server-entry, backup/restore, regenerate, uninstall |
| `client-setup.sh` | 68 | build `ConsoleClient` + bikin `client.config` + `run.sh` yang langsung jalan |

## Hasil di server (`/etc/psiphond/`)
- `psiphond.config` — port: `TunnelProtocolPorts` SSH:3001, OSSH:3002, `WebServerPort`:8080
- `psiphond-traffic-rules.config`, `psiphond-osl.config`, `psiphond-tactics.config`
- `server-entry.dat` — entry koneksi (dipakai client)

Service: `systemctl status psiphond` · Menu: `psiphon`

## Client (mesin sendiri)
```bash
./client-setup.sh /path/server-entry.dat   # ambil dari /etc/psiphond/server-entry.dat
bash ~/.psiphon/run.sh                     # HTTP 127.0.0.1:8080 / SOCKS5 127.0.0.1:1080
```

## ⚠️ Batasan penting
1. **Aplikasi Psiphon resmi (Play Store / psiphon3) TIDAK bisa connect.** Client resmi mengambil entry dari daftar server jaringan Psiphon dan entri itu di-sign (`ServerEntrySignaturePublicKey`). Entry self-host tidak ada di daftar itu.
2. Client yang bisa = `psiphon-tunnel-core` yang kamu build sendiri. Terbukti dari source: `ConsoleClient/main.go` memanggil `ImportEmbeddedServerEntries(ctx, config, listFile, "")` — public key dikirim **kosong**, jadi entry tanpa signature diterima.
3. Psiphon **bukan** protokol akun-per-user. Tidak ada user, kuota, atau expiry. Tidak bisa dijual per akun seperti SSH/VMess.
4. Client butuh Go + jaringan penuh. Di Termux bisa build, tapi mode `tun` tidak tersedia (hanya proxy 8080/1080).
5. Server butuh **Go 1.26.x** (sesuai `go.mod`). Build pertama makan waktu beberapa menit.

## Status verifikasi (jujur)
| Uji | Hasil |
| --- | --- |
| `bash -n` 3 file | ✅ lulus |
| install.sh end-to-end (mock: apt/git/go/curl/ip/systemctl/psiphond) | ✅ 5 config + service + menu terbentuk |
| Jalan gagal `go build` -> `die` terpanggil | ✅ exit 1 (karena `set -o pipefail`) |
| menu.sh baca config (IP + port) | ✅ `SSH:3001 OSSH:3002 web:8080` |
| client-setup.sh (mock) | ✅ client.config + run.sh + entry |
| **Uji nyata di VPS** | ❌ **belum** — butuh VPS amd64 + bandwidth build |

## Instal (VPS Debian/Ubuntu x86_64, root)
```bash
chmod +x install.sh menu.sh client-setup.sh
./install.sh
```

## Kalau tujuanmu jualan akun
Paket ini bukan jalurnya. Yang cocok: **SSH-only** (dropbear/SSH + WS + Stunnel + OHP), user tetap pakai Psiphon resmi sebagai jalur keluar dari filter ISP, lalu SSH ke VPS. Bilang kalau mau versi itu.

---

# Bagian 2 — ws-epro (multiplexer WebSocket)

`ws-epro` = satu port TCP (Salome) yang membagi trafik WS ke beberapa backend berdasarkan path/header. Ini yang dipakai HTTP Custom/payload PSIPHON.

## File
| File | Baris | Fungsi |
| --- | --- | --- |
| `install-ws-epro.sh` | 171 | unduh binary + verifikasi sha256 + tulis `config.yml` + systemd service |
| `menu-ws-epro.sh` | 64 | start/stop/restart, log, edit config, cek port, **test backend**, backup, autostart |
| `config.yml.example` | 76 | config lengkap berkomentar (dari `CONFIGURATION.md` resmi) |
| `CONFIGURATION.md` | — | dokumentasi asli dari paket ws-epro |

## Fakta yang terverifikasi
| Item | Nilai |
| --- | --- |
| Versi binary resmi | `ws-epro v5.3.21-patch1 linux amd64` |
| sha256 resmi | `c1e827e2c81d2371a70bf587b97b3a9fc8427747f21706f670c233532468b2d4` |
| Flag CLI | `-f <config.yml>` (dari `ExecStart` unit resmi) |
| Direktori | `/root/ws/` |
| Port Salome | `:80` |

⚠️ **Binary di `/storage/emulated/0/Download/ws-epro` (d92a7268...) BEDA dengan yang di repo resmi (c1e827e2...).** Installer menolak kalau hash tidak cocok — pakai `WS_SKIP_HASH=1` kalau memang mau versi lain.

## Routing (default installer = opsi B, routing lewat path)
| Tunnel | Path | Backend | Integrasi |
| --- | --- | --- | --- |
| ssh | `/ssh` | 127.0.0.1:22 | sshd |
| vpn | `/vpn` | 127.0.0.1:1194 | OpenVPN |
| **psi** | **`/psi`** | 127.0.0.1:8080 | **→ `WebServerPort` psiphond** (nyambung ke Bagian 1) |
| v2ray | `/vmess` | 127.0.0.1:10001 | Xray/V2Ray WS inbound |
| default | — | 127.0.0.1:10001 | fallback kalau tak ada path yang cocok |

`selector_header: ""` → **routing murni lewat path**. Ini yang dicocokkan dengan payload lamamu:

```
GET / HTTP/1.1[crlf]Host: www.ruangguru.com[crlf][crlf]BMOVE /psi [protocol]...
                                                          ^^^^ path /psi -> rute psi
```

Payload tidak perlu diubah. Kalau nanti mau pakai header pemilih (`X-WS-Epro: ssh`), ubah `selector_header` di `config.yml` lalu restart.

## Verifikasi
| Uji | Hasil |
| --- | --- |
| `bash -n` 2 file | ✅ |
| install, sha256 cocok | ✅ binary + config.yml + service |
| install, sha256 beda | ✅ dibatalkan, exit 1 |
| `WS_SKIP_HASH=1` | ✅ lolos |
| config.yml hasil generate | ✅ `selector_header: ""` + `psi: /psi` terkonfirmasi |
| menu: header + status + rute | ✅ |
| menu: opsi 8 test backend | ✅ 4/4 terdeteksi MATI (backend fiktif) |
| **Uji di VPS nyata** | ❌ **belum** |

## Pakai
```bash
./install-ws-epro.sh                    # unduh dari repo resmi
./install-ws-epro.sh /path/ws-epro      # pakai binary lokal
SALOME_PORT=81 ./install-ws-epro.sh     # ganti port
WS_SKIP_HASH=1 ./install-ws-epro.sh /path/ws-epro   # binary versi lain
```
