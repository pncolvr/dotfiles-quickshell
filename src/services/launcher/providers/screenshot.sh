#!/usr/bin/env bash

WORKSPACE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$WORKSPACE"/_common/utils.sh
source "$(get_env_file "${BASH_SOURCE[0]:-0}")"
# set the following variables on the .env file
# SCREENSHOT_FOLDER=

function pick() {
    bash "$PICKER_LAUNCHER" --dmenu -case-smart -sort -sorting-method fzf -p ""
}

function capture_screenshot() {
    local method=$1
    sleep 0.3 # allow helper stuff to be removed from screen
    timeout 30 hyprshot --freeze --silent --clipboard-only --raw --mode "$method"
}

function screenshot() {
    local method=$1
    local filename
    local file
    file=$(date '+%Y-%m-%d_%H:%M:%S').png
    filename="$SCREENSHOT_FOLDER/$file"

    capture_screenshot "$method" | satty --filename - --output-filename "$filename"

    if [[ -f "$filename" ]]; then
        open_file_explorer "$filename"
    fi
}

function detect_qrcode() {
    local qr_result
    qr_result=$(capture_screenshot region | zbarimg --raw -q - 2>/dev/null)

    if [[ -n "$qr_result" ]]; then
        notify-send --urgency low "$qr_result"
        echo "$qr_result" | wl-copy
    else
        notify-send --urgency low "No QR code found in selected region"
    fi
}

function detect_text() {
    local ocr_result

    ocr_result=$(capture_screenshot region | tesseract stdin stdout -l por 2>/dev/null)
    if [[ -n "$ocr_result" ]]; then
        notify-send --urgency low "$ocr_result"
        echo "$ocr_result" | wl-copy
        echo "$ocr_result"
    else
        notify-send --urgency low "No readable text found in selected region"
    fi
}

method=$1

if [[ -z "$method" ]]; then
    selected=$(echo -e "ocr\noutput\nqrcode\nregion\nwindow" | pick)
    if [[ -n "$selected" ]]; then
        method="$selected"
    fi
fi

case "$method" in
    region|output|window) screenshot "$method";;
    qrcode) detect_qrcode;;
    ocr) detect_text;;
    *) echo "Usage: ${BASH_SOURCE[0]:-0} {region|output|window|qrcode|ocr}" && exit 1;;
esac
