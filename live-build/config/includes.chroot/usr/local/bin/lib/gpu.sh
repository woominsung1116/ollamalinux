#!/bin/bash
# OllamaLinux GPU Library

GPU_CONF="/etc/ollamalinux/gpu.conf"

# Ensure common library is loaded for get_conf_value
if ! command -v get_conf_value &>/dev/null; then
    source /usr/local/bin/lib/common.sh 2>/dev/null || true
fi

get_gpu_type() {
    get_conf_value "$GPU_CONF" "GPU_TYPE" "unknown"
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
