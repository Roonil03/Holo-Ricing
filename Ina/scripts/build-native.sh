#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init native "$@"
ina_need cc sha256sum
sources=(image-check lockscreen-native lockscreen-worker widget-position)
for name in "${sources[@]}"; do
    source_file="$(ina_path "$SCRIPT_DIR/../src/$name.c")"
    [[ -f "$source_file" ]] || ina_error "Native source is missing: $source_file"
done
ina_begin
if "$INA_DRY"; then
    for name in "${sources[@]}"; do
        printf 'Would compile %s into %s/ina/bin/%s. No compiler runs during preview.\n' "$SCRIPT_DIR/../src/$name.c" "$INA_DATA" "$name"
    done
    ina_finish
    exit 0
fi
for name in "${sources[@]}"; do
    source_file="$(ina_path "$SCRIPT_DIR/../src/$name.c")"
    INA_DOWNLOAD_TMP="$(mktemp "$INA_STATE/.native-XXXXXX")"
    cc -std=c11 -O2 -Wall -Wextra -Werror -Wl,-z,relro,-z,now "$source_file" -o "$INA_DOWNLOAD_TMP" -ldl
    if [[ "$name" == image-check ]]; then
        "$INA_DOWNLOAD_TMP" --check "$SCRIPT_DIR/../vendor/grub-evangelion/selectors/selected_c.png"
    else
        "$INA_DOWNLOAD_TMP" --help >/dev/null
    fi
    ina_copy "$INA_DOWNLOAD_TMP" "$INA_DATA/ina/bin/$name" 755
    source_hash="$(sha256sum < "$source_file")"
    ina_text "$INA_DATA/ina/bin/$name.source" "${source_hash:0:64}"$'\n'
    rm -- "$INA_DOWNLOAD_TMP"
    INA_DOWNLOAD_TMP=''
done
ina_finish
