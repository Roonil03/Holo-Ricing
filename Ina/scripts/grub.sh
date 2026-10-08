#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init grub "$@"
if ! "$INA_DRY"; then "$INA_BOOT" || ina_error 'GRUB preparation requires --apply --allow-boot-change'; fi
prepared="$INA_DATA/ina/grub"
theme="$(cat <<EOF
# Original text-only Ina GRUB theme. No artwork or font files.
title-text: "Boot menu"
title-color: "$INA_ANCIENT_PARCHMENT"
desktop-color: "$INA_ABYSS"
terminal-box: ""
+ boot_menu {
  left = 15%
  top = 25%
  width = 70%
  height = 50%
  item_color = "$INA_MUTED_TEXT"
  selected_item_color = "$INA_ELDRITCH_TEAL"
  item_height = 36
  item_padding = 8
  item_spacing = 8
}
EOF
)"
ina_begin
ina_text "$prepared/theme.txt" "$theme"$'\n' 644
ina_text "$prepared/90-ina.cfg" $'# Original Ina override. Loaded after /etc/default/grub.\nGRUB_THEME=\'/boot/grub/themes/ina/theme.txt\'\n' 644
printf '%s\n' 'User files only. Test with grub-emu in a disposable environment before activating.' \
    'Rendered theme and real boot recovery remain [unverified]. Manual activation requires unused destinations:'
printf '%s\n' 'test ! -e /boot/grub/themes/ina && test ! -e /etc/default/grub.d/90-ina.cfg' \
    'sudo install -d -m 755 /boot/grub/themes/ina /etc/default/grub.d'
printf 'sudo install -m 644 %q /boot/grub/themes/ina/theme.txt\n' "$prepared/theme.txt"
printf 'sudo install -m 644 %q /etc/default/grub.d/90-ina.cfg\n' "$prepared/90-ina.cfg"
printf '%s\n' 'sudo update-grub' 'Recovery after installing those exact files:' \
    'sudo rm -- /etc/default/grub.d/90-ina.cfg /boot/grub/themes/ina/theme.txt' \
    'sudo rmdir -- /boot/grub/themes/ina' 'sudo update-grub' \
    'At the GRUB prompt: set theme=, then Esc. This recovery procedure is [unverified]. No automatic restart.'
ina_finish
