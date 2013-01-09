#!/bin/sh
WDIR="$HOME/bios-update"
DOWNLOAD_DIR="$WDIR/bios-packages"

VENDOR=${vendor:-$(cat /sys/class/dmi/id/sys_vendor || sudo dmidecode -s system-manufacturer)}
OS="$(uname -o)"
#PRODUCT=${2:-$(sudo dmidecode -s system-product-name)}
#VERSION=${2:-$(cat /sys/class/dmi/id/bios_version || sudo dmidecode -s bios-version)}

doexit() {
    echo "$2" >&2
    exit $1
}

msg() {
    [ -n "$quiet" ] || echo "$1" >&2
}

debug() {
    [ -z $debug ] || echo "$1" >&2
}

info() {
    [ -z $info ] || msg "$1"
}

warning() {
    msg "WARNING: $1"
}
