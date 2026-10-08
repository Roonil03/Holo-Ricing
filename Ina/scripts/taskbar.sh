#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init taskbar "$@"
ina_desktop
source_theme=/usr/share/themes/Mint-Y-Dark/cinnamon/cinnamon.css
[[ -f "$source_theme" ]] || ina_error 'Installed Mint-Y-Dark Cinnamon theme is required'
ina_array_read "$(ina_get org.cinnamon panels-enabled)"
panels=("${INA_ARRAY[@]}"); panel_id=''
for entry in "${panels[@]}"; do
    [[ "$entry" =~ ^([0-9]+):([0-9]+):(top|bottom|left|right)$ ]] || ina_error "Unsupported panel: $entry"
    if [[ "${BASH_REMATCH[2]}" == 0 && -z "$panel_id" ]]; then panel_id="${BASH_REMATCH[1]}"; fi
done
[[ -n "$panel_id" ]] || ina_error 'No primary-monitor panel found'
for index in "${!panels[@]}"; do
    [[ "${panels[index]}" != "$panel_id:0:"* ]] || panels[index]="$panel_id:0:bottom"
done
ina_array_read "$(ina_get org.cinnamon panels-height)"
heights=()
for entry in "${INA_ARRAY[@]}"; do
    [[ "$entry" =~ ^[0-9]+:[0-9]+$ ]] || ina_error "Unsupported panel height: $entry"
    [[ "$entry" == "$panel_id:"* ]] || heights+=("$entry")
done
heights+=("$panel_id:40")
ina_array_read "$(ina_get org.cinnamon enabled-applets)"
others=() left=() center=() right=()
for entry in "${INA_ARRAY[@]}"; do
    if [[ "$entry" != "panel$panel_id:"* ]]; then others+=("$entry"); continue; fi
    IFS=: read -r panel zone position uuid identity extra <<< "$entry"
    [[ -z "${extra:-}" && "$position" =~ ^[0-9]+$ && "$identity" =~ ^[0-9]+$ && "$zone" =~ ^(left|center|right)$ ]] ||
        ina_error "Unsupported applet entry: $entry"
    case "$uuid" in
        menu@cinnamon.org|grouped-window-list@cinnamon.org) zone=left ;;
        calendar@cinnamon.org) zone=center ;;
        systray@cinnamon.org|xapp-status@cinnamon.org|notifications@cinnamon.org|sound@cinnamon.org|network@cinnamon.org|power@cinnamon.org) zone=right ;;
    esac
    case "$zone" in
        left) left+=("$uuid:$identity") ;; center) center+=("$uuid:$identity") ;; right) right+=("$uuid:$identity") ;;
    esac
done
layout=("${others[@]}")
for zone in left center right; do
    declare -n entries="$zone"
    for index in "${!entries[@]}"; do layout+=("panel$panel_id:$zone:$index:${entries[index]}"); done
    unset -n entries
done
css="$(cat <<EOF
/* Original Ina overrides; installed Mint base retains its own license. */
@import url("$source_theme");
#panel { background-color: $INA_ABYSS; color: $INA_ANCIENT_PARCHMENT; border: 1px solid $INA_DEEP_VIOLET; }
.panel-left, .panel-center, .panel-right { spacing: 4px; }
.applet-box { padding-left: 6px; padding-right: 6px; color: $INA_ANCIENT_PARCHMENT; }
.applet-box:hover { background-color: $INA_DEEP_VIOLET; color: $INA_ELDRITCH_TEAL; }
.panel-launchers, .grouped-window-list-item-box { color: $INA_MUTED_TEXT; }
.grouped-window-list-item-box:active, .grouped-window-list-item-box:focus { background-color: $INA_DEEP_VIOLET; border-bottom: 2px solid $INA_ELDRITCH_TEAL; }
.calendar { color: $INA_ANCIENT_PARCHMENT; }
EOF
)"
ina_begin
ina_text "$INA_DATA/themes/Ina-Panel/cinnamon/cinnamon.css" "$css"$'\n' 644
ina_setting org.cinnamon panels-enabled "$(ina_array "${panels[@]}")"
ina_setting org.cinnamon panels-height "$(ina_array "${heights[@]}")"
ina_setting org.cinnamon enabled-applets "$(ina_array "${layout[@]}")"
ina_setting org.cinnamon.theme name "'Ina-Panel'"
printf '%s\n' 'Other panels, custom applets, existing IDs, and clock formatting are retained.'
ina_finish
