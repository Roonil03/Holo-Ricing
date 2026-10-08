#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init animations "$@"
ina_desktop
ina_begin
ina_setting org.cinnamon desktop-effects true
ina_setting org.cinnamon desktop-effects-on-dialogs true
ina_setting org.cinnamon desktop-effects-on-menus false
ina_setting org.cinnamon desktop-effects-workspace false
ina_setting org.cinnamon desktop-effects-close "'fade'"
ina_setting org.cinnamon desktop-effects-map "'fade'"
ina_setting org.cinnamon desktop-effects-minimize "'traditional'"
ina_setting org.cinnamon desktop-effects-change-size false
ina_setting org.cinnamon window-effect-speed 1
printf '%s\n' 'Use built-in timing and easing. No motion extension is installed.'
ina_finish
