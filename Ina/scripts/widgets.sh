#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
source "$SCRIPT_DIR/lib/widget-removal.sh"
source "$SCRIPT_DIR/lib/widget-position.sh"
ina_init widgets "$@"
ina_desktop
printf '%s\n' 'Available: clock, calendar, system. The retired Ina music desklet is removed.'
ina_array_read "$(ina_get org.cinnamon enabled-desklets)"
current=("${INA_ARRAY[@]}")
next="$(ina_get org.cinnamon next-desklet-id)"
[[ "$next" =~ ^[0-9]+$ && ${#next} -le 10 ]] || ina_error 'Unsupported next-desklet-id'
next=$((10#$next))
((next <= 2147483647)) || ina_error 'Unsupported next-desklet-id'
allocated=false
for entry in "${current[@]}"; do
    [[ "$entry" =~ ^[^:]+:([0-9]+):-?[0-9]+:-?[0-9]+$ ]] || ina_error "Unsupported desklet entry: $entry"
    identity="${BASH_REMATCH[1]}"
    ((${#identity} <= 10)) || ina_error "Unsupported desklet ID: $identity"
    number=$((10#$identity))
    ((number < 2147483647)) || ina_error "Desklet ID is too large: $identity"
    ((number < next)) || next=$((number + 1))
done
# Validate all requested widgets before recording or changing any files.
for name in "${INA_WIDGETS[@]}"; do
    case "$name" in
        clock) source_theme=/usr/share/cinnamon/desklets/clock@cinnamon.org ;;
        calendar) source_theme="$SCRIPT_DIR/../vendor/desklets/calendar@deeppradhan" ;;
        system) source_theme="$SCRIPT_DIR/../vendor/desklets/system-monitor-graph@rcassani" ;;
        *) ina_error "Unavailable widget: $name" ;;
    esac
    schema_path="$(ina_path "$source_theme/settings-schema.json")"
    [[ -f "$schema_path" ]] || ina_error "Widget schema missing: $schema_path"
    jq -e 'type=="object"' "$schema_path" >/dev/null || ina_error "Invalid widget schema: $schema_path"
    if [[ "$name" != clock ]]; then
        for file in desklet.js metadata.json settings-schema.json LICENSE; do
            [[ -f "$source_theme/$file" ]] || ina_error "Widget file missing: $source_theme/$file"
        done
    fi
done
declare -A seen=()
reloads=()
ina_begin
ina_remove_media
for name in "${INA_WIDGETS[@]}"; do
    [[ -z "${seen[$name]:-}" ]] || continue
    seen["$name"]=1
    case "$name" in
        clock) uuid=clock@cinnamon.org; x=30; y=30; source_theme="/usr/share/cinnamon/desklets/$uuid" ;;
        calendar) uuid=calendar@deeppradhan; x=30; y=140; source_theme="$SCRIPT_DIR/../vendor/desklets/$uuid" ;;
        system) uuid=system-monitor-graph@rcassani; x=0; y=0; source_theme="$SCRIPT_DIR/../vendor/desklets/$uuid" ;;
        *) ina_error "Unavailable widget: $name" ;;
    esac
    identity=''
    for entry in "${current[@]}"; do
        if [[ "$entry" == "$uuid:"* ]]; then IFS=: read -r _ identity _ _ <<< "$entry"; break; fi
    done
    existing=true
    if [[ -z "$identity" ]]; then
        existing=false
        ((next < 2147483647)) || ina_error 'No desklet IDs remain available'
        identity="$next"; next=$((next + 1)); allocated=true; current+=("$uuid:$identity:$x:$y")
    fi
    schema_path="$(ina_path "$source_theme/settings-schema.json")"
    [[ -f "$schema_path" ]] || ina_error "Widget schema missing: $schema_path"
    schema="$(cat -- "$schema_path")"
    jq -e 'type=="object"' <<< "$schema" >/dev/null
    if [[ "$name" != clock ]]; then
        if "$existing"; then
            for file in desklet.js settings-schema.json; do
                installed="$(ina_user_path "$INA_DATA/cinnamon/desklets/$uuid/$file")"
                if [[ ! -f "$installed" ]] || ! cmp -s -- "$source_theme/$file" "$installed"; then
                    reloads+=("$uuid")
                    break
                fi
            done
        fi
        [[ -f "$source_theme/LICENSE" ]] || ina_error 'Desklet license missing'
        for file in desklet.js metadata.json settings-schema.json LICENSE; do ina_copy "$source_theme/$file" "$INA_DATA/cinnamon/desklets/$uuid/$file"; done
    fi
    config="$(ina_user_path "$INA_CONFIG/cinnamon/spices/$uuid/$identity.json")"
    settings="$schema"; [[ ! -f "$config" ]] || settings="$(cat -- "$config")"
    if [[ "$name" == system ]]; then
        scale="$(jq -r '."scale-size".value // ."scale-size".default // 1' <<< "$settings")"
        if position="$(ina_widget_position "$scale")"; then
            read -r x y <<< "$position"
            printf 'System widget: primary monitor work area, upper right at %s,%s\n' "$x" "$y"
            # Reposition existing instances as well as newly allocated ones, without changing IDs.
            for index in "${!current[@]}"; do
                if [[ "${current[$index]}" == "$uuid:$identity:"* ]]; then current[$index]="$uuid:$identity:$x:$y"; fi
            done
        elif "$INA_DRY"; then
            printf '%s\n' 'System widget position unresolved in preview. Apply requires the primary monitor work area.' >&2
            # Do not preview an invented position. Existing coordinates remain;
            # a new instance is listed only once geometry can be resolved.
            if ! "$existing"; then
                pending=()
                for entry in "${current[@]}"; do [[ "$entry" == "$uuid:$identity:"* ]] || pending+=("$entry"); done
                current=("${pending[@]}")
            fi
        else ina_error 'Cannot determine the system widget position'; fi
    fi
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
            ({"refresh-interval":2,"text-color":$c,"background-color":$b,"midline-color":$m}; .[$k]=$l)')" ;;
    esac
    settings="$(jq --argjson overrides "$overrides" 'reduce ($overrides|keys[]) as $k (.;
        if has($k) then .[$k].value=$overrides[$k] else error("Unsupported widget key: "+$k) end)' <<< "$settings")"
    ina_widget_write "$config" "$overrides" "$settings"
done
if "$allocated"; then ina_setting org.cinnamon next-desklet-id "$next"; fi
ina_setting org.cinnamon enabled-desklets "$(ina_array "${current[@]}")"
ina_finish
# Reload only after the file/settings transaction is committed. A failed refresh
# must leave the journal intact so the user can retry or restore safely.
reload_failed=false
for uuid in "${reloads[@]}"; do
    printf 'Reload desklet: %s\n' "$uuid"
    if "$INA_DRY" || [[ -n "$INA_TEST" ]]; then continue; fi
    if ! command -v gdbus >/dev/null 2>&1; then
        printf 'Required command not found: gdbus\n' >&2
    elif ! gdbus call --session --dest org.Cinnamon --object-path /org/Cinnamon \
        --method org.Cinnamon.ReloadXlet "$uuid" DESKLET; then
        :
    else
        continue
    fi
    printf 'Desklet files were saved, but reload failed. Retry: gdbus call --session --dest org.Cinnamon --object-path /org/Cinnamon --method org.Cinnamon.ReloadXlet %q DESKLET\n' "$uuid" >&2
    printf 'Recovery: bash %q --component widgets --apply\n' "$SCRIPT_DIR/restore.sh" >&2
    reload_failed=true
done
"$reload_failed" && exit 1
exit 0
