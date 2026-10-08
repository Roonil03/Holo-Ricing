#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init icons "$@"
ina_desktop
[[ -f /usr/share/icons/Mint-Y-Purple/index.theme && -f /usr/share/doc/mint-y-icons/copyright ]] ||
    ina_error 'Install mint-y-icons manually before selecting Mint-Y-Purple'
grep -q 'CC-BY-SA-4' /usr/share/doc/mint-y-icons/copyright ||
    ina_error 'Installed icon license could not be verified'
grep -q 'https://github.com/linuxmint/mint-y-icons' /usr/share/doc/mint-y-icons/copyright ||
    ina_error 'Installed icon source could not be verified'
ina_begin
ina_setting org.cinnamon.desktop.interface icon-theme "'Mint-Y-Purple'"
ina_finish
