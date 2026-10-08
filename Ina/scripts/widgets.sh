#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init widgets "$@"
ina_desktop
printf '%s\n' 'Available: clock, calendar, system. Soundbox remains unavailable.'
if (("${#INA_WIDGETS[@]}" == 0)); then
    "$INA_DRY" || ina_error 'Select widgets with --widgets clock calendar system'
    exit 0
fi
ina_array_read "$(ina_get org.cinnamon enabled-desklets)"
current=("${INA_ARRAY[@]}"); next=0
for entry in "${current[@]}"; do
    [[ "$entry" =~ ^[^:]+:([0-9]+):-?[0-9]+:-?[0-9]+$ ]] || ina_error "Unsupported desklet entry: $entry"
    identity="${BASH_REMATCH[1]}"; number=$((10#$identity))
    ((number < next)) || next=$((number + 1))
done
declare -A seen=()
ina_begin
for name in "${INA_WIDGETS[@]}"; do
    [[ -z "${seen[$name]:-}" ]] || continue
    seen["$name"]=1
    case "$name" in
        clock) uuid=clock@cinnamon.org; x=30; y=30; source_theme="/usr/share/cinnamon/desklets/$uuid" ;;
        calendar) uuid=calendar@deeppradhan; x=30; y=140; source_theme="$SCRIPT_DIR/../vendor/desklets/$uuid" ;;
        system) uuid=system-monitor-graph@rcassani; x=400; y=140; source_theme="$SCRIPT_DIR/../vendor/desklets/$uuid" ;;
        *) ina_error "Unavailable widget: $name" ;;
    esac
    identity=''
    for entry in "${current[@]}"; do
        if [[ "$entry" == "$uuid:"* ]]; then IFS=: read -r _ identity _ _ <<< "$entry"; break; fi
    done
    if [[ -z "$identity" ]]; then identity="$next"; next=$((next + 1)); current+=("$uuid:$identity:$x:$y"); fi
    schema_path="$(ina_path "$source_theme/settings-schema.json")"
    [[ -f "$schema_path" ]] || ina_error "Widget schema missing: $schema_path"
    schema="$(cat -- "$schema_path")"
    jq -e 'type=="object"' <<< "$schema" >/dev/null
    if [[ "$name" != clock ]]; then
        [[ -f "$source_theme/LICENSE" ]] || ina_error 'Desklet license missing'
        for file in desklet.js metadata.json settings-schema.json LICENSE; do ina_copy "$source_theme/$file" "$INA_DATA/cinnamon/desklets/$uuid/$file"; done
    fi
    config="$(ina_user_path "$INA_CONFIG/cinnamon/spices/$uuid/$identity.json")"
    settings="$schema"; [[ ! -f "$config" ]] || settings="$(cat -- "$config")"
    settings="$(jq -n --argjson schema "$schema" --argjson old "$settings" '
        if ($old|type) != "object" then error("Expected widget settings object") else
        reduce ($schema|keys[]) as $k ($old;
            if ($schema[$k]|type)=="object" and ($schema[$k]|has("default")) then
                .[$k] = (.[$k] // $schema[$k]) |
                .[$k].value = (if .[$k]|has("value") then .[$k].value else $schema[$k].default end)
            else . end) end')"
    rgb() { local h="${1#\#}"; printf 'rgb(%d,%d,%d)' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"; }
    rgba() { local h="${1#\#}"; printf 'rgba(%d,%d,%d,1)' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"; }
    case "$name" in
        clock) overrides="$(jq -n --arg c "$(rgb "$INA_ANCIENT_PARCHMENT")" '{"font-size":36,"text-color":$c,"use-custom-format":true,"date-format":"%H:%M"}')" ;;
        calendar) overrides="$(jq -n --arg c "$(rgb "$INA_ANCIENT_PARCHMENT")" --arg b "$(rgb "$INA_ABYSS")" --arg s "$(rgb "$INA_LAVENDER")" --arg a "$(rgb "$INA_SOFT_PEACH")" '{"colour-text":$c,"colour-background":$b,"colour-sundays":$s,"colour-saturdays":$a}')" ;;
        system) overrides="$(jq -n --argjson schema "$schema" --arg c "$(rgba "$INA_ANCIENT_PARCHMENT")" --arg b "$(rgba "$INA_ABYSS")" --arg m "$(rgba "$INA_DEEP_VIOLET")" --arg l "$(rgba "$INA_ELDRITCH_TEAL")" '
            reduce ($schema|keys[]|select(startswith("line-color-"))) as $k
            ({"refresh-interval":3,"text-color":$c,"background-color":$b,"midline-color":$m}; .[$k]=$l)')" ;;
    esac
    settings="$(jq --argjson overrides "$overrides" 'reduce ($overrides|keys[]) as $k (.;
        if has($k) then .[$k].value=$overrides[$k] else error("Unsupported widget key: "+$k) end)' <<< "$settings")"
    ina_text "$config" "$settings"$'\n'
done
ina_setting org.cinnamon enabled-desklets "$(ina_array "${current[@]}")"
ina_finish
