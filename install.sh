#!/usr/bin/env bash
# AutoScriptPsiphon - installer psiphond (self-host Psiphon server)
# Target: VPS Debian/Ubuntu x86_64 (root)
# Basis: github.com/Psiphon-Labs/psiphon-tunnel-core (GPL-3.0)
set -o pipefail   # WAJIB: tanpa ini `cmd | tail || die` tak pernah men-trigger die

RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'; CYN='\033[1;36m'; NC='\033[0m'
ok(){ echo -e "${GRN}[OK]${NC} $*"; }
info(){ echo -e "${CYN}[..]${NC} $*"; }
warn(){ echo -e "${YLW}[!]${NC} $*"; }
die(){ echo -e "${RED}[X]${NC} $*"; exit 1; }

[ "$(id -u)" = "0" ] || die "harus root"

ETC=/etc/psiphond
LOGDIR=/var/log/psiphond
SRC=/usr/local/src/psiphon-tunnel-core
BIN=/usr/local/bin/psiphond
SHARE=/usr/local/share/AutoScriptPsiphon
WEB_PORT=8080
PROTO_PORTS="--protocol SSH:3001 --protocol OSSH:3002"

info "pasang dependency dasar"
if command -v apt >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt update -y >/dev/null 2>&1
  apt install -y git curl tar ca-certificates openssl psmisc iproute2 jq >/dev/null 2>&1 || die "apt install gagal"
else
  die "hanya dukung apt (Debian/Ubuntu)"
fi

# --- Go toolchain ---
need_go=1
if command -v go >/dev/null 2>&1; then
  gv=$(go env GOVERSION 2>/dev/null | sed 's/go//')
  major=${gv%%.*}; rest=${gv#*.}; minor=${rest%%.*}
  if [ "${major:-0}" -ge 1 ] && [ "${minor:-0}" -ge 21 ]; then need_go=0; fi
fi

if [ "$need_go" = "1" ]; then
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64|amd64) GOARCH=amd64 ;;
    aarch64|arm64) GOARCH=arm64 ;;
    *) die "arch $ARCH tidak didukung" ;;
  esac
  info "ambil versi Go terbaru dari go.dev"
  GOVER=$(curl -fsSL "https://go.dev/dl/?mode=json" | tr -d ' \n' | grep -oE '"version":"go[0-9.]+"' | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
  [ -n "$GOVER" ] || GOVER="1.26.8"
  info "unduh Go $GOVER ($GOARCH)"
  curl -fsSL -o /root/go.tgz "https://go.dev/dl/go${GOVER}.linux-${GOARCH}.tar.gz" || die "unduh Go gagal"
  rm -rf /usr/local/go
  tar -C /usr/local -xzf /root/go.tgz || die "ekstrak Go gagal"
  rm -f /root/go.tgz
  export PATH=/usr/local/go/bin:$PATH
  grep -q '/usr/local/go/bin' /etc/profile 2>/dev/null || echo 'export PATH=/usr/local/go/bin:$PATH' >> /etc/profile
fi
ok "Go: $(go version 2>/dev/null | awk '{print $3}')"

info "clone psiphon-tunnel-core"
if [ -d "$SRC/.git" ]; then
  git -C "$SRC" fetch --depth 1 origin master >/dev/null 2>&1 && git -C "$SRC" reset --hard origin/master >/dev/null 2>&1
else
  rm -rf "$SRC"; mkdir -p "$(dirname "$SRC")"
  git clone --depth 1 https://github.com/Psiphon-Labs/psiphon-tunnel-core.git "$SRC" >/dev/null 2>&1 || die "clone gagal"
fi
ok "source siap"

info "build psiphond (beberapa menit)"
cd "$SRC/Server" || die "folder Server tidak ada"
export GOFLAGS=-mod=mod GOCACHE=/root/.cache/go-build GOPATH=/root/go
info "unduh dependency module"
go mod download 2>&1 | tail -3 || die "go mod download gagal"
info "compile"
if ! go build -o "$BIN" . 2>&1 | tail -15; then
  die "build gagal (lihat output di atas)"
fi
[ -x "$BIN" ] || die "binary $BIN tidak terbentuk"
chmod 755 "$BIN"
ok "binary terpasang: $BIN"

info "generate config server"
mkdir -p "$ETC" "$LOGDIR"
PUBIP=$(curl -fsS --max-time 8 https://api.ipify.org 2>/dev/null || true)
IFACE=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
if [ -n "$PUBIP" ]; then GENIP="--ipaddress $PUBIP"
elif [ -n "$IFACE" ]; then GENIP="--interface $IFACE"
else GENIP="--ipaddress 0.0.0.0"; fi

cd "$ETC" || die "cd $ETC gagal"
$BIN $GENIP --web "$WEB_PORT" $PROTO_PORTS --logFilename "$LOGDIR/psiphond.log" generate >/dev/null 2>&1 || die "generate config gagal"
for f in psiphond.config psiphond-traffic-rules.config psiphond-osl.config psiphond-tactics.config server-entry.dat; do
  [ -f "$ETC/$f" ] || die "file $f tidak terbentuk"
done
chmod 600 "$ETC"/*.config "$ETC/server-entry.dat"
ok "config: psiphond.config + server-entry.dat"

info "pasang systemd service"
cat > /etc/systemd/system/psiphond.service <<EOSVC
[Unit]
Description=Psiphon Tunnel Core Server (psiphond)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$ETC
ExecStart=$BIN -config $ETC/psiphond.config run
Restart=always
RestartSec=5
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOSVC
systemctl daemon-reload
systemctl enable psiphond >/dev/null 2>&1
systemctl restart psiphond
sleep 3

if systemctl is-active --quiet psiphond; then ok "psiphond jalan"
else warn "service belum aktif — cek: journalctl -u psiphond -n 40"; fi

if command -v ufw >/dev/null 2>&1; then
  ufw allow 3001/tcp >/dev/null 2>&1; ufw allow 3002/tcp >/dev/null 2>&1
  ufw allow "$WEB_PORT"/tcp >/dev/null 2>&1
fi

cat > /usr/local/bin/psiphon <<'EOW'
#!/usr/bin/env bash
exec bash /usr/local/share/AutoScriptPsiphon/menu.sh "$@"
EOW
chmod 755 /usr/local/bin/psiphon
mkdir -p "$SHARE"
SRCDIR=$(cd "$(dirname "$0")" && pwd)
for f in menu.sh install.sh client-setup.sh; do
  [ -f "$SRCDIR/$f" ] && cp "$SRCDIR/$f" "$SHARE/$f" && chmod 755 "$SHARE/$f"
done
ok "menu terpasang: $SHARE"

echo
echo -e "${GRN}=== SELESAI ===${NC}"
echo "Service : systemctl {status|restart|stop} psiphond"
echo "Menu    : psiphon"
echo "Entry   : $ETC/server-entry.dat"
echo
echo -e "${YLW}PENTING:${NC} aplikasi Psiphon resmi (Play Store/psiphon3) TIDAK bisa pakai entry ini."
echo "Client harus psiphon-tunnel-core (ConsoleClient) — lihat client-setup.sh"
