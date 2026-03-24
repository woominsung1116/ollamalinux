#!/bin/bash
# OllamaLinux Common Library

OLLAMALINUX_VERSION="0.1.0"
OLLAMALINUX_CONF="/etc/ollamalinux"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_file() {
    local logfile="$1"; shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$logfile"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This command requires root privileges."
        echo "Try: sudo $0 $*"
        exit 1
    fi
}

get_ip() {
    hostname -I 2>/dev/null | awk '{print $1}'
}

is_service_running() {
    systemctl is-active "$1" &>/dev/null
}
