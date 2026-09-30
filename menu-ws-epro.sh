#!/usr/bin/env bash
# AutoScriptPsiphon - menu kontrol ws-epro
RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'; CYN='\033[1;36m'; WHT='\033[1;37m'; NC='\033[0m'
WS_DIR=/root/ws
WS_BIN=$WS_DIR/ws-epro
WS_CFG=$WS_DIR/config.yml
SV=ws-epro

need_root(){ [ "$(id -u)" = "0" ] || { echo -e "${RED}harus root${NC}"; exit 1; }; }

head_(){ clear; echo -e "${CYN}=================================${NC}"; \
  echo -e "${WHT}        ws-epro  manager${NC}"; \
  echo -e "${CYN}=================================${NC}"; }

stat_line(){
  if systemctl is-active --quiet $SV 2>/dev/null; then echo -e "Service : ${GRN}AKTIF${NC}"
  else echo -e "Service : ${RED}MATI${NC}"; fi

  local port; port=$(grep -oE '^  listen: ":[0-9]+"' "$WS_CFG" 2>/dev/null | grep -oE '[0-9]+')
  echo "Salome  : ${port:-?}"
  echo "Binary  : $([ -x "$WS_BIN" ] && echo -e "${GRN}ADA${NC}" || echo -e "${RED}HILANG${NC}") ($( [ -x "$WS_BIN" ] && echo "$(du -h "$WS_BIN" 2>/dev/null | cut -f1)" ))"
  echo "Config  : $([ -f "$WS_CFG" ] && echo -e "${GRN}ADA${NC}" || echo -e "${RED}HILANG${NC}")"
  local routes; routes=$(grep -oE '^  (ssh|vpn|psi|v2ray): *\{ *addr: *"[^"]*"' "$WS_CFG" 2>/dev/null | sed -E 's/^  //; s/: *\{ *addr: *"/ -> /; s/"$//' | tr '\n' '|')
  echo "Rute    : ${routes:-?}"
}

edit_cfg(){
  local ed=${EDITOR:-nano}
  command -v "$ed" >/dev/null 2>&1 || ed=vi
  "$ed" "$WS_CFG"
  systemctl restart $SV 2>/dev/null && echo "config di-reload" || echo "restart manual: systemctl restart $SV"
}

main(){
  need_root
  while true; do
    head_; stat_line; echo
    echo " 1) Start        2) Stop         3) Restart"
    echo " 4) Status       5) Log live     6) Edit config.yml"
    echo " 7) Cek port     8) Test backend 9) Backup config"
    echo "10) Lihat config 11) Autostart toggle   0) Keluar"
    echo
    read -rp "Pilih: " c
    case "$c" in
      1) systemctl start $SV; sleep 2; systemctl is-active --quiet $SV && echo -e "${GRN}OK${NC}" || echo -e "${RED}gagal${NC}"; read -rp "Enter..." ;;
      2) systemctl stop $SV; echo "dihentikan"; read -rp "Enter..." ;;
      3) systemctl restart $SV; sleep 2; systemctl is-active --quiet $SV && echo -e "${GRN}OK${NC}" || echo -e "${RED}gagal${NC}"; read -rp "Enter..." ;;
      4) systemctl status $SV --no-pager -l | head -25; read -rp "Enter..." ;;
      5) journalctl -u $SV -f -n 50 ;;
      6) edit_cfg; read -rp "Enter..." ;;
      7) if command -v ss >/dev/null 2>&1; then ss -ltnp | grep -E "ws-epro|:($(grep -oE ':[0-9]+' "$WS_CFG" 2>/dev/null | tr -d ':' | sort -u | paste -sd'|'))" || echo "tidak ada listener"; else echo "ss tidak tersedia"; fi; read -rp "Enter..." ;;
      8) local b; for b in $(grep -oE 'addr: *"[^"]*"' "$WS_CFG" 2>/dev/null | grep -oE '[0-9.]+:[0-9]+' | sort -u); do
           h=${b%:*}; p=${b#*:}
           if timeout 2 bash -c "echo > /dev/tcp/$h/$p" 2>/dev/null; then echo -e "  ${GRN}OK${NC}   $b"; else echo -e "  ${RED}MATI${NC} $b"; fi
         done; read -rp "Enter..." ;;
      9) D=/root/ws-config-$(date +%Y%m%d-%H%M%S).yml.bak; cp "$WS_CFG" "$D" && echo "backup -> $D"; read -rp "Enter..." ;;
     10) cat "$WS_CFG"; read -rp "Enter..." ;;
     11) if systemctl is-enabled --quiet $SV 2>/dev/null; then systemctl disable $SV >/dev/null 2>&1; echo "autostart MATI"; else systemctl enable $SV >/dev/null 2>&1; echo "autostart AKTIF"; fi; read -rp "Enter..." ;;
      0|q) exit 0 ;;
      *) echo "salah pilih"; sleep 1 ;;
    esac
  done
}
main
