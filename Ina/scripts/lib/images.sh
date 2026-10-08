#!/usr/bin/env bash
set -euo pipefail
# Original MIT code. Selected images are downloaded only on explicit application.
ina_image_source() {
    local role="$1" record
    record="$(jq -ce --arg role "$role" '.images[] | select(.role == $role)' "$SCRIPT_DIR/../dotfiles/image-sources.json")" || ina_error "Image source missing: $role"
    INA_IMAGE_URL="$(jq -r '.url' <<< "$record")"
    INA_IMAGE_ALLOWED="$(jq -r '.download_allowed' <<< "$record")"
    printf 'Selected %s: %s\n' "$role" "$INA_IMAGE_URL"
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
    [[ "$INA_IMAGE_ALLOWED" == true ]] || ina_error 'Download is disabled for this source'
    [[ "$INA_IMAGE_URL" == https://* ]] || ina_error 'Image downloads require an HTTPS URL'
    printf 'Local image destination: %s\nNo repository copy or redistribution.\n' "$destination"
    "$INA_DRY" && return 0
    "$INA_APPROVED" || ina_error 'Download requires --approved'
    if [[ -e "$destination" ]]; then
        expected="$(jq -r --arg p "$destination" '.files[$p].applied // empty' <<< "$INA_JSON")"
        [[ -n "$expected" && "$(base64 -w0 -- "$destination")" == "$expected" ]] || ina_error "Download destination exists without matching component ownership: $destination"
        ina_jpeg "$destination"
        ina_file "$destination" "$expected" 644
        return 0
    fi
    ina_need wget timeout head df
    parent="$(dirname -- "$destination")"
    while [[ ! -d "$parent" ]]; do parent="$(dirname -- "$parent")"; done
    for parent in "$parent" "$INA_STATE"; do
        available="$(df -Pk -- "$parent" | awk 'END {print $4}')"
        [[ "$available" =~ ^[0-9]+$ ]] && ((available >= 131072)) || ina_error "Require 128 MiB free for download and backup: $parent"
    done
    # Bound output independently of Content-Length. Redirects are refused,
    # and wget cannot read user configuration or write an HSTS cache.
    # Journal validated bytes before publishing them at the destination.
    INA_DOWNLOAD_TMP="$(mktemp "$INA_STATE/.image-XXXXXX")"
    if ! timeout 180 wget --no-config --no-hsts --https-only --max-redirect=0 \
        --timeout=30 --tries=2 --no-verbose --output-document=- -- "$INA_IMAGE_URL" \
        | head -c 33554433 > "$INA_DOWNLOAD_TMP"; then
        ina_error 'Image download failed; destination was not changed'
    fi
    [[ "$(stat -c '%s' -- "$INA_DOWNLOAD_TMP")" -le 33554432 ]] || ina_error 'Image exceeds 32 MiB'
    ina_jpeg "$INA_DOWNLOAD_TMP"
    ina_file "$destination" "$(base64 -w0 -- "$INA_DOWNLOAD_TMP")" 644
    rm -- "$INA_DOWNLOAD_TMP"
    INA_DOWNLOAD_TMP=''
}
