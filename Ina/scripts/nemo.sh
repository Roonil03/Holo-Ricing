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
/* Nemo desktop windows inherit nemo-window; keep wallpaper and desktop labels theme-controlled. */
.nemo-window:not(.nemo-desktop-window), .nemo-window:not(.nemo-desktop-window) .view { background-color: $INA_ABYSS; color: $INA_ANCIENT_PARCHMENT; }
.nemo-window:not(.nemo-desktop-window) .sidebar, .nemo-window:not(.nemo-desktop-window) .sidebar .view { background-color: $INA_DEEP_VIOLET; color: $INA_MUTED_TEXT; }
/* Cover icon canvas and list selections, including unfocused windows. */
.nemo-window:not(.nemo-desktop-window) .view:selected,
.nemo-window:not(.nemo-desktop-window) .view:selected:focus,
.nemo-window:not(.nemo-desktop-window) .view:selected:backdrop,
.nemo-window:not(.nemo-desktop-window) .nemo-canvas-item:selected,
.nemo-window:not(.nemo-desktop-window) .nemo-canvas-item:selected:focus,
.nemo-window:not(.nemo-desktop-window) .nemo-canvas-item:selected:backdrop,
.nemo-window:not(.nemo-desktop-window) .sidebar .view:selected { background-image: none; background-color: $INA_ANCIENT_PARCHMENT; color: $INA_INK; border-color: $INA_ANCIENT_PARCHMENT; }
.nemo-window:not(.nemo-desktop-window) rubberband,
.nemo-window:not(.nemo-desktop-window) .rubberband { background-color: alpha($INA_ANCIENT_PARCHMENT, 0.25); border: 1px solid $INA_ANCIENT_PARCHMENT; }
.nemo-window:not(.nemo-desktop-window) toolbar { background-image: none; background-color: $INA_DEEP_VIOLET; color: $INA_ANCIENT_PARCHMENT; }
.nemo-window:not(.nemo-desktop-window) entry:focus { border-color: $INA_ELDRITCH_TEAL; }
/* Ina Nemo end */
EOF
)"
ina_block "$INA_CONFIG/gtk-3.0/gtk.css" 'Ina Nemo' "$css"
ina_finish
