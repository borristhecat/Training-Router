# Training-Router

Builds a Wavlink WL-WNT100X3 as one of up to four Legrand training stations.
Separate from the GL.iNet Commissioning-Router kit.

## Stations

| Station | SSID, wifi password and admin password | 2.4 GHz | 5 GHz | DOT LAN | No-dot LAN |
| --- | --- | --- | --- | --- | --- |
| 1 | Legrand_Station_1 | 1 | 36 | 172.24.172.1 | 10.10.1.1 |
| 2 | Legrand_Station_2 | 6 | 40 | 172.24.172.1 | 10.10.2.1 |
| 3 | Legrand_Station_3 | 11 | 44 | 172.24.172.1 | 10.10.3.1 |
| 4 | Legrand_Station_4 | 1 | 48 | 172.24.172.1 | 10.10.4.1 |

The SSID, wifi password and admin password are all the same on each unit. This works around a Wavlink bug where the web login rejects an admin password that differs from the wifi password. The units are standalone, so this is acceptable.

Wifi is the same in both switch positions. The side switch only moves the LAN address.
DHCP hands out .230 to .249 in both positions. 20 MHz on both bands, TX power 25%.

## Build a station

You need: the Wavlink, a laptop with a network port, two network cables, and a building network port with internet.

### 1. Reset and connect

1. Factory reset the router: hold the reset button for 10 seconds until the light flashes.
2. Set the side switch to the **DOT** position.
3. Connect a cable from the building network to the router's **WAN** port.
4. Connect a cable from the router's **LAN** port to your laptop.

### 2. Set up the router in the web page

1. On the laptop, open a browser and go to `http://192.168.20.1`.
2. Choose "Set up the router" and set the region to **Global** (these units go to different countries).
3. Set the wifi name (SSID) to the station you are building, e.g. `Legrand_Station_1`.
4. Set the wifi password to the same text, `Legrand_Station_1`.
5. Tick the option to use the same password for the device (management) login.
6. Save. The router reboots.

### 3. Turn on SSH

1. Go back to `http://192.168.20.1` and log in with the password, e.g. `Legrand_Station_1`.
2. Open **More** (top right), then **Developer Options** (bottom left), then **SSH**.
3. Turn SSH on and click **Save**.
4. Log out of the web page.

### 4. Run the build

1. On the laptop, open **PowerShell** and paste:
   ```
   ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa root@192.168.20.1
   ```
2. If it asks "Are you sure you want to continue connecting", type `yes` and press Enter.
3. Enter the device password (e.g. `Legrand_Station_1`). Nothing shows while you type; that is normal.
4. Paste this, changing the number at the end to the station you are building (1, 2, 3 or 4):
   ```
   wget -qO /tmp/install.sh https://raw.githubusercontent.com/borristhecat/Training-Router/main/install.sh && sh /tmp/install.sh 1
   ```
5. It prints "Station N configured. Rebooting..." and the PowerShell session closes. That's it.

### 5. Check it

1. Wait about 2 minutes, then unplug and replug the laptop's network cable.
2. Browse to `http://172.24.172.1` and log in with the same password.
3. On a phone, check that only `Legrand_Station_N` is showing (no WAVLINK_Guest, Parental-Wi-Fi or MeshLink).
4. Flip the switch to no-dot, wait 10 seconds, replug the laptop, and check you can reach `http://10.10.N.1`. Flip back to DOT.

### If SSH refuses to connect: "REMOTE HOST IDENTIFICATION HAS CHANGED"

Every router has its own SSH key, so after building one unit, the next one at the same address triggers this warning. Clear the saved key in PowerShell and try again:
```
ssh-keygen -R 192.168.20.1
ssh-keygen -R 172.24.172.1
```

## Rebuilding

- To rebuild without internet, SSH in and run `sh /root/station.sh <1-4>`.
- After a switch change, unplug and replug the laptop (or renew DHCP) to pick up the new address range.

## Notes

- Saving the wifi page in the web UI can undo the 20 MHz and TX power settings. Re-run `station.sh`.
- Wifi settings live in three files in `/etc/wireless/mediatek/`: `mt7981.dbdc.b0.dat` (2.4 GHz) and `mt7981.dbdc.b1.dat` (5 GHz), which the driver loads, and `DBDC_card0.dat`, the web UI's combined copy. The script edits all three. Originals are kept as `*.dat.orig`.
- Only Legrand_Station_N is broadcast. The factory extra networks (WAVLINK_Guest, Parental-Wi-Fi, MeshLink) are turned off by setting `BssidNum=1` in the two per-band files.
- The scripts never change the admin or root password.
- What runs on the router: `/usr/bin/station-lan`, `/usr/bin/station-switch`, `/etc/init.d/station-switch`, `/etc/training-station`.
- Log: `logread -e station`.
