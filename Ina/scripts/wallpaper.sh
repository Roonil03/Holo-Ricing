#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init wallpaper "$@"
ina_desktop
if [[ -z "$INA_IMAGE" ]]; then
    "$INA_DRY" || ina_error 'Supply --image PATH --approved'
    printf '%s\n' 'No approved wallpaper selected. No download or wallpaper change.'
    exit 0
fi
"$INA_APPROVED" || ina_error 'Image approval requires --approved after checking its original license'
image="$(ina_path "$INA_IMAGE")"
[[ -f "$image" && -r "$image" ]] || ina_error "Readable image missing: $image"
ina_need od
header="$(od -An -tx1 -N16 -- "$image" | tr -d ' \n')"
case "$header" in
    89504e470d0a1a0a*|ffd8ff*|474946383761*|474946383961*|52494646????????57454250*) ;;
    *) ina_error 'Expected a PNG, JPEG, GIF, or WebP header' ;;
esac
uri="$(jq -rn --arg p "$image" '$p|split("/")|map(@uri)|join("/")')"
ina_begin
ina_setting org.cinnamon.desktop.background.slideshow slideshow-enabled false
ina_setting org.cinnamon.desktop.background picture-uri "$(ina_quote "file://$uri")"
ina_setting org.cinnamon.desktop.background picture-options "'zoom'"
printf '%s\n' 'One static image. No rotation or login-screen changes.'
ina_finish
