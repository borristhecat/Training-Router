# Training-Router

Builds a Wavlink WL-WNT100X3 as one of up to four Legrand training stations.
Separate from the GL.iNet Commissioning-Router kit.

## Stations

| Station | SSID / password | 2.4 GHz | 5 GHz | DOT LAN | No-dot LAN |
| --- | --- | --- | --- | --- | --- |
| 1 | Legrand_Station_1 | 1 | 36 | 172.24.172.1 | 10.10.1.1 |
| 2 | Legrand_Station_2 | 6 | 40 | 172.24.172.1 | 10.10.2.1 |
| 3 | Legrand_Station_3 | 11 | 44 | 172.24.172.1 | 10.10.3.1 |
| 4 | Legrand_Station_4 | 1 | 48 | 172.24.172.1 | 10.10.4.1 |

Wifi is the same in both switch positions. The side switch only moves the LAN.
DHCP hands out .230-.249 in both. 20 MHz on both bands, TX power 25%.

## Build a station

The router needs internet on its WAN port.

1. Set the admin password in the web UI (same on every unit).
2. SSH in (from Windows PowerShell):
   `ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa root@<ip>`
3. Run, with the station number at the end:
   ```
   wget -qO /tmp/install.sh https://raw.githubusercontent.com/borristhecat/Training-Router/main/install.sh && sh /tmp/install.sh 1
   ```
4. It fetches `station.sh` to `/root/`, builds the station and reboots. Its LAN address then follows the switch.

After a switch change, unplug and replug the laptop (or renew DHCP) to pick up the new range.

To rebuild without internet: `sh /root/station.sh <1-4>`.

## Notes

- Saving the wifi page in the web UI can undo the 20 MHz and TX power settings. Re-run `station.sh`.
- Wifi settings live in three files in `/etc/wireless/mediatek/`: `mt7981.dbdc.b0.dat` (2.4 GHz) and `mt7981.dbdc.b1.dat` (5 GHz), which the driver loads, and `DBDC_card0.dat`, the web UI's combined copy. The script edits all three. Originals are kept as `*.dat.orig`.
- Only Legrand_Station_N is broadcast. The factory extra networks (WAVLINK_Guest, Parental-Wi-Fi, MeshLink) are turned off by setting `BssidNum=1` in the two per-band files.
- What runs on the router: `/usr/bin/station-lan`, `/usr/bin/station-switch`, `/etc/init.d/station-switch`, `/etc/training-station`.
- Log: `logread -e station`.
