#!/bin/bash
# OllamaLinux GPU Library

GPU_CONF="/etc/ollamalinux/gpu.conf"

get_gpu_type() {
    if [ -f "$GPU_CONF" ]; then
        source "$GPU_CONF"
        echo "${GPU_TYPE:-unknown}"
    else
        echo "unknown"
    fi
}

get_gpu_vram_mb() {
    local gpu_type
    gpu_type=$(get_gpu_type)

    case "$gpu_type" in
        nvidia)
            nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1
            ;;
        *)
            echo "0"
            ;;
    esac
}

get_total_ram_gb() {
    free -g | awk '/Mem:/{print $2}'
}
