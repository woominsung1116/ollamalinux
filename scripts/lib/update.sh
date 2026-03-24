#!/bin/bash
# OllamaLinux Update Helper Library

# Get the latest Ollama version from GitHub API (HTTPS only)
get_latest_ollama_version() {
    local api_url="https://api.github.com/repos/ollama/ollama/releases/latest"
    local version

    version=$(curl -fsSL --max-time 10 "$api_url" 2>/dev/null \
        | grep '"tag_name"' \
        | head -1 \
        | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

    if [ -z "$version" ]; then
        return 1
    fi

    echo "$version"
}

# Get the currently installed Ollama version
get_current_ollama_version() {
    if ! command -v ollama &>/dev/null; then
        echo ""
        return 1
    fi

    local version
    version=$(ollama --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)

    if [ -z "$version" ]; then
        echo ""
        return 1
    fi

    echo "$version"
}

# Compare two version strings (semver: MAJOR.MINOR.PATCH)
# Returns: 0 if equal, 1 if v1 > v2, 2 if v1 < v2
compare_versions() {
    local v1="$1"
    local v2="$2"

    # Strip leading 'v' if present
    v1="${v1#v}"
    v2="${v2#v}"

    if [ "$v1" = "$v2" ]; then
        return 0
    fi

    local IFS='.'
    local i
    read -ra a1 <<< "$v1"
    read -ra a2 <<< "$v2"

    local max_len="${#a1[@]}"
    [ "${#a2[@]}" -gt "$max_len" ] && max_len="${#a2[@]}"

    for (( i=0; i<max_len; i++ )); do
        local n1="${a1[$i]:-0}"
        local n2="${a2[$i]:-0}"

        if (( n1 > n2 )); then
            return 1
        elif (( n1 < n2 )); then
            return 2
        fi
    done

    return 0
}
