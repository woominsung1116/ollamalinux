#!/bin/bash
# OllamaLinux First-Boot Configuration Wizard
set -uo pipefail
trap 'systemctl start getty@tty1.service 2>/dev/null || true' EXIT

source /usr/local/bin/lib/ui.sh 2>/dev/null || true
source /usr/local/bin/lib/common.sh 2>/dev/null || true
source /usr/local/bin/lib/gpu.sh 2>/dev/null || true

CONF_DIR="/etc/ollamalinux"
FIRSTBOOT_FLAG="/etc/ollamalinux/.firstboot-done"
LOG="/var/log/ollamalinux-firstboot.log"
username="user"  # default, overwritten by create_user

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

welcome_screen() {
    whiptail --title "OllamaLinux Setup" \
        --msgbox "Welcome to OllamaLinux!\n\nThis wizard will help you configure:\n\n  1. Hostname\n  2. User account\n  3. GPU drivers\n  4. AI model selection\n  5. Open WebUI\n  6. Network access\n\nPress OK to continue." \
        18 60
}

configure_hostname() {
    local hostname
    while true; do
        hostname=$(whiptail --title "Hostname" \
            --inputbox "Enter a hostname for this machine:" \
            8 60 "ollamalinux" 3>&1 1>&2 2>&3) || return 0

        # Validate RFC-1123 hostname
        if echo "$hostname" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'; then
            hostnamectl set-hostname "$hostname"
            log "Hostname set to: $hostname"
            return 0
        fi

        whiptail --msgbox "Invalid hostname. Use only letters, digits, and hyphens (1-63 chars)." 8 60
    done
}

create_user() {
    local password
    while true; do
        username=$(whiptail --title "User Account" \
            --inputbox "Create an admin user account.\n\nUsername:" \
            10 60 "ai" 3>&1 1>&2 2>&3) || return 0

        # Simple username validation
        if ! echo "$username" | grep -qE '^[a-z_][a-z0-9_-]*$'; then
             whiptail --msgbox "Invalid username. Use only lowercase letters, digits, underscores, and hyphens." 8 60
             continue
        fi

        password=$(whiptail --title "User Account" \
            --passwordbox "Password for $username:" \
            8 60 3>&1 1>&2 2>&3) || return 0

        if [ ${#password} -lt 8 ]; then
            whiptail --msgbox "Password must be at least 8 characters." 8 60
            continue
        fi

        useradd -m -s /bin/bash -G sudo,ollama "$username" 2>/dev/null || true
        printf '%s:%s\n' "$username" "$password" | chpasswd
        unset password
        log "User created: $username"
        return 0
    done
}

detect_gpu() {
    whiptail --title "GPU Detection" \
        --infobox "Detecting GPU hardware...\n\nThis may take a moment." \
        8 50

    ollamalinux-gpu-detect detect 2>/dev/null || true

    local gpu_type="cpu"
    [ -f "$CONF_DIR/gpu.conf" ] && gpu_type=$(grep '^GPU_TYPE=' "$CONF_DIR/gpu.conf" 2>/dev/null | cut -d= -f2 || echo "cpu")

    local msg
    case "${gpu_type:-cpu}" in
        nvidia) msg="NVIDIA GPU detected.\nCUDA drivers installed successfully." ;;
        rocm)   msg="AMD GPU detected.\nROCm drivers installed successfully." ;;
        intel)  msg="Intel GPU detected.\nOneAPI drivers installed successfully." ;;
        *)      msg="No discrete GPU found.\nOllama will use CPU inference mode." ;;
    esac

    whiptail --title "GPU Detection Result" --msgbox "$msg" 10 60
}

