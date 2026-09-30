#!/usr/bin/env bash
# AutoScriptPsiphon - bootstrap: ambil semua script ke VPS
set -e -u
REPO=${REPO:-https://github.com/citrakampank-hue/auto-psiphon.git}
DEST=${DEST:-/root/auto-psiphon}

command -v git >/dev/null 2>&1 || { apt-get update -y >/dev/null 2>&1; apt-get install -y git >/dev/null 2>&1; }

if [ -d "$DEST/.git" ]; then
  git -C "$DEST" fetch --depth 1 origin main >/dev/null 2>&1 || true
  git -C "$DEST" reset --hard origin/main >/dev/null 2>&1 || true
else
  rm -rf "$DEST"
  git clone --depth 1 "$REPO" "$DEST"
fi

cd "$DEST"
chmod 755 ./*.sh 2>/dev/null || true

echo
echo "=== file siap di $DEST ==="
ls -1
echo
echo "Jalankan berurutan:"
echo "  1. ./install-ws-epro.sh    # ws-epro  -> port 80  (multiplexer WS)"
echo "  2. ./install.sh            # psiphond -> port 8080, 3001, 3002"
echo
echo "Menu: bash menu-ws-epro.sh  |  bash menu.sh"
