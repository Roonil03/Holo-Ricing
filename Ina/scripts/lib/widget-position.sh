#!/usr/bin/env bash
set -euo pipefail
# Original MIT code. Read-only placement in Cinnamon stage pixels.
ina_widget_workarea() (
    local native source_file source_hash installed_hash temporary
    native="$(ina_user_path "$INA_DATA/ina/bin/widget-position")"
    source_file="$SCRIPT_DIR/../src/widget-position.c"
    if [[ -x "$native" && -f "$native.source" ]]; then
        ina_path "$native.source" >/dev/null
        ina_need sha256sum
        source_hash="$(sha256sum < "$source_file")"
        installed_hash="$(cat -- "$native.source")"
        if [[ "$installed_hash" == "${source_hash:0:64}" ]]; then
            "$native" --workarea
            exit
        fi
    fi
    if "$INA_DRY"; then
        printf '%s\n' 'Monitor helper is not built. Apply builds it temporarily; build-native.sh --apply installs it for previews.' >&2
        exit 1
    fi
    ina_need cc
    temporary="$(mktemp "${TMPDIR:-/tmp}/ina-widget-position.XXXXXXXX")"
    trap 'rm -f -- "$temporary"' EXIT
    cc -std=c11 -O2 -Wall -Wextra -Werror -Wl,-z,relro,-z,now "$source_file" -o "$temporary" -ldl || exit
    "$temporary" --workarea
)

ina_widget_position() {
    local scale="$1" area fixture geometry
    if [[ -n "$INA_TEST" ]]; then
        fixture="$(ina_path "$INA_TEST/monitor.json")"
        if [[ -f "$fixture" ]]; then
            area="$(jq -c -s 'if length == 1 then .[0] else error("Expected one monitor geometry object") end' "$fixture")" || return
        else
            area='{"x":0,"y":0,"width":1920,"height":1080,"scale":1}'
        fi
    else
        geometry="$(ina_widget_workarea)" || return
        area="$(jq -n --arg geometry "$geometry" '
            ($geometry | split(" ") | map(tonumber)) as $g |
            if ($g | length) != 5 then error("Invalid monitor geometry") else
            {x:$g[0],y:$g[1],width:$g[2],height:$g[3],scale:$g[4]} end')" || return
    fi
    jq -er --arg requested "$scale" '
        ($requested | tonumber) as $size |
        if ($size | type) != "number" or $size < 0.5 or $size > 5 then
            error("Invalid system widget scale")
        elif type != "object" then error("Invalid monitor geometry")
        elif ([.x,.y,.width,.height,.scale] | all(.[];
            type == "number" and . == floor and . >= -2147483648 and . <= 2147483647) | not) then
            error("Invalid monitor geometry")
        elif .width <= 0 or .height <= 0 or .scale < 1 or .scale > 4 then
            error("Invalid monitor dimensions or scale")
        else
            .scale as $factor |
            (.x * $factor) as $left | (.y * $factor) as $top |
            (.width * $factor) as $width | (.height * $factor) as $height |
            # Reserve room for desklet borders/header and a panel-aware gap.
            (((330 * $size + 26) * $factor) | ceil) as $graph_width |
            (((120 * $size + 70) * $factor) | ceil) as $graph_height |
            if $graph_width > $width or $graph_height > $height then
                error("System widget does not fit this monitor; reduce its scale-size first")
            else
                ([$left, $left + $width - $graph_width - 30 * $factor] | max) as $x |
                ([$top + 30 * $factor, $top + $height - $graph_height] | min) as $y |
                "\($x) \($y)"
            end
        end' <<< "$area"
}
