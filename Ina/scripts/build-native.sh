#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init native "$@"
source_file="$(ina_path "$SCRIPT_DIR/../src/image-check.c")"
[[ -f "$source_file" ]] || ina_error 'Native image validator source is missing'
ina_need cc sha256sum
ina_begin
if "$INA_DRY"; then
    printf 'Would compile %s into %s/ina/bin/image-check. No compiler runs during preview.\n' "$source_file" "$INA_DATA"
    ina_finish
    exit 0
fi
INA_DOWNLOAD_TMP="$(mktemp "$INA_STATE/.native-XXXXXX")"
cc -std=c11 -O2 -Wall -Wextra -Werror -Wl,-z,relro,-z,now "$source_file" -o "$INA_DOWNLOAD_TMP" -ldl
"$INA_DOWNLOAD_TMP" --check "$SCRIPT_DIR/../vendor/grub-evangelion/selectors/selected_c.png"
ina_copy "$INA_DOWNLOAD_TMP" "$INA_DATA/ina/bin/image-check" 755
source_hash="$(sha256sum < "$source_file")"
ina_text "$INA_DATA/ina/bin/image-check.source" "${source_hash:0:64}"$'\n'
rm -- "$INA_DOWNLOAD_TMP"
INA_DOWNLOAD_TMP=''
ina_finish
