#!/bin/sh
#
# install.sh - fetch the training-station builder onto this Wavlink and run it.
#
#   wget -qO /tmp/install.sh <RAW_URL>/install.sh && sh /tmp/install.sh 1
#
# Argument: station number 1-4. Optional second argument: a different base URL.
# The router needs internet on its WAN port. It reboots at the end.
# Safe to re-run (e.g. after someone saves the wifi page in the web UI).

set -u

N="${1:-}"
case "$N" in 1|2|3|4) ;; *) echo "Usage: sh install.sh <station 1-4> [base-url]"; exit 1 ;; esac

BASE="${2:-https://raw.githubusercontent.com/borristhecat/Training-Router/main}"

fetch() {   # $1 = file in repo, $2 = destination
    tmp="$2.new"
    if ! wget -q -O "$tmp" "$BASE/$1"; then
        rm -f "$tmp"; echo "FAILED to fetch $1"; exit 1
    fi
    [ -s "$tmp" ] || { rm -f "$tmp"; echo "FAILED: $1 is empty"; exit 1; }
    sed -i 's/\r$//' "$tmp"
    mv "$tmp" "$2"
    echo "  $2  ($(wc -l < "$2") lines)"
}

echo "Fetching from $BASE"
fetch station.sh /root/station.sh
chmod +x /root/station.sh

echo "Building station $N"
sh /root/station.sh "$N"
