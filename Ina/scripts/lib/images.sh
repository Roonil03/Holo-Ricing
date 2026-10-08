#!/usr/bin/env bash
set -euo pipefail
# Original MIT code. Source permissions are checked before network access.
ina_image_source() {
    local role="$1" record
    record="$(jq -ce --arg role "$role" '.images[] | select(.role == $role)' "$SCRIPT_DIR/../dotfiles/image-sources.json")" || ina_error "Image source missing: $role"
    INA_IMAGE_URL="$(jq -r '.url' <<< "$record")"
    INA_IMAGE_PERMISSION="$(jq -r '.permission' <<< "$record")"
    INA_IMAGE_ALLOWED="$(jq -r '.download_allowed' <<< "$record")"
    printf 'Selected %s: %s\nPermission: %s\n' "$role" "$INA_IMAGE_URL" "$INA_IMAGE_PERMISSION"
}
ina_jpeg() {
    local path="$1" header
    ina_need od
    [[ -f "$path" && -r "$path" ]] || ina_error "Readable JPEG missing: $path"
    header="$(od -An -tx1 -N3 -- "$path" | tr -d ' \n')"
    [[ "$header" == ffd8ff ]] || ina_error "Expected a JPEG header: $path"
}
ina_download_image() {
    local destination="$1" parent available expected
    destination="$(ina_user_path "$destination")"
    [[ "$INA_IMAGE_ALLOWED" == true && "$INA_IMAGE_PERMISSION" == private-personal-use ]] || ina_error 'Download blocked. Original image permissions remain [unverified]. Supply a licensed local file instead.'
    printf 'Local image destination: %s\nNo repository copy or redistribution.\n' "$destination"
    "$INA_DRY" && return 0
    "$INA_APPROVED" || ina_error 'Download requires --approved for private, personal use'
    if [[ -e "$destination" ]]; then
        expected="$(jq -r --arg p "$destination" '.files[$p].applied // empty' <<< "$INA_JSON")"
        [[ -n "$expected" && "$(base64 -w0 -- "$destination")" == "$expected" ]] || ina_error "Download destination exists without matching component ownership: $destination"
        ina_jpeg "$destination"
        ina_file "$destination" "$expected" 644
        return 0
    fi
    ina_need curl df
    parent="$(dirname -- "$destination")"
    while [[ ! -d "$parent" ]]; do parent="$(dirname -- "$parent")"; done
    for parent in "$parent" "$INA_STATE"; do
        available="$(df -Pk -- "$parent" | awk 'END {print $4}')"
        [[ "$available" =~ ^[0-9]+$ ]] && ((available >= 131072)) || ina_error "Require 128 MiB free for download and backup: $parent"
    done
    # curl writes only a private temporary file. The component journals the
    # validated bytes before publishing them at the destination.
    INA_DOWNLOAD_TMP="$(mktemp "$INA_STATE/.image-XXXXXX")"
    if ! curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time 120 --max-filesize 33554432 \
        --output "$INA_DOWNLOAD_TMP" "$INA_IMAGE_URL"; then
        ina_error 'Image download failed; destination was not changed'
    fi
    [[ "$(stat -c '%s' -- "$INA_DOWNLOAD_TMP")" -le 33554432 ]] || ina_error 'Image exceeds 32 MiB'
    ina_jpeg "$INA_DOWNLOAD_TMP"
    ina_file "$destination" "$(base64 -w0 -- "$INA_DOWNLOAD_TMP")" 644
    rm -- "$INA_DOWNLOAD_TMP"
    INA_DOWNLOAD_TMP=''
}
