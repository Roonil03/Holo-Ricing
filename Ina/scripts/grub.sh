#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
source "$SCRIPT_DIR/lib/images.sh"
ina_init grub "$@"
if ! "$INA_DRY"; then
    "$INA_BOOT" || ina_error 'GRUB preparation requires --apply --allow-boot-change'
    "$INA_APPROVED" || ina_error 'Image use requires --approved after checking the source permissions'
fi
prepared="$INA_DATA/ina/grub"
vendor="$SCRIPT_DIR/../vendor/grub-evangelion"
ina_image_source grub
if [[ -n "$INA_IMAGE" ]]; then
    "$INA_APPROVED" || ina_error 'A local GRUB image requires --image PATH --approved'
    image="$(ina_path "$INA_IMAGE")"
    ina_jpeg "$image"
else
    image=''
    if ! "$INA_DRY"; then
        "$INA_DOWNLOAD" || ina_error 'Select --download-images to fetch the configured image, or --image PATH for an approved local JPEG'
    fi
fi
theme="$(sed -e "s/@ABYSS@/$INA_ABYSS/g" -e "s/@PARCHMENT@/$INA_ANCIENT_PARCHMENT/g" \
    -e "s/@TEAL@/$INA_ELDRITCH_TEAL/g" "$vendor/theme.txt.in")"
ina_begin
if [[ -n "$image" ]]; then
    ina_copy "$image" "$prepared/background.jpg" 644
else
    ina_download_image "$prepared/background.jpg"
fi
ina_text "$prepared/theme.txt" "$theme"$'\n' 644
ina_text "$prepared/90-ina.cfg" $'# Original Ina override. Loaded after /etc/default/grub.\nGRUB_THEME=\'/boot/grub/themes/ina/theme.txt\'\n' 644
for name in selected_c.png selected_e.png selected_w.png; do
    ina_copy "$vendor/selectors/$name" "$prepared/selectors/$name" 644
done
ina_copy "$vendor/LICENSE" "$prepared/LICENSE" 644
ina_copy "$vendor/NOTICE" "$prepared/NOTICE" 644
printf '%s\n' 'User files only. Preview at the intended resolution with grub-emu or a disposable VM.' \
    'Check text contrast, long menu entries, selection, and JPEG support before activation.' \
    'Rendered theme and real boot recovery remain [unverified]. Manual activation requires unused destinations:' \
    'test ! -e /boot/grub/themes/ina && test ! -e /etc/default/grub.d/90-ina.cfg' \
    'Stop if that check fails. Preserve any existing files instead of overwriting them.' \
    'sudo install -d -m 755 /boot/grub/themes/ina/selectors /etc/default/grub.d'
for name in theme.txt background.jpg LICENSE NOTICE; do
    printf 'sudo install -m 644 %q %q\n' "$prepared/$name" "/boot/grub/themes/ina/$name"
done
for name in selected_c.png selected_e.png selected_w.png; do
    printf 'sudo install -m 644 %q %q\n' "$prepared/selectors/$name" "/boot/grub/themes/ina/selectors/$name"
done
printf 'sudo install -m 644 %q /etc/default/grub.d/90-ina.cfg\n' "$prepared/90-ina.cfg"
printf '%s\n' 'sudo update-grub' 'Recovery after installing those exact files:' \
    'sudo rm -- /etc/default/grub.d/90-ina.cfg /boot/grub/themes/ina/theme.txt /boot/grub/themes/ina/background.jpg /boot/grub/themes/ina/LICENSE /boot/grub/themes/ina/NOTICE' \
    'sudo rm -- /boot/grub/themes/ina/selectors/selected_c.png /boot/grub/themes/ina/selectors/selected_e.png /boot/grub/themes/ina/selectors/selected_w.png' \
    'sudo rmdir -- /boot/grub/themes/ina/selectors /boot/grub/themes/ina' 'sudo update-grub' \
    'At the GRUB prompt: set theme=, then Esc. This recovery procedure is [unverified]. No automatic restart.'
ina_finish
