#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init cursor "$@"
ina_desktop
theme=/usr/share/icons/DMZ-White
notice=/usr/share/doc/dmz-cursor-theme/copyright
[[ -f "$theme/index.theme" && -e "$theme/cursors/left_ptr" && -f "$notice" ]] || ina_error 'Install dmz-cursor-theme manually before selecting DMZ-White'
grep -q 'Creative Commons Attribution-ShareAlike 3.0' "$notice" || ina_error 'Installed cursor license could not be verified'
settings="$(ina_user_path "$INA_CONFIG/gtk-3.0/settings.ini")"
[[ ! -e "$settings" || -f "$settings" ]] || ina_error "Not a regular file: $settings"
# Preserve all unrelated GTK settings and reject ambiguous duplicate sections/keys.
content="$(awk '
    function finish() {
        if (!theme_seen) print "gtk-cursor-theme-name=DMZ-White"
        if (!size_seen) print "gtk-cursor-theme-size=32"
    }
    /^\[[^]]+\][[:space:]]*$/ {
        if (inside) finish()
        inside=($0 ~ /^\[Settings\][[:space:]]*$/)
        if (inside && ++sections > 1) { print "Duplicate GTK Settings section" > "/dev/stderr"; exit 1 }
        print; next
    }
    inside && /^[[:space:]]*gtk-cursor-theme-name[[:space:]]*=/ {
        if (++theme_seen > 1) { print "Duplicate GTK cursor theme setting" > "/dev/stderr"; exit 1 }
        print "gtk-cursor-theme-name=DMZ-White"; next
    }
    inside && /^[[:space:]]*gtk-cursor-theme-size[[:space:]]*=/ {
        if (++size_seen > 1) { print "Duplicate GTK cursor size setting" > "/dev/stderr"; exit 1 }
        print "gtk-cursor-theme-size=32"; next
    }
    { print }
    END {
        if (sections > 1 || theme_seen > 1 || size_seen > 1) exit 1
        if (inside) finish()
        if (!sections) { if (NR) print ""; print "[Settings]"; finish() }
    }
' "${settings:-/dev/null}" 2>/dev/null)" || {
    # A nonexistent file is treated as an empty configuration.
    if [[ -e "$settings" ]]; then ina_error 'Invalid or unreadable GTK settings'; fi
    content=$'[Settings]\ngtk-cursor-theme-name=DMZ-White\ngtk-cursor-theme-size=32'
}
ina_begin
ina_text "$settings" "$content"$'\n'
ina_setting org.cinnamon.desktop.interface cursor-theme "'DMZ-White'"
ina_setting org.cinnamon.desktop.interface cursor-size 32
ina_finish
printf '%s\n' 'DMZ-White selected for Cinnamon and GTK 3. Reopen applications if needed.'