select_models() {
    local choices
    choices=$(whiptail --title "AI Model Selection" \
        --checklist "Select models to download:\n(SPACE to select, ENTER to confirm)" \
        20 70 10 \
        "llama3.2:3b"     "Llama 3.2 3B (2.0 GB) - Fast, lightweight"      ON \
        "llama3.1:8b"     "Llama 3.1 8B (4.7 GB) - Good balance"           OFF \
        "llama3.1:70b"    "Llama 3.1 70B (40 GB) - High quality"           OFF \
        "codellama:13b"   "Code Llama 13B (7.4 GB) - Code generation"      OFF \
        "mistral:7b"      "Mistral 7B (4.1 GB) - Fast general-purpose"     OFF \
        "mixtral:8x7b"    "Mixtral 8x7B (26 GB) - MoE architecture"       OFF \
        "phi3:mini"       "Phi-3 Mini (2.3 GB) - Microsoft small model"    OFF \
        "gemma2:9b"       "Gemma 2 9B (5.5 GB) - Google model"            OFF \
        "qwen2.5:7b"      "Qwen 2.5 7B (4.7 GB) - Multilingual"          OFF \
        "deepseek-r1:8b"  "DeepSeek-R1 8B (4.9 GB) - Reasoning"          OFF \
        3>&1 1>&2 2>&3) || return 0

    for model in $choices; do
        model=$(echo "$model" | tr -d '"')
        whiptail --title "Downloading Model" \
            --infobox "Downloading $model...\nThis may take a while." \
            8 60
        sudo -u ollama ollama pull "$model" >> "$LOG" 2>&1 || true
        log "Model downloaded: $model"
    done
}

configure_webui() {
    if whiptail --title "Open WebUI" \
        --yesno "Enable Open WebUI (web-based chat interface)?\n\nAccessible at http://127.0.0.1:8080 (localhost only)\nFor remote access, configure a reverse proxy." \
        10 60; then
        systemctl enable --now open-webui.service
        log "Open WebUI enabled"
    else
        systemctl disable open-webui.service 2>/dev/null || true
        log "Open WebUI disabled"
    fi
}

configure_access() {
    # Force 127.0.0.1 for security
    sed -i 's/OLLAMA_HOST=.*/OLLAMA_HOST=127.0.0.1:11434/' /etc/default/ollama
    log "Ollama bound to 127.0.0.1:11434 (Local only)"
}

show_summary() {
    local gpu_type="cpu"
    [ -f "$CONF_DIR/gpu.conf" ] && gpu_type=$(grep '^GPU_TYPE=' "$CONF_DIR/gpu.conf" 2>/dev/null | cut -d= -f2 || echo "cpu")

    local ip_addr
    ip_addr=$(hostname -I | awk '{print $1}')

    local models
    models=$(sudo -u ollama ollama list 2>/dev/null | tail -n +2 | awk '{print "  - " $1}') || models="  (none)"

    whiptail --title "Setup Complete!" \
        --msgbox "OllamaLinux is ready!\n\n\
GPU: ${gpu_type:-cpu}\n\
Ollama API: http://127.0.0.1:11434 (Local only)\n\
Open WebUI: http://127.0.0.1:8080 (Local only)\n\n\
Models:\n${models}\n\n\
SSH: ssh $username@${ip_addr:-localhost}\n\n\
Note: For remote access, configure an SSH tunnel or reverse proxy." \
        22 65
}

main() {
    if [ -f "$FIRSTBOOT_FLAG" ]; then
        echo "First-boot already completed. Remove $FIRSTBOOT_FLAG to re-run."
        exit 0
    fi

    mkdir -p "$CONF_DIR"

    welcome_screen
    configure_hostname
    create_user
    detect_gpu

    # Start temporary ollama server for model downloads
    sudo -u ollama /usr/local/bin/ollama serve &>/dev/null &
    local ollama_pid=$!
    sleep 2

    select_models

    # Stop temporary server
    kill "$ollama_pid" 2>/dev/null || true
    wait "$ollama_pid" 2>/dev/null || true

    configure_webui
    configure_access

    touch "$FIRSTBOOT_FLAG"
    log "=== First-boot wizard completed ==="

    # Start services properly via systemd now that firstboot flag exists
    systemctl daemon-reload 2>/dev/null || true
    systemctl start ollama.service 2>/dev/null || true

    show_summary
}

main "$@"
