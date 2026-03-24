#!/bin/bash
# OllamaLinux TUI Helper Library (whiptail wrappers)

export NEWT_COLORS='
root=,black
window=white,black
border=white,black
title=white,black
textbox=white,black
button=black,cyan
actbutton=black,cyan
compactbutton=white,black
checkbox=white,black
actcheckbox=black,cyan
listbox=white,black
actlistbox=black,cyan
actsellistbox=black,cyan
'

ui_msgbox() {
    local title="$1" msg="$2"
    local height="${3:-10}" width="${4:-60}"
    whiptail --title "$title" --msgbox "$msg" "$height" "$width"
}

ui_yesno() {
    local title="$1" msg="$2"
    local height="${3:-10}" width="${4:-60}"
    whiptail --title "$title" --yesno "$msg" "$height" "$width"
}

ui_input() {
    local title="$1" msg="$2" default="$3"
    local height="${4:-8}" width="${5:-60}"
    whiptail --title "$title" --inputbox "$msg" "$height" "$width" "$default" 3>&1 1>&2 2>&3
}

ui_password() {
    local title="$1" msg="$2"
    local height="${3:-8}" width="${4:-60}"
    whiptail --title "$title" --passwordbox "$msg" "$height" "$width" 3>&1 1>&2 2>&3
}

ui_menu() {
    local title="$1" msg="$2"
    local height="$3" width="$4" list_height="$5"
    shift 5
    whiptail --title "$title" --menu "$msg" "$height" "$width" "$list_height" "$@" 3>&1 1>&2 2>&3
}

ui_checklist() {
    local title="$1" msg="$2"
    local height="$3" width="$4" list_height="$5"
    shift 5
    whiptail --title "$title" --checklist "$msg" "$height" "$width" "$list_height" "$@" 3>&1 1>&2 2>&3
}

ui_infobox() {
    local title="$1" msg="$2"
    local height="${3:-8}" width="${4:-50}"
    whiptail --title "$title" --infobox "$msg" "$height" "$width"
}
