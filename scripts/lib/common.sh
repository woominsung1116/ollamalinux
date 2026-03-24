#!/bin/bash
# OllamaLinux Common Library

OLLAMALINUX_VERSION="0.1.0"
OLLAMALINUX_CONF="/etc/ollamalinux"

# Safe configuration value extractor (avoids source)
get_conf_value() {
    local file="$1"
    local key="$2"
    local default="${3:-}"
    
    if [ ! -f "$file" ]; then
        echo "$default"
        return
    fi
    
    # Extract value using grep/sed, handle quotes if present
    local value
    value=$(grep "^${key}=" "$file" | head -1 | cut -d'=' -f2- | sed "s/^['\"]//;s/['\"]$//")
    
    echo "${value:-$default}"
}

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
