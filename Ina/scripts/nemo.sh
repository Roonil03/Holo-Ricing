#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init nemo "$@"
ina_desktop
ina_begin
ina_setting org.nemo.preferences default-folder-viewer "'icon-view'"
ina_setting org.nemo.icon-view default-zoom-level "'standard'"
ina_setting org.nemo.icon-view default-use-tighter-layout false
ina_setting org.nemo.window-state side-pane-view "'places'"
ina_setting org.nemo.window-state start-with-sidebar true
ina_setting org.nemo.window-state start-with-toolbar true
ina_setting org.nemo.window-state start-with-location-bar true
css="$(cat <<EOF
/* Ina Nemo begin */
.nemo-window, .nemo-window .view { background-color: $INA_ABYSS; color: $INA_ANCIENT_PARCHMENT; }
.nemo-window .sidebar, .nemo-window .sidebar .view { background-color: $INA_DEEP_VIOLET; color: $INA_MUTED_TEXT; }
.nemo-window .view:selected, .nemo-window .sidebar .view:selected { background-color: $INA_DEEP_VIOLET; color: $INA_ANCIENT_PARCHMENT; border-color: $INA_TENTACLE_PURPLE; }
.nemo-window toolbar { background-image: none; background-color: $INA_DEEP_VIOLET; color: $INA_ANCIENT_PARCHMENT; }
.nemo-window entry:focus { border-color: $INA_ELDRITCH_TEAL; }
/* Ina Nemo end */
EOF
)"
ina_block "$INA_CONFIG/gtk-3.0/gtk.css" 'Ina Nemo' "$css"
ina_finish
