#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init neofetch "$@"
ina_need neofetch
art="$(sed 's/^/${c1}/; s/:/${c2}:${c1}/g' "$SCRIPT_DIR/../dotfiles/tako-ascii-neofetch.txt")"
config="$(cat <<'CONFIG'
print_info() {
    info title
    info underline
    info "OS" distro
    info "Host" model
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "Resolution" resolution
    info "DE" de
    info "WM" wm
    info "WM Theme" wm_theme
    info "Theme" theme
    info "Icons" icons
    info "Font" font
    info "Cursor" cursor
    info "Terminal" term
    info "Terminal Font" term_font
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory
    info "Swap" swap
    info "Disk" disk
    info "Local IP" local_ip
    info "Battery" battery
    info "Locale" locale
    prin "" "\e[33mIna Ina Ina, Ina Ina!\e[0m"
}
image_backend="ascii"
image_source=__INA_IMAGE_PATH__
ascii_distro="auto"
ascii_colors=(5 3)
ascii_bold="on"
gap=2
colors=(5 5 5 5 5 7)
CONFIG
)"
# The config is a shell script: quote the chosen path as a shell literal.
printf -v image_path '%q' "$INA_CONFIG/neofetch/tako-ascii.txt"
config="${config%%__INA_IMAGE_PATH__*}${image_path}${config#*__INA_IMAGE_PATH__}"
ina_begin
ina_text "$INA_CONFIG/neofetch/config.conf" "$config"$'\n'
ina_text "$INA_CONFIG/neofetch/tako-ascii.txt" "$art"$'\n'
ina_finish
printf '%s\n' 'Neofetch configured. Run neofetch manually.'
