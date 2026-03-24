#!/bin/bash
# OllamaLinux Model Management CLI
set -euo pipefail

source /usr/local/bin/lib/common.sh 2>/dev/null || true
source /usr/local/bin/lib/gpu.sh 2>/dev/null || true
source /usr/local/bin/lib/ui.sh 2>/dev/null || true

cmd_list() {
    echo "=== Installed Models ==="
    ollama list
    echo ""
    local total
    total=$(du -sh /var/lib/ollama/models 2>/dev/null | awk '{print $1}')
    echo "Total storage: ${total:-unknown}"
}

cmd_pull() {
    echo "Downloading $1..."
    ollama pull "$1"
}

cmd_remove() {
    local model="$1"
    read -rp "Remove model $model? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy] ]]; then
        ollama rm "$model"
        echo "Removed $model."
    fi
}

cmd_info() {
    ollama show "$1"
}

cmd_recommend() {
    source /etc/ollamalinux/gpu.conf 2>/dev/null || true
    local total_ram
    total_ram=$(free -g | awk '/Mem:/{print $2}')
    local gpu_vram=0

    if [ "${GPU_TYPE:-cpu}" = "nvidia" ]; then
        gpu_vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1) || gpu_vram=0
    fi

    echo "=== Model Recommendations ==="
    echo "RAM: ${total_ram}GB | GPU VRAM: ${gpu_vram:-0} MB"
    echo ""

    if [ "${gpu_vram:-0}" -ge 24000 ]; then
        echo "  llama3.1:70b    - Best quality, fits in VRAM"
        echo "  mixtral:8x7b    - Fast MoE, diverse tasks"
        echo "  codellama:34b   - Excellent for code"
    elif [ "${gpu_vram:-0}" -ge 8000 ]; then
        echo "  llama3.1:8b     - Great balance"
        echo "  mistral:7b      - Fast general-purpose"
        echo "  codellama:7b    - Good for code"
    else
        echo "  llama3.2:3b     - Fastest, lowest memory"
        echo "  phi3:mini       - Small but capable"
        echo "  gemma2:2b       - Lightweight"
    fi
}

cmd_tui() {
    while true; do
        local action
        action=$(whiptail --title "OllamaLinux Model Manager" \
            --menu "Choose an action:" 16 60 6 \
            "list"      "List installed models" \
            "pull"      "Download a new model" \
            "remove"    "Remove an installed model" \
            "recommend" "Get model recommendations" \
            "test"      "Test a model" \
            "exit"      "Exit" \
            3>&1 1>&2 2>&3) || break

        case "$action" in
            list) cmd_list; read -rp "Press Enter..." ;;
            pull)
                local m
                m=$(whiptail --inputbox "Model name (e.g., llama3.1:8b):" 8 60 3>&1 1>&2 2>&3) || continue
                cmd_pull "$m"; read -rp "Press Enter..." ;;
            remove)
                local m
                m=$(whiptail --inputbox "Model to remove:" 8 60 3>&1 1>&2 2>&3) || continue
                cmd_remove "$m" ;;
            recommend) cmd_recommend; read -rp "Press Enter..." ;;
            test)
                local m
                m=$(whiptail --inputbox "Model to test:" 8 60 3>&1 1>&2 2>&3) || continue
                ollama run "$m" "Say hello and describe your capabilities in 2 sentences."
                read -rp "Press Enter..." ;;
            exit) break ;;
        esac
    done
}

usage() {
    cat <<EOF
OllamaLinux Model Manager

Usage: $(basename "$0") <command> [args]

Commands:
  list              List installed models
  pull <model>      Download a model
  remove <model>    Remove a model
  info <model>      Show model details
  recommend         Recommendations for your hardware
  tui               Interactive TUI mode

Examples:
  $(basename "$0") pull llama3.1:8b
  $(basename "$0") list
  $(basename "$0") recommend
EOF
}

case "${1:-tui}" in
    list)              cmd_list ;;
    pull)              cmd_pull "${2:?Model name required}" ;;
    remove|rm)         cmd_remove "${2:?Model name required}" ;;
    info|show)         cmd_info "${2:?Model name required}" ;;
    recommend)         cmd_recommend ;;
    tui|interactive)   cmd_tui ;;
    -h|--help|help)    usage ;;
    *)                 usage; exit 1 ;;
esac
