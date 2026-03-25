#!/bin/bash
# OllamaLinux Auto-Update Script
set -uo pipefail

source /usr/local/bin/lib/common.sh 2>/dev/null || {
    log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
    log_file() { local f="$1"; shift; echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$f"; }
    require_root() {
        if [ "$(id -u)" -ne 0 ]; then
            echo "Error: This command requires root privileges."
            echo "Try: sudo $0 $*"
            exit 1
        fi
    }
}
source /usr/local/bin/lib/update.sh 2>/dev/null || \
    source "$(dirname "$0")/lib/update.sh" 2>/dev/null || true

LOG="/var/log/ollamalinux-update.log"
OLLAMA_BINARY="/usr/local/bin/ollama"
OLLAMA_TMP="$(mktemp -d /tmp/ollama-update-XXXXXXXXXX)"

# Options
OPT_CHECK_ONLY=false
OPT_OLLAMA_ONLY=false
OPT_WEBUI_ONLY=false
OPT_SYSTEM_ONLY=false

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logmsg() {
    log_file "$LOG" "$*"
}

# ---------------------------------------------------------------------------
# Ollama update
# ---------------------------------------------------------------------------
update_ollama() {
    logmsg "=== Checking Ollama update ==="

    local latest current
    latest=$(get_latest_ollama_version 2>/dev/null) || {
        logmsg "WARN: Could not fetch latest Ollama version from GitHub API"
        return 1
    }

    current=$(get_current_ollama_version 2>/dev/null) || current=""

    logmsg "Ollama current: ${current:-not installed}  latest: $latest"

    local stripped_latest="${latest#v}"

    compare_versions "$stripped_latest" "${current:-0.0.0}"
    local cmp=$?

    if [ "$OPT_CHECK_ONLY" = true ]; then
        if [ $cmp -eq 1 ]; then
            logmsg "UPDATE AVAILABLE: Ollama $current -> $latest"
        else
            logmsg "Ollama is up to date ($current)"
        fi
        return 0
    fi

    if [ $cmp -ne 1 ]; then
        logmsg "Ollama is up to date ($current)"
        return 0
    fi

    logmsg "Updating Ollama $current -> $latest ..."

    # Determine architecture
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *)
            logmsg "ERROR: Unsupported architecture: $arch"
            return 1
            ;;
    esac

    local tgz_name="ollama-linux-${arch}.tgz"
    local download_url="https://github.com/ollama/ollama/releases/download/${latest}/${tgz_name}"

    logmsg "Downloading from $download_url ..."
    mkdir -p "$OLLAMA_TMP"
    local tmp_tgz="$OLLAMA_TMP/${tgz_name}"

    if ! curl -fsSL --max-time 300 -o "$tmp_tgz" "$download_url"; then
        logmsg "ERROR: Failed to download Ollama binary"
        rm -rf "$OLLAMA_TMP"
        return 1
    fi

    # Verify SHA256 checksum (security: prevent tampered binaries)
    local checksum_url="https://github.com/ollama/ollama/releases/download/${latest}/sha256sum.txt"
    local expected_checksum
    expected_checksum=$(curl -fsSL --max-time 30 "$checksum_url" 2>/dev/null \
        | grep "${tgz_name}$" | awk '{print $1}')

    if [ -z "$expected_checksum" ]; then
        logmsg "ERROR: Could not fetch checksum — aborting update for safety"
        rm -rf "$OLLAMA_TMP"
        return 1
    fi

    local actual_checksum
    actual_checksum=$(sha256sum "$tmp_tgz" | awk '{print $1}')
    if [ "$expected_checksum" != "$actual_checksum" ]; then
        logmsg "ERROR: Checksum verification failed!"
        logmsg "  Expected: $expected_checksum"
        logmsg "  Got:      $actual_checksum"
        rm -rf "$OLLAMA_TMP"
        return 1
    fi
    logmsg "Checksum verified: $actual_checksum"

    # Stop ollama service before replacing files
    local ollama_was_running=false
    if systemctl is-active ollama.service &>/dev/null; then
        ollama_was_running=true
        logmsg "Stopping ollama.service ..."
        systemctl stop ollama.service
    fi

    # Extract tgz (same method as initial install)
    tar -xzf "$tmp_tgz" -C /usr
    chmod +x /usr/bin/ollama
    ln -sf /usr/bin/ollama /usr/local/bin/ollama
    rm -rf "$OLLAMA_TMP"

    if [ "$ollama_was_running" = true ]; then
        logmsg "Restarting ollama.service ..."
        systemctl start ollama.service
    fi

    logmsg "Ollama updated successfully to $latest"
}

