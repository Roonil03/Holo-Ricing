#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init fastfetch "$@"
ina_need fastfetch
config="$(jq --arg image "$INA_CONFIG/fastfetch/tako-ascii.txt" '.logo.source=$image | .display.separator=" -> "' "$SCRIPT_DIR/../dotfiles/fastfetch_config.jsonc")"
art="$(sed '/^-\+$/d; s/-/ /g; s/^/\x1b[35m/; s/:/\x1b[33m:\x1b[35m/g; s/$/\x1b[0m/' "$SCRIPT_DIR/../dotfiles/tako-ascii.txt")"
ina_begin
ina_text "$INA_CONFIG/fastfetch/config.jsonc" "$config"$'\n'
ina_text "$INA_CONFIG/fastfetch/tako-ascii.txt" "$art"$'\n'
ina_finish
printf '%s\n' 'Fastfetch configured. Run fastfetch manually.'
