#!/bin/sh
# Training-Router station builder - Wavlink WL-WNT100X3 (MT7981, vendor OpenWrt 21.02)
# Usage:  sh station.sh <1-4>
#
# Sets wifi (both bands, both switch positions), DHCP .230-.249, and installs a
# watcher that moves the LAN when the side switch changes:
#   DOT (released, gpio hi)   -> 172.24.172.1
#   no dot (pressed, gpio lo) -> 10.10.N.1
# Reboots at the end. Safe to re-run (e.g. after someone saves the web wifi page).

N="$1"
case "$N" in 1|2|3|4) ;; *) echo "Usage: sh $0 <station 1-4>"; exit 1;; esac

SSID="Legrand_Station_$N"
PSK="Legrand_Station_$N"
TXPOWER=25
DOT_IP=172.24.172.1
ALT_IP="10.10.$N.1"
case "$N" in
  1) C2=1;  C5=36;;
  2) C2=6;  C5=40;;
  3) C2=11; C5=44;;
  4) C2=1;  C5=48;;
esac

printf 'STATION=%s\nDOT_IP=%s\nALT_IP=%s\n' "$N" "$DOT_IP" "$ALT_IP" > /etc/training-station

# ---------- wifi (MediaTek .dat files) ----------
# The driver loads mt7981.dbdc.b0.dat (2.4 GHz) and mt7981.dbdc.b1.dat (5 GHz).
# The web UI also keeps DBDC_card0.dat (both bands, 8 BSS: 1-4 = 2.4, 5-8 = 5 GHz).
# All three are edited so they agree. Many values are ;-separated per-BSS lists.
D=/etc/wireless/mediatek
C0=$D/DBDC_card0.dat; B0=$D/mt7981.dbdc.b0.dat; B1=$D/mt7981.dbdc.b1.dat
for f in "$C0" "$B0" "$B1"; do
  [ -f "$f" ] || { echo "Missing $f - stopping"; exit 1; }
  [ -f "$f.orig" ] || cp "$f" "$f.orig"
done

# setidx file key index value : set one element of a ;-list (index from 1)
# setall file key value       : set every element of a ;-list
# Both leave the file alone if the key is not there.
dat() {
  awk -v m="$1" -v k="$3" -v i="$4" -v v="$5" '
    index($0, k "=") == 1 {
      n = split(substr($0, length(k) + 2), a, ";")
      if (n == 0) { n = 1; a[1] = "" }
      if (m == "idx") a[i] = v
      else for (j = 1; j <= n; j++) if (a[j] != "" || n == 1) a[j] = v
      s = a[1]; for (j = 2; j <= n; j++) s = s ";" a[j]
      $0 = k "=" s
    }
    { print }' "$2" > "$2.tmp" && mv "$2.tmp" "$2"
}
setidx() { dat idx "$1" "$2" "$3" "$4"; }
setall() { dat all "$1" "$2" "" "$3"; }

# Combined file: BSS 1 = 2.4 GHz main, BSS 5 = 5 GHz main
setidx "$C0" SSID1 1 "$SSID";  setidx "$C0" SSID5 1 "$SSID"
setidx "$C0" WPAPSK1 1 "$PSK"; setidx "$C0" WPAPSK5 1 "$PSK"
for i in 1 5; do
  setidx "$C0" AuthMode $i WPA2PSK
  setidx "$C0" EncrypType $i AES
done
setidx "$C0" Channel 1 "$C2"; setidx "$C0" Channel 2 "$C5"

# Per-band files: BSS 1 is the main network
for f in "$B0" "$B1"; do
  setidx "$f" SSID1 1 "$SSID"
  setidx "$f" WPAPSK1 1 "$PSK"
  setidx "$f" AuthMode 1 WPA2PSK
  setidx "$f" EncrypType 1 AES
done
# Only the main network per band (factory has Guest, Parental and MeshLink on too)
setall "$B0" BssidNum 1
setall "$B1" BssidNum 1
setall "$B0" Channel "$C2"
setall "$B1" Channel "$C5"

# 20 MHz, fixed channel, low power - all three files
for f in "$C0" "$B0" "$B1"; do
  setall "$f" HT_BW 0
  setall "$f" VHT_BW 0
  setall "$f" HT_BSSCoexistence 0
  setall "$f" AutoChannelSelect 0
  setall "$f" PERCENTAGEenable 1
  setall "$f" TxPower "$TXPOWER"
done

for k in $(uci -q show ws_wireless | grep '\.auto_channel=' | cut -d= -f1); do uci set "$k=0"; done
uci -q commit ws_wireless

# ---------- DHCP and vendor switch handler ----------
uci set dhcp.lan.start=230
uci set dhcp.lan.limit=20
uci commit dhcp
uci -q set ws_mode_button.mode_button.enable=0 && uci commit ws_mode_button

# ---------- station-lan: move the LAN everywhere Wavlink keeps it ----------
cat > /usr/bin/station-lan <<'EOF'
#!/bin/sh
# station-lan <ip> : change LAN to <ip>/24 in network, network_r, dhcp, firewall, ws_sys
NEW="$1"; [ -n "$NEW" ] || exit 1
OLD=$(uci -q get network.lan.ipaddr)
[ "$OLD" = "$NEW" ] && exit 0
RE=$(echo "$OLD" | sed 's/\./\\./g')
for c in network network_r dhcp firewall ws_sys; do
  [ -f /etc/config/$c ] || continue
  for k in $(uci -q show $c | grep "='$RE'\$" | cut -d= -f1); do uci set "$k=$NEW"; done
  uci commit $c
done
uci set network.lan.netmask=255.255.255.0
uci commit network
logger -t station "LAN $OLD -> $NEW"
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart
EOF

# ---------- station-switch: poll the side switch ----------
cat > /usr/bin/station-switch <<'EOF'
#!/bin/sh
. /etc/training-station
grep -q debugfs /proc/mounts || mount -t debugfs none /sys/kernel/debug
state() {
  for w in $(grep -m1 switch_button /sys/kernel/debug/gpio); do
    case "$w" in hi) echo dot; return;; lo) echo nodot; return;; esac
  done
  echo unknown
}
last=""
while true; do
  s=$(state)
  if [ "$s" != unknown ] && [ "$s" != "$last" ]; then
    sleep 1
    if [ "$(state)" = "$s" ]; then
      [ "$s" = dot ] && ip=$DOT_IP || ip=$ALT_IP
      /usr/bin/station-lan "$ip"
      last=$s
    fi
  fi
  sleep 2
done
EOF

cat > /etc/init.d/station-switch <<'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
  procd_open_instance
  procd_set_param command /usr/bin/station-switch
  procd_set_param respawn
  procd_close_instance
}
EOF

chmod +x /usr/bin/station-lan /usr/bin/station-switch /etc/init.d/station-switch
/etc/init.d/station-switch enable

echo "Station $N configured. Rebooting..."
sleep 2
reboot
