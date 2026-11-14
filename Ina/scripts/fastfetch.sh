#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init fastfetch "$@"
ina_need fastfetch python3
config="$(python3 - "$SCRIPT_DIR/../dotfiles/fastfetch_config.jsonc" "$INA_CONFIG/fastfetch/tako-ascii.txt" <<'PY'
import json, pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
text = text.replace('"~/.config/fastfetch/tako-ascii.txt"', json.dumps(sys.argv[2]))
text = text.replace(' 󰇙 ', ' -> ')
print(text, end='')
PY
)"
art="$(sed '/^-\+$/d; s/-/ /g; s/^/\x1b[35m/; s/:/\x1b[33m:\x1b[35m/g; s/$/\x1b[0m/' "$SCRIPT_DIR/../dotfiles/tako-ascii.txt")"
ina_begin
ina_text "$INA_CONFIG/fastfetch/config.jsonc" "$config"$'\n'
ina_text "$INA_CONFIG/fastfetch/tako-ascii.txt" "$art"$'\n'
ina_finish
printf '%s\n' 'Fastfetch configured. Run fastfetch manually.'
