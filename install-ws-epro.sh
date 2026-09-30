#!/usr/bin/env bash
# AutoScriptPsiphon - installer ws-epro (WS multiplexer: ssh/vpn/psi/v2ray)
# Jalankan di VPS Linux amd64, root.
set -o pipefail

RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'; CYN='\033[1;36m'; NC='\033[0m'
ok(){ echo -e "${GRN}[OK]${NC} $*"; }
info(){ echo -e "${CYN}[..]${NC} $*"; }
warn(){ echo -e "${YLW}[!]${NC} $*"; }
die(){ echo -e "${RED}[X]${NC} $*"; exit 1; }

[ "$(id -u)" = "0" ] || die "harus root"

WS_DIR=/root/ws
WS_BIN=$WS_DIR/ws-epro
WS_CFG=$WS_DIR/config.yml
SERVICE=/etc/systemd/system/ws-epro.service
SALOME_PORT=${SALOME_PORT:-80}
PSI_BACKEND=${PSI_BACKEND:-127.0.0.1:8080}
SSH_BACKEND=${SSH_BACKEND:-127.0.0.1:22}
VPN_BACKEND=${VPN_BACKEND:-127.0.0.1:1194}
V2RAY_BACKEND=${V2RAY_BACKEND:-127.0.0.1:10001}

# sha256 resmi v5.3.21-patch1 (repo citrakampank-hue/ws-epro-binary).
# Set WS_SKIP_HASH=1 kalau memakai binary versi lain.
EXPECT_SHA256=${EXPECT_SHA256:-c1e827e2c81d2371a70bf587b97b3a9fc8427747f21706f670c233532468b2d4}
DL_URL=${DL_URL:-https://raw.githubusercontent.com/citrakampank-hue/ws-epro-binary/main/bin/ws-epro-linux-amd64}

LOCAL_SRC=${1:-}

case "$(uname -m)" in
  x86_64|amd64) : ;;
  *) die "arch $(uname -m) tidak didukung (binary amd64 saja)" ;;
esac

mkdir -p "$WS_DIR"

# --- ambil binary ---
if [ -n "$LOCAL_SRC" ]; then
  [ -f "$LOCAL_SRC" ] || die "file tidak ada: $LOCAL_SRC"
  info "pakai binary lokal: $LOCAL_SRC"
  cp "$LOCAL_SRC" "$WS_BIN"
else
  info "unduh binary dari repo"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$WS_BIN" "$DL_URL" || die "unduh gagal"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$WS_BIN" "$DL_URL" || die "unduh gagal"
  else
    die "butuh curl atau wget"
  fi
fi
chmod 755 "$WS_BIN"

# --- verifikasi hash ---
GOT=$(sha256sum "$WS_BIN" | cut -d' ' -f1)
if [ "${WS_SKIP_HASH:-0}" = "1" ]; then
  warn "verifikasi sha256 dilewati (WS_SKIP_HASH=1). sha256=$GOT"
elif [ "$GOT" = "$EXPECT_SHA256" ]; then
  ok "sha256 cocok: ${GOT:0:16}..."
else
  warn "sha256 TIDAK cocok!"
  echo "   harap : $EXPECT_SHA256"
  echo "   dapat : $GOT"
  die "batalkan. Pakai WS_SKIP_HASH=1 kalau memang binary versi lain yang kamu mau."
fi

# --- cek konflik port salome ---
if command -v ss >/dev/null 2>&1; then
  busy=$(ss -ltnpH "sport = :$SALOME_PORT" 2>/dev/null | head -3)
  if [ -n "$busy" ]; then
    warn "port $SALOME_PORT sudah dipakai:"
    echo "$busy" | sed 's/^/   /'
    warn "hentikan layanan itu dulu, atau jalankan dengan SALOME_PORT=81"
  fi
else
  warn "ss tidak ada — lewati cek port"
fi

# --- tulis config.yml ---
info "tulis $WS_CFG"
cat > "$WS_CFG" <<EOC
# ws-epro config - dibuat install-ws-epro.sh
# verbose: 0=normal 1=debug 2=isi trafik

verbose: 0

network: { handshake_timeout: "10s", dial_timeout: "5s", max_connections: 1024 }

# port alias tambahan (opsional)
listen:
  - { target_host: 127.0.0.1, target_port: 22, listen_port: 222 }

salome:
  enable: true
  listen: ":$SALOME_PORT"

  websocket:
    # true = payload wajib Connection: Upgrade + Sec-WebSocket-Key + Sec-WebSocket-Version: 13
    strict_handshake: false
    # "" = routing lewat path saja (cocok dengan payload lama: GET /psi, /ssh, dst)
    selector_header: ""

  legacy_loopback: { enable: false, listen: "127.0.0.1:1707" }

  ssh:   { addr: "$SSH_BACKEND",    path: "/ssh" }
  vpn:   { addr: "$VPN_BACKEND",    path: "/vpn" }
  psi:   { addr: "$PSI_BACKEND",    path: "/psi" }
  v2ray: { addr: "$V2RAY_BACKEND",  path: "/vmess" }

  default: "$V2RAY_BACKEND"
EOC

# --- validasi config sederhana (tanpa pyyaml) ---
if grep -qE '^salome:' "$WS_CFG" && grep -qE '^  listen: ":'"$SALOME_PORT"'"' "$WS_CFG"; then
  ok "config.yml valid (struktur dasar)"
else
  die "config.yml tidak sesuai harapan"
fi

# --- systemd unit ---
info "pasang systemd service"
cat > "$SERVICE" <<EOSVC
[Unit]
Description=ws-epro (WS multiplexer)
After=network-online.target
Wants=network-online.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$WS_BIN -f $WS_CFG
Type=simple
WorkingDirectory=$WS_DIR
Restart=on-failure
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOSVC

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload
  systemctl enable ws-epro >/dev/null 2>&1
  systemctl restart ws-epro
  sleep 2
  if systemctl is-active --quiet ws-epro; then
    ok "ws-epro jalan di port $SALOME_PORT"
  else
    warn "service belum aktif — cek: journalctl -u ws-epro -n 40"
  fi
else
  warn "systemd tidak ada — jalankan manual: $WS_BIN -f $WS_CFG"
fi

# --- firewall ---
if command -v ufw >/dev/null 2>&1; then
  ufw allow "$SALOME_PORT"/tcp >/dev/null 2>&1
  ufw allow 222/tcp >/dev/null 2>&1
fi

echo
echo -e "${GRN}=== SELESAI ===${NC}"
echo "Binary  : $WS_BIN"
echo "Config  : $WS_CFG"
echo "Salome  : port $SALOME_PORT  (multiplexer WS)"
echo "Rute    : /ssh -> $SSH_BACKEND | /vpn -> $VPN_BACKEND | /psi -> $PSI_BACKEND | /vmess -> $V2RAY_BACKEND"
echo "Selector: OFF (routing lewat path)"
echo "Menu    : bash menu-ws-epro.sh"
