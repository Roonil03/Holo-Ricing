#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init tiling-window "$@"
ina_desktop
uuid=gTile@shuairan
extension="$INA_DATA/cinnamon/extensions/$uuid"
# A system installation is also acceptable. Do not download or replace it.
if [[ ! -d "$extension" ]]; then extension="/usr/share/cinnamon/extensions/$uuid"; fi
ina_path "$extension" >/dev/null
[[ -f "$extension/metadata.json" && -f "$extension/LICENSE" ]] || ina_error 'Install a licensed gTile extension manually before enabling it'
jq -e --arg uuid "$uuid" '.uuid == $uuid' "$extension/metadata.json" >/dev/null || ina_error 'Installed extension metadata does not match gTile'
ina_array_read "$(ina_get org.cinnamon enabled-extensions)"
enabled=("${INA_ARRAY[@]}")
found=false
for entry in "${enabled[@]}"; do [[ "$entry" != "$uuid" ]] || found=true; done
"$found" || enabled+=("$uuid")
ina_begin
ina_setting org.cinnamon enabled-extensions "$(ina_array "${enabled[@]}")"
ina_finish
printf '%s\n' 'Enabled the installed gTile extension. Run restore.sh --component tiling-window --apply to restore the prior setting.'
