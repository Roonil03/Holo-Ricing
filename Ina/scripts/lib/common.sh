#!/usr/bin/env bash
set -euo pipefail
ina_main() {
    local component="$1"
    shift
    command -v python3 >/dev/null 2>&1 || { printf '%s\n' 'Error: python3 is required.' >&2; return 1; }
    local script_dir
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    source "$script_dir/../../dotfiles/colors.sh"
    PYTHONDONTWRITEBYTECODE=1 exec python3 "$script_dir/engine.py" "$component" "$@"
}
