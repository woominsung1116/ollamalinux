#!/bin/bash
# OllamaLinux GPU Auto-Detection and Driver Installation
set -euo pipefail

LOG_FILE="/var/log/ollamalinux-gpu.log"
GPU_CONF="/etc/ollamalinux/gpu.conf"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

detect_nvidia() {
    lspci -nn | grep -i 'nvidia' | grep -iE 'vga|3d|display' && return 0
    return 1
}

detect_amd() {
    lspci -nn | grep -i 'amd\|radeon' | grep -iE 'vga|3d|display' && return 0
    return 1
}

detect_intel() {
    lspci -nn | grep -i 'intel' | grep -iE 'vga|3d|display' && return 0
    return 1
}

install_nvidia_drivers() {
    log "Installing NVIDIA drivers and CUDA toolkit..."
    apt-get update -qq
    apt-get install -y nvidia-driver-560 nvidia-utils-560 cuda-toolkit-12-6
    if nvidia-smi &>/dev/null; then
        local gpu_info
        gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader)
        log "NVIDIA driver installed: $gpu_info"
        echo "GPU_TYPE=nvidia" > "$GPU_CONF"
        echo "GPU_DRIVER=560" >> "$GPU_CONF"
        echo "GPU_INFO=\"$gpu_info\"" >> "$GPU_CONF"
        echo "CUDA_VERSION=12.6" >> "$GPU_CONF"
    else
        log "ERROR: NVIDIA driver installation failed"
        return 1
    fi
}

install_amd_drivers() {
    log "Installing AMD ROCm drivers..."
    apt-get update -qq
    apt-get install -y rocm-hip-runtime rocm-smi-lib
    echo "GPU_TYPE=rocm" > "$GPU_CONF"
    echo "GPU_DRIVER=rocm" >> "$GPU_CONF"
    log "AMD ROCm drivers installed."
}

install_intel_drivers() {
    log "Installing Intel compute runtime..."
    apt-get update -qq
    apt-get install -y intel-opencl-icd intel-level-zero-gpu level-zero
    echo "GPU_TYPE=intel" > "$GPU_CONF"
    echo "GPU_DRIVER=oneapi" >> "$GPU_CONF"
    log "Intel drivers installed."
}

main() {
    log "=== OllamaLinux GPU Detection Started ==="
    mkdir -p "$(dirname "$GPU_CONF")"

    local gpu_found=false

    if detect_nvidia; then
        gpu_found=true
        install_nvidia_drivers
    fi

    if detect_amd; then
        gpu_found=true
        install_amd_drivers
    fi

    if detect_intel; then
        gpu_found=true
        install_intel_drivers
    fi

    if [ "$gpu_found" = false ]; then
        log "No discrete GPU detected. CPU inference mode."
        echo "GPU_TYPE=cpu" > "$GPU_CONF"
        echo "GPU_DRIVER=none" >> "$GPU_CONF"
    fi

    log "=== GPU Detection Complete ==="
}

case "${1:-detect}" in
    detect) main ;;
    status) cat "$GPU_CONF" 2>/dev/null || echo "No GPU configuration found." ;;
    *) echo "Usage: $0 {detect|status}" ;;
esac