# ---------------------------------------------------------------------------
# Open WebUI update
# ---------------------------------------------------------------------------
update_webui() {
    logmsg "=== Checking Open WebUI update ==="

    if ! command -v pip3 &>/dev/null && ! python3 -m pip --version &>/dev/null 2>&1; then
        logmsg "WARN: pip3 not available, skipping Open WebUI update"
        return 1
    fi

    if "$OPT_CHECK_ONLY"; then
        local installed latest
        installed=$(pip3 show open-webui 2>/dev/null | grep '^Version:' | awk '{print $2}') || installed="not installed"
        latest=$(pip3 index versions open-webui 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1) || latest="unknown"
        logmsg "Open WebUI current: $installed  latest: ${latest:-unknown}"
        return 0
    fi

    logmsg "Upgrading Open WebUI via pip ..."

    local webui_was_running=false
    if systemctl is-active open-webui.service &>/dev/null; then
        webui_was_running=true
        logmsg "Stopping open-webui.service ..."
        systemctl stop open-webui.service
    fi

    if /opt/open-webui/venv/bin/pip install --upgrade open-webui >> "$LOG" 2>&1; then
        logmsg "Open WebUI upgraded successfully"
    else
        logmsg "ERROR: Open WebUI upgrade failed"
        # Restart service even if upgrade failed
        if [ "$webui_was_running" = true ]; then
            systemctl start open-webui.service || true
        fi
        return 1
    fi

    if [ "$webui_was_running" = true ]; then
        logmsg "Restarting open-webui.service ..."
        systemctl start open-webui.service
    fi
}

# ---------------------------------------------------------------------------
# System update
# ---------------------------------------------------------------------------
update_system() {
    logmsg "=== Running system update ==="

    if "$OPT_CHECK_ONLY"; then
        logmsg "Checking for system package updates ..."
        apt-get update -qq >> "$LOG" 2>&1 || {
            logmsg "WARN: apt-get update failed"
            return 1
        }
        local count
        count=$(apt-get --simulate upgrade 2>/dev/null | grep -c '^Inst ' || echo 0)
        logmsg "System packages available for upgrade: $count"
        return 0
    fi

    logmsg "Running apt-get update ..."
    if ! apt-get update -qq >> "$LOG" 2>&1; then
        logmsg "ERROR: apt-get update failed"
        return 1
    fi

    logmsg "Running apt-get upgrade ..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q >> "$LOG" 2>&1; then
        logmsg "ERROR: apt-get upgrade failed"
        return 1
    fi

    logmsg "System update completed successfully"
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

OllamaLinux Auto-Update Script

Options:
  --check         Check for updates only, do not install
  --ollama-only   Update Ollama only
  --webui-only    Update Open WebUI only
  --system-only   Update system packages only
  -h, --help      Show this help message

Without options, all components are updated.

Log file: $LOG
EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --check)        OPT_CHECK_ONLY=true ;;
            --ollama-only)  OPT_OLLAMA_ONLY=true ;;
            --webui-only)   OPT_WEBUI_ONLY=true ;;
            --system-only)  OPT_SYSTEM_ONLY=true ;;
            -h|--help)      usage; exit 0 ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
        shift
    done

    require_root

    mkdir -p "$(dirname "$LOG")"
    logmsg "=== OllamaLinux update started (check-only: $OPT_CHECK_ONLY) ==="

    local exit_code=0

    # Determine which components to update
    local do_ollama=true do_webui=true do_system=true
    if $OPT_OLLAMA_ONLY || $OPT_WEBUI_ONLY || $OPT_SYSTEM_ONLY; then
        do_ollama=$OPT_OLLAMA_ONLY
        do_webui=$OPT_WEBUI_ONLY
        do_system=$OPT_SYSTEM_ONLY
    fi

    # Each step runs independently; failures do not abort the others
    if $do_ollama; then
        update_ollama || { logmsg "Ollama update step failed (continuing)"; exit_code=1; }
    fi

    if $do_webui; then
        update_webui || { logmsg "Open WebUI update step failed (continuing)"; exit_code=1; }
    fi

    if $do_system; then
        update_system || { logmsg "System update step failed (continuing)"; exit_code=1; }
    fi

    logmsg "=== OllamaLinux update finished (exit_code=$exit_code) ==="
    exit $exit_code
}

main "$@"
