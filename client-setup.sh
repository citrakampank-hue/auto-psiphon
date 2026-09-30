#!/usr/bin/env bash
# AutoScriptPsiphon - siapkan CLIENT (ConsoleClient psiphon-tunnel-core)
# Pakai: ./client-setup.sh /path/ke/server-entry.dat
#
# Catatan: client resmi (Play Store / psiphon3) TIDAK menerima entry ini.
# Client ini adalah psiphon-tunnel-core yang dibuild sendiri.
set -e -u

RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'; CYN='\033[1;36m'; NC='\033[0m'
die(){ echo -e "${RED}[X]${NC} $*" >&2; exit 1; }

ENTRY=${1:-}
[ -n "$ENTRY" ] || die "pakai: $0 /path/ke/server-entry.dat"
[ -f "$ENTRY" ] || die "file entry tidak ada: $ENTRY"

SRC=${SRC:-$HOME/psiphon-tunnel-core}
ROOT=${ROOT:-$HOME/.psiphon}

command -v go >/dev/null 2>&1 || die "Go belum ada. Contoh: pkg install golang | apt install golang-go"

echo -e "${CYN}[..]${NC} clone/sinkron source"
if [ -d "$SRC/.git" ]; then
  git -C "$SRC" fetch --depth 1 origin master >/dev/null 2>&1 || true
  git -C "$SRC" reset --hard origin/master >/dev/null 2>&1 || true
else
  git clone --depth 1 https://github.com/Psiphon-Labs/psiphon-tunnel-core.git "$SRC" \
    || die "clone gagal"
fi

echo -e "${CYN}[..]${NC} build ConsoleClient"
cd "$SRC/ConsoleClient" || die "folder ConsoleClient tidak ada"
BIN=$HOME/psiphon-tunnel-core-bin
if ! go build -o "$BIN" . 2>&1 | tail -15; then
  die "build gagal (lihat output di atas)"
fi
[ -x "$BIN" ] || die "binary tidak terbentuk"

mkdir -p "$ROOT"
cp "$ENTRY" "$ROOT/server-entry.dat"

# client.config: field wajib agar lolos Commit() -> DataRootDirectory + PropagationChannelId + SponsorId
cat > "$ROOT/client.config" <<EOC
{
    "DataRootDirectory": "$ROOT",
    "PropagationChannelId": "FFFFFFFFFFFFFFFF",
    "SponsorId": "FFFFFFFFFFFFFFFF",
    "ClientPlatform": "Android",
    "LocalHttpProxyPort": 8080,
    "LocalSocksProxyPort": 1080,
    "DisableRemoteServerListFetcher": true
}
EOC

cat > "$ROOT/run.sh" <<EOR
#!/usr/bin/env bash
# jalankan client: HTTP proxy 127.0.0.1:8080, SOCKS 127.0.0.1:1080
exec $BIN -config $ROOT/client.config -serverList $ROOT/server-entry.dat -dataRootDirectory $ROOT -formatNotices
EOR
chmod 755 "$ROOT/run.sh"

echo
echo -e "${GRN}[OK]${NC} binary : $BIN"
echo -e "${GRN}[OK]${NC} entry  : $ROOT/server-entry.dat"
echo -e "${GRN}[OK]${NC} config : $ROOT/client.config"
echo -e "${GRN}[OK]${NC} jalan  : bash $ROOT/run.sh"
echo
echo -e "${YLW}[!]${NC} Setelah jalan, proxy lokal: HTTP 127.0.0.1:8080 / SOCKS5 127.0.0.1:1080"
echo -e "${YLW}[!]${NC} Kalau gagal connect, cek: server-entry.dat cocok, port 3001/3002 terbuka di server."
