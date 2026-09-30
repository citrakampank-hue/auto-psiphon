# EN: 0 = normal, 1 = debug, 2 = traffic contents. Use 1/2 for troubleshooting; logs may contain sensitive data.
# ID: 0 = normal, 1 = debug, 2 = isi trafik. Gunakan 1/2 saat diagnosis.
verbose: 0

# EN: Handshake timeout, backend connection timeout, and total active connections. Adjust if needed.
# ID: Batas waktu handshake, koneksi backend, dan total koneksi aktif. Ubah jika diperlukan.
network: { handshake_timeout: "10s", dial_timeout: "5s", max_connections: 1024 }

# EN: Extra forwarding (alias) ports. Remove this list if you only need one shared Salome port.
#     target_host/target_port = backend; listen_port = alias port.
# ID: Port tambahan ketika ingin menggunakan alias port. Hapus daftar ini jika hanya perlu satu port Salome.
#     target_host/target_port = backend; listen_port = port alias.
listen:
  - { target_host: 127.0.0.1, target_port: 22, listen_port: 222 }
  - { target_host: 127.0.0.1, target_port: 1194, listen_port: 1111 }

salome:
  # EN: true = enable the shared TCP port (Salome); false = disable Salome.
  # ID: true = aktifkan port TCP bersama (salome); false = nonaktifkan Salome.
  enable: true
  listen: ":80"

  websocket:
    # EN: true = the payload must include Connection: Upgrade, a valid Sec-WebSocket-Key, and Sec-WebSocket-Version: 13.
    #     false = key/version are optional, but Upgrade: websocket is still needed to identify WebSocket requests.
    # ID: true mewajibkan payload berisi `Connection: Upgrade, Sec-WebSocket-Key [ws_key], dan Sec-WebSocket-Version: 13`.
    #     false = isi payload tidak mewajibkan key/version namum `Upgrade: websocket` tetap diperlukan untuk identifikasi metode websocket.
    strict_handshake: false

    # EN: Optional header to select the right tunnel when routing is ambiguous. Values: ssh, vpn, psi, v2ray (WS only).
    #     Example: X-WS-Epro: ssh. "" disables it; omitting the field uses X-WS-Epro as the routing header.
    # ID: Opsi untuk identifikasi koneksi ambigu atau koneksi yang bisa saja salah masuk tunnel. Nilai: ssh, vpn, psi, v2ray (khusus WS).
    #     Contoh: X-WS-Epro: ssh. "" menonaktifkan; menghapus field artinya menggunakan X-WS-Epro sebagai identifikasi.
    selector_header: "X-WS-Epro"

  # EN: Enable only if your setup still needs the older ws-epro loopback route. Omitted = disabled.
  # ID: Aktifkan hanya jika butuh loopback ws-epro versi lama. Aktifkan jika masih tidak dapat mendeteksi tunnel. Dihapus = nonaktif.
  legacy_loopback: { enable: false, listen: "127.0.0.1:1707" }
  # EN: Keep the backends you use; remove unused blocks. addr = destination, path = an additional routing identifier.
  # ID: Tulis backend yang dipakai; hapus blok yang tidak dipakai. addr = tujuan, path = identifikasi tambahan seperti selector_header.
  ssh: { addr: ":22", path: "/ssh" }
  vpn: { addr: "127.0.0.1:1194", path: "/vpn" }
  psi: { addr: "127.0.0.1:8080", path: "/psiphon" }

  # EN: Route V2Ray traffic by connection type. Uncomment only if the backend is available.
  # ID: v2ray berdasarkan bentuk koneksi. Uncomment hanya jika backend tersedia.
  v2ray:
    # EN: Real WebSocket inbound; path must match the client/backend.
    # ID: Inbound WebSocket asli; path sesuai client/backend.
    ws: { addr: "127.0.0.1:10001", path: "/vmess" }

    # EN: TCP/raw destination with payload support, before default. Not needed if default is enough.
    # ID: TCP/raw khusus support payload, sebelum default. Tidak perlu jika default sudah mencukupi.
    # raw: "127.0.0.1:10000"

    # EN: HTTP/1 non-WS backend. An empty path may also send Psiphon POST and opening payload requests to this backend.
    # ID: Backend HTTP/1 non-WS. Path kosong juga bisa salah dianggap Psiphon dan request payload pembuka.
    # http: { addr: "127.0.0.1:10002", path: "/xhttp" }

    # EN: Plaintext HTTP/2 (h2c), such as a compatible gRPC inbound; not direct TLS traffic.
    # ID: HTTP/2 tanpa TLS (h2c), misalnya inbound gRPC yang sesuai; bukan trafik TLS langsung.
    # http2: "127.0.0.1:10003"

    # EN: TLS backend selected by exact SNI name. Empty server_names accepts all matching TLS, including Psiphon.
    # ID: Backend TLS dipilih lewat nama SNI persis. server_names kosong menerima semua TLS yang cocok, termasuk Psiphon.
    # tls: { addr: "127.0.0.1:10004", server_names: ["v.example.com"] }

    # EN: Use only with a SOCKS5 backend; this is not a VMess/VLESS transport.
    # ID: Gunakan hanya jika ada backend SOCKS5; bukan transport VMess/VLESS.
    # socks: "127.0.0.1:1080"

  # EN: Optional fallback TCP backend, not necessarily V2Ray. Omit if unused; other configured routes still apply.
  #     It may stay when legacy_loopback is enabled; default overrides that fallback. raw overrides default.
  # ID: Backend TCP cadangan opsional, tidak harus V2Ray. Hapus jika tidak dipakai; rute lain yang terisi tetap berlaku.
  #     Boleh tetap diisi saat legacy_loopback aktif; default didahulukan atas fallback itu. raw mendahului default.
  default: "127.0.0.1:10000"
