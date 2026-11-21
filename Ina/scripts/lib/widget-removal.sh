#!/usr/bin/env bash
set -euo pipefail
# Retire only this project's original music desklet. Existing journals establish
# file ownership; an unknown or externally changed file is left in place.
ina_remove_media() {
    local uuid=ina-media@holo-ricing entry path record current_bytes mode directory
    local filtered=()
    for entry in "${current[@]}"; do
        if [[ "$entry" == "$uuid:"* ]]; then
            printf 'Remove retired Ina music desklet: %s\n' "$entry"
        else filtered+=("$entry"); fi
    done
    current=("${filtered[@]}")
    while IFS= read -r path; do
        case "$path" in
            "$INA_DATA/cinnamon/desklets/$uuid/desklet.js"|\
            "$INA_DATA/cinnamon/desklets/$uuid/metadata.json"|\
            "$INA_DATA/cinnamon/desklets/$uuid/settings-schema.json"|\
            "$INA_DATA/cinnamon/desklets/$uuid/LICENSE") ;;
            "$INA_CONFIG/cinnamon/spices/$uuid/"*.json)
                [[ "${path##*/}" =~ ^[0-9]+\.json$ ]] || continue ;;
            *) continue ;;
        esac
        path="$(ina_user_path "$path")"
        record="$(jq -c --arg p "$path" '.files[$p]' <<< "$INA_JSON")"
        [[ ! -e "$path" || -f "$path" ]] || ina_error "Not a regular retired widget file: $path"
        [[ -f "$path" ]] || continue
        current_bytes="$(base64 -w0 -- "$path")"
        mode="$(stat -c '%a' -- "$path")"
        if [[ "$current_bytes" != "$(jq -r '.applied // ""' <<< "$record")" || "$mode" != "$(jq -r '.applied_mode // .mode' <<< "$record")" ]]; then
            printf 'Preserve externally changed retired widget file: %s\n' "$path" >&2
            continue
        fi
        printf 'Remove backed-up retired widget file: %s\n' "$path"
        "$INA_DRY" && continue
        # Keep both the first application baseline and the removed bytes. The
        # latter remain reviewable in the backup even when the baseline is null.
        record="$(jq --arg bytes "$current_bytes" 'del(.widget_values,.widget_baseline) | .removed_content=$bytes | .applied=null | .removed_file=true' <<< "$record")"
        INA_JSON="$(jq --arg p "$path" --argjson r "$record" '.files[$p]=$r' <<< "$INA_JSON")"
        INA_ROLLBACK_JSON="$(jq --arg p "$path" --arg bytes "$current_bytes" --arg mode "$mode" '.files[$p]={original:$bytes,applied:null,mode:$mode,applied_mode:$mode,removed_file:true}' <<< "$INA_ROLLBACK_JSON")"
        ina_save
        rm -- "$path"
    done < <(jq -r '.files|keys[]' <<< "$INA_JSON")
    for directory in "$INA_DATA/cinnamon/desklets/$uuid" "$INA_CONFIG/cinnamon/spices/$uuid"; do
        ina_user_path "$directory" >/dev/null
        [[ ! -d "$directory" ]] || printf 'Retired widget directory: %s (unknown files are preserved)\n' "$directory"
        # Leave empty directories until restore. Their original journal tracks
        # cleanup, and keeping them here avoids changing unrecorded directories.
        if [[ -d "$directory" ]]; then
            for path in "$directory/"*; do
                [[ -e "$path" ]] || continue
                if ! jq -e --arg p "$path" '.files|has($p)' <<< "$INA_JSON" >/dev/null; then
                    printf 'Preserve untracked retired widget file: %s\n' "$path" >&2
                fi
            done
        fi
    done
}
