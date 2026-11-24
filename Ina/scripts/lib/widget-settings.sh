#!/usr/bin/env bash
set -euo pipefail
# Owned desklet values coexist with Cinnamon's schema metadata and other preferences.
ina_widget_keys() {
    local path="$1" applied="$2"
    case "$path" in
        */clock@cinnamon.org/*.json) printf '%s' '["font-size","text-color","use-custom-format","date-format"]' ;;
        */calendar@deeppradhan/*.json) printf '%s' '["colour-text","colour-background","colour-sundays","colour-saturdays"]' ;;
        */system-monitor-graph@rcassani/*.json) jq -cn --argjson a "$applied" '["refresh-interval","text-color","background-color","midline-color"] + [$a|keys[]|select(startswith("line-color-"))]' ;;
        */ina-media@holo-ricing/*.json) printf '%s' '["foreground","background","accent"]' ;;
        *) return 1 ;;
    esac
}
ina_widget_migrate_entry() {
    local path="$1" entry="$2" live="$3" applied keys
    jq -e '.widget_values|type == "object"' <<< "$entry" >/dev/null && { printf '%s' "$entry"; return; }
    applied="$(jq -ce '.applied|@base64d|fromjson' <<< "$entry")" || ina_error "Invalid previous widget backup: $path"
    keys="$(ina_widget_keys "$path" "$applied")" || ina_error "Unknown widget backup: $path"
    jq -cn --argjson e "$entry" --argjson a "$applied" --argjson now "$live" --argjson keys "$keys" '
      ($e.original | if . == null then null else @base64d|fromjson end) as $o |
      $e + {widget_baseline:$a, widget_values:(reduce $keys[] as $k ({};
        if ($a[$k]|type)!="object" or ($a[$k]|has("value")|not) then error("Missing applied widget value: "+$k) else
        .[$k]={original_key_exists:($o != null and ($o|has($k))), original_exists:($o != null and ($o|has($k)) and ($o[$k]|type)=="object" and ($o[$k]|has("value"))),
               original:(if $o == null then $a[$k].default else $o[$k].value end),
               applied:(if $k=="refresh-interval" and $a[$k].value==3 and $now[$k].value==$a[$k].default and ([($a[$k].options // {})[]]|index(3)|not) then $now[$k].value else $a[$k].value end)} end))}' || ina_error "Cannot migrate widget backup: $path"
}
ina_widget_validate() {
    local path="$1" entry="$2" live="$3"
    jq -en --argjson e "$entry" --argjson live "$live" '
      ($live|type)=="object" and all($e.widget_values|to_entries[];
        . as $v | if ($live[$v.key]|type)=="object" and ($live[$v.key]|has("value")) then
          ($live[$v.key].value == $v.value.applied or (($v.value.original_exists or $e.original == null) and $live[$v.key].value == $v.value.original))
        else ($e.original != null and ($v.value.original_exists|not)) end)' >/dev/null || ina_error "Widget setting changed externally: $path"
}
ina_widget_prepare_restore() {
    local path="$1" entry="$2" live="$3"
    jq -cn --argjson e "$entry" --argjson live "$live" '
      def unowned($keys): with_entries(. as $item | select($item.key != "__md5__" and ($keys|index($item.key)|not)) | if (.value|type)=="object" and (.value|has("value")) then .value={value:.value.value} else . end);
      ($e.widget_values|keys) as $keys |
      if $e.original == null and ($live|unowned($keys)) == ($e.widget_baseline|unowned($keys)) then {remove:true}
      else {remove:false, content:(reduce ($e.widget_values|to_entries[]) as $v ($live;
          if $v.value.original_exists or $e.original == null then .[$v.key].value=$v.value.original
          elif $v.value.original_key_exists then .[$v.key] |= del(.value) else del(.[$v.key]) end))} end'
}
ina_widget_write() {
    local path="$1" wanted="$2" settings="$3" entry live current mode baseline rollback
    path="$(ina_user_path "$path")"
    [[ ! -e "$path" || -f "$path" ]] || ina_error "Not a regular file: $path"
    live='{}'; current='null'; mode=600
    if [[ -f "$path" ]]; then
        live="$(cat -- "$path")"; jq -e 'type=="object"' <<< "$live" >/dev/null || ina_error "Invalid widget settings: $path"
        current="$(base64 -w0 -- "$path" | jq -Rs .)"; mode="$(stat -c '%a' -- "$path")"
    fi
    printf 'Widget settings: %s\n' "$path"
    if jq -e --arg p "$path" '.files|has($p)' <<< "$INA_JSON" >/dev/null; then
        entry="$(jq -c --arg p "$path" '.files[$p]' <<< "$INA_JSON")"
        entry="$(ina_widget_migrate_entry "$path" "$entry" "$live")"
        [[ -f "$path" ]] || ina_error "Widget settings missing: $path"
        ina_widget_validate "$path" "$entry" "$live"
    else
        entry="$(jq -cn --argjson o "$current" --arg m "$mode" --argjson b "$settings" '{original:$o,mode:$m,applied_mode:$m,widget_baseline:$b,widget_values:{}}')"
    fi
    "$INA_DRY" && return 0
    baseline="$settings"
    entry="$(jq -cn --argjson e "$entry" --argjson live "$live" --argjson w "$wanted" --argjson baseline "$baseline" --argjson exists "$( [[ -f "$path" ]] && printf true || printf false )" '
      $e | reduce ($w|keys[]) as $k (.;
        if .widget_values|has($k) then .widget_values[$k].applied=$w[$k]
        else .widget_values[$k]={original_key_exists:($exists and ($live|has($k))), original_exists:($exists and ($live|has($k)) and ($live[$k]|type)=="object" and ($live[$k]|has("value"))), original:(if $exists then $live[$k].value else $baseline[$k].default end),applied:$w[$k]} end)')"
    entry="$(jq --arg a "$(ina_b64 "$settings"$'\n')" '.applied=$a' <<< "$entry")"
    rollback="$(jq -cn --argjson o "$current" --arg m "$mode" --argjson live "$live" --argjson w "$wanted" --argjson baseline "$baseline" --arg a "$(ina_b64 "$settings"$'\n')" --argjson exists "$( [[ -f "$path" ]] && printf true || printf false )" '
      {original:$o,mode:$m,applied_mode:$m,applied:$a,widget_baseline:$baseline,widget_values:(reduce ($w|keys[]) as $k ({}; .[$k]={original_key_exists:($exists and ($live|has($k))), original_exists:($exists and ($live|has($k)) and ($live[$k]|type)=="object" and ($live[$k]|has("value"))), original:(if $exists then $live[$k].value else $baseline[$k].default end),applied:$w[$k]}))}')"
    INA_JSON="$(jq --arg p "$path" --argjson e "$entry" '.files[$p]=$e' <<< "$INA_JSON")"
    INA_ROLLBACK_JSON="$(jq --arg p "$path" --argjson e "$rollback" '.files[$p]=$e' <<< "$INA_ROLLBACK_JSON")"
    ina_track_dirs "$path"; ina_save
    ina_atomic "$path" "$(ina_b64 "$settings"$'\n')" "$mode"
}
