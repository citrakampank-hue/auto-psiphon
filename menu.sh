#!/usr/bin/env bash
# AutoScriptPsiphon - menu manajemen psiphond
RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'; CYN='\033[1;36m'; WHT='\033[1;37m'; NC='\033[0m'
ETC=/etc/psiphond
LOGF=/var/log/psiphond/psiphond.log
SV=psiphond

head_(){ clear; echo -e "${CYN}=================================${NC}"; echo -e "${WHT}     AutoScriptPsiphon${NC}"; echo -e "${CYN}=================================${NC}"; }

stat_line(){
  if systemctl is-active --quiet $SV 2>/dev/null; then
    echo -e "Service : ${GRN}AKTIF${NC}"
  else
    echo -e "Service : ${RED}MATI${NC}"
  fi
  local ip; ip=$(jq -r '.ServerIPAddress // empty' $ETC/psiphond.config 2>/dev/null)
  [ -n "$ip" ] || ip=$(grep -oE '"ServerIPAddress"[^,]*' $ETC/psiphond.config 2>/dev/null | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')
  echo "IP      : ${ip:-?}"
  if [ -f $ETC/server-entry.dat ]; then echo -e "Entry   : ${GRN}ADA${NC} ($ETC/server-entry.dat)"; else echo -e "Entry   : ${RED}HILANG${NC}"; fi
  # field asli: TunnelProtocolPorts (map nama->port); tambah WebServerPort
  local ports tports wport
  tports=$(jq -r '(.TunnelProtocolPorts // {}) | to_entries | map("\(.key):\(.value)") | join(" ")' $ETC/psiphond.config 2>/dev/null)
  wport=$(jq -r '.WebServerPort // empty' $ETC/psiphond.config 2>/dev/null)
  ports="$tports"
  [ -n "$wport" ] && ports="$ports web:$wport"
  [ -n "${ports// /}" ] || ports=$(grep -oE '"[A-Za-z]*Port": ?[0-9]+' $ETC/psiphond.config 2>/dev/null | tr -d '" ' | tr '\n' ' ')
  echo "Port    : ${ports:-?}"
  echo "Uptime  : $(systemctl show -p ActiveEnterTimestamp --value $SV 2>/dev/null)"
}

main(){
  while true; do
    head_; stat_line; echo
    echo " 1) Start psiphond"
    echo " 2) Stop psiphond"
    echo " 3) Restart psiphond"
    echo " 4) Status detail"
    echo " 5) Lihat log (tail -f, Ctrl+C keluar)"
    echo " 6) Tampilkan server-entry.dat"
    echo " 7) Backup config"
    echo " 8) Restore config dari backup"
    echo " 9) Regenerate config (IP/port baru)"
    echo "10) Uninstall"
    echo " 0) Keluar"
    echo
    read -rp "Pilih: " c
    case "$c" in
      1) systemctl start $SV && sleep 2 && systemctl is-active --quiet $SV && echo -e "${GRN}OK jalan${NC}" || echo -e "${RED}gagal${NC}"; read -rp "Enter..." ;;
      2) systemctl stop $SV; echo "dihentikan"; read -rp "Enter..." ;;
      3) systemctl restart $SV; sleep 2; systemctl is-active --quiet $SV && echo -e "${GRN}OK${NC}" || echo -e "${RED}gagal${NC}"; read -rp "Enter..." ;;
      4) systemctl status $SV --no-pager -l | head -30; read -rp "Enter..." ;;
      5) [ -f "$LOGF" ] && tail -f "$LOGF" || { journalctl -u $SV -f; } ;;
      6) if [ -f $ETC/server-entry.dat ]; then echo; head -c 2000 $ETC/server-entry.dat; echo; else echo "tidak ada"; fi; read -rp "Enter..." ;;
      7) D=/root/psiphon-backup-$(date +%Y%m%d-%H%M%S).tar.gz; tar -czf "$D" -C /etc psiphond 2>/dev/null && echo "backup -> $D" || echo "gagal"; read -rp "Enter..." ;;
      8) ls -1t /root/psiphon-backup-*.tar.gz 2>/dev/null | head -5; echo; read -rp "file backup: " f
         [ -n "$f" ] && [ -f "$f" ] && tar -xzf "$f" -C / && systemctl restart $SV && echo "restore OK" || echo "gagal/lewati"; read -rp "Enter..." ;;
      9) bash "$(dirname "$0")/install.sh"; read -rp "Enter..." ;;
     10) read -rp "Yakin uninstall? (y/n): " y
         if [ "$y" = "y" ]; then systemctl disable --now $SV >/dev/null 2>&1; rm -f /etc/systemd/system/psiphond.service; rm -rf /etc/psiphond; systemctl daemon-reload; echo "uninstalled"; fi; read -rp "Enter..." ;;
      0|q) exit 0 ;;
      *) echo "salah pilih"; sleep 1 ;;
    esac
  done
}
main
