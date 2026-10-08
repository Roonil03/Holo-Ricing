#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init cursor "$@"
ina_desktop
[[ -f /usr/share/icons/DMZ-White/index.theme && -f /usr/share/doc/dmz-cursor-theme/copyright ]] ||
    ina_error 'Install dmz-cursor-theme manually before selecting DMZ-White'
grep -q 'Attribution-ShareAlike 3.0' /usr/share/doc/dmz-cursor-theme/copyright ||
    ina_error 'Installed cursor license could not be verified'
gtk="$(ina_user_path "$INA_CONFIG/gtk-3.0/settings.ini")"
[[ ! -e "$gtk" || -f "$gtk" ]] || ina_error "Not a regular file: $gtk"
text=''
[[ ! -f "$gtk" ]] || text="$(cat -- "$gtk")"
# Preserve unrelated INI lines. Refuse duplicate Settings sections.
text="$(awk '
    BEGIN {inside=0; seen=0}
    /^\[Settings\][[:space:]]*$/ {if (seen++) exit 2; inside=1; print; next}
    /^\[/ {if (inside) {print "gtk-cursor-theme-name=DMZ-White"; print "gtk-cursor-theme-size=32"}; inside=0}
    inside && /^[[:space:]]*gtk-cursor-theme-(name|size)[[:space:]]*=/ {next}
    {print}
    END {
        if (seen>1) exit 2
        if (!seen) print "[Settings]"
        if (inside || !seen) {print "gtk-cursor-theme-name=DMZ-White"; print "gtk-cursor-theme-size=32"}
    }
' <<< "$text")" || ina_error 'Duplicate or unsupported GTK Settings sections'
xresources="$(ina_user_path "$INA_HOME/.Xresources")"
[[ ! -e "$xresources" || -f "$xresources" ]] || ina_error "Not a regular file: $xresources"
xtext=''
[[ ! -f "$xresources" ]] || xtext="$(sed '/^Xcursor\.\(theme\|size\):/d' "$xresources")"
ina_begin
ina_text "$gtk" "$text"$'\n'
ina_text "$xresources" "${xtext:+$xtext$'\n'}Xcursor.theme: DMZ-White"$'\nXcursor.size: 32\n'
ina_setting org.cinnamon.desktop.interface cursor-theme "'DMZ-White'"
ina_setting org.cinnamon.desktop.interface cursor-size 32
printf '%s\n' 'No live xrdb merge or login-screen cursor change. Reopen GTK applications; Xresources needs a new login.'
ina_finish
