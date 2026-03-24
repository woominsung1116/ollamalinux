#!/bin/bash
# OllamaLinux System Monitoring Dashboard
set -euo pipefail

show_dashboard() {
    clear
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local sep
    sep=$(printf '=%.0s' $(seq 1 "$cols"))

    echo "$sep"
    echo "  OllamaLinux Monitor  |  $(date '+%Y-%m-%d %H:%M:%S')  |  $(hostname)"
    echo "$sep"
    echo ""

    echo "--- CPU & Memory ---"
    printf "CPU:  %s cores @ %s MHz\n" "$(nproc)" "$(grep 'cpu MHz' /proc/cpuinfo | head -1 | awk '{printf "%.0f", $4}')"
    printf "Load: %s\n" "$(cat /proc/loadavg | awk '{print $1, $2, $3}')"
    free -h | awk '/Mem:/{printf "RAM:  %s used / %s total (%s available)\n", $3, $2, $7}'
    echo ""

    echo "--- GPU ---"
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu \
            --format=csv,noheader 2>/dev/null | while IFS=',' read -r name util memused memtotal temp; do
            printf "%-30s | Util: %s | VRAM: %s/%s | Temp: %s\n" \
                "$name" "$util" "$memused" "$memtotal" "$temp"
        done
    else
        echo "No NVIDIA GPU detected"
    fi
    echo ""

    echo "--- Ollama ---"
    if systemctl is-active ollama.service &>/dev/null; then
        echo "Status: RUNNING"
        local models
        models=$(ollama ps 2>/dev/null | tail -n +2)
        if [ -n "$models" ]; then
            echo "Loaded:"
            echo "$models" | while read -r line; do echo "  $line"; done
        else
            echo "No models loaded"
        fi
    else
        echo "Status: STOPPED"
    fi
    echo ""

    echo "--- Open WebUI ---"
    if systemctl is-active open-webui.service &>/dev/null; then
        echo "Status: RUNNING at http://$(hostname -I | awk '{print $1}'):8080"
    else
        echo "Status: STOPPED"
    fi
    echo ""

    echo "--- Storage ---"
    du -sh /var/lib/ollama/models 2>/dev/null || echo "Models: N/A"
    df -h /var/lib/ollama 2>/dev/null | tail -1 | awk '{printf "Disk:   %s used / %s (%s)\n", $3, $2, $5}'
}

case "${1:-live}" in
    once)   show_dashboard ;;
    live|*) watch -n 2 -t "$(readlink -f "$0")" once ;;
esac
