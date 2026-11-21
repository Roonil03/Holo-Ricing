#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init window-controls "$@"
ina_desktop
source_theme=/usr/share/themes/Mint-Y/metacity-1
notice=/usr/share/doc/mint-themes/copyright
[[ -f "$source_theme/metacity-theme-3.xml" && -f "$notice" ]] || ina_error 'Installed Mint-Y window theme and copyright notice are required'
grep -q 'License: GPL-3+' "$notice" || ina_error 'Installed Mint theme license could not be verified'
names=(C_title_focused C_title_unfocused C_wm_bg C_wm_bg_unfocused C_wm_border C_wm_border_unfocused C_wm_highlight C_button_close_bg_focused C_button_close_bg_hover C_button_close_bg_active C_icon_close_bg C_button_bg_hover C_button_bg_active C_icon_bg_focused C_icon_bg_unfocused C_icon_bg_hover C_icon_bg_active)
colours=("$INA_ANCIENT_PARCHMENT" "$INA_MUTED_TEXT" "$INA_DEEP_VIOLET" "$INA_ABYSS" "$INA_ELDRITCH_TEAL" "$INA_TENTACLE_PURPLE" "$INA_LAVENDER" "$INA_WARNING_ACCENT" "$INA_SOFT_PEACH" "$INA_LAVENDER" "$INA_INK" "$INA_TENTACLE_PURPLE" "$INA_DEEP_VIOLET" "$INA_ANCIENT_PARCHMENT" "$INA_MUTED_TEXT" "$INA_ANCIENT_PARCHMENT" "$INA_ELDRITCH_TEAL")
# Validate and recolour in one pass instead of starting grep and sed for every
# constant. Keep the source formatting so the generated theme stays unchanged.
xml="$(awk -v names="${names[*]}" -v colours="${colours[*]}" '
    BEGIN {
        count = split(names, name, " ")
        split(colours, colour, " ")
        for (i = 1; i <= count; i++) {
            marker[i] = "<constant name=\"" name[i] "\" value="
            prefix[i] = marker[i] "\""
        }
    }
    {
        if (index($0, "<constant name=")) {
            for (i = 1; i <= count; i++) {
                if (!index($0, marker[i])) continue
                seen[i]++
                if (match($0, prefix[i] "[^\"]*\"[[:space:]]*/>")) {
                    value_start = RSTART + length(prefix[i])
                    rest = substr($0, value_start)
                    sub(/^[^"]*/, colour[i], rest)
                    $0 = substr($0, 1, value_start - 1) rest
                }
            }
        }
        print
    }
    END {
        for (i = 1; i <= count; i++) {
            if (seen[i] != 1) {
                print "Error: Unsupported Mint constant: " name[i] > "/dev/stderr"
                exit 1
            }
        }
    }
' "$source_theme/metacity-theme-3.xml")"
mapfile -t images < <(grep -oE '<image filename="[^"]+"' "$source_theme/metacity-theme-3.xml" | sed 's/^<image filename="//;s/"$//' | sort -u)
for image in "${images[@]}"; do
    [[ "$image" =~ ^[a-zA-Z0-9_-]+\.svg$ && -f "$source_theme/$image" ]] || ina_error "Unexpected or missing Mint artwork: $image"
done
css="$(cat <<EOF
/* Ina window controls begin */
@define-color wm_title $INA_ANCIENT_PARCHMENT;
@define-color wm_title_unfocused $INA_MUTED_TEXT;
@define-color wm_bg $INA_DEEP_VIOLET;
@define-color wm_bg_unfocused $INA_ABYSS;
headerbar { background-image: none; background-color: $INA_DEEP_VIOLET; color: $INA_ANCIENT_PARCHMENT; border-color: $INA_ELDRITCH_TEAL; }
headerbar:backdrop { background-color: $INA_ABYSS; color: $INA_MUTED_TEXT; border-color: $INA_TENTACLE_PURPLE; }
/* Muffin renders symbolic controls through GTK, independently of the XML above.
 * Limit this to the headerbars made dark here; keep light custom titlebars intact.
 * Restore uses the maximize button class. */
headerbar button.titlebutton.minimize:not(:disabled),
headerbar button.titlebutton.maximize:not(:disabled) {
    color: $INA_ANCIENT_PARCHMENT;
}
headerbar button.titlebutton.minimize:not(:disabled):hover,
headerbar button.titlebutton.maximize:not(:disabled):hover {
    color: $INA_ANCIENT_PARCHMENT;
    background-image: -gtk-gradient(radial, center center, 0, center center, 0.5, to($INA_TENTACLE_PURPLE), to(transparent));
}
headerbar button.titlebutton.minimize:not(:disabled):active,
headerbar button.titlebutton.maximize:not(:disabled):active {
    color: $INA_ANCIENT_PARCHMENT;
    background-image: -gtk-gradient(radial, center center, 0, center center, 0.5, to($INA_DEEP_VIOLET), to(transparent));
}
decoration { box-shadow: 0 3px 8px alpha($INA_INK, 0.35); }
/* Ina window controls end */
EOF
)"
ina_begin
target="$INA_DATA/themes/Ina-Windows/metacity-1"
for image in "${images[@]}"; do ina_copy "$source_theme/$image" "$target/$image"; done
ina_text "$target/metacity-theme-3.xml" "$xml"$'\n' 644
ina_copy "$notice" "$INA_DATA/themes/Ina-Windows/COPYRIGHT"
ina_block "$INA_CONFIG/gtk-3.0/gtk.css" 'Ina window controls' "$css"
ina_setting org.cinnamon.desktop.wm.preferences theme "'Ina-Windows'"
ina_setting org.cinnamon.desktop.wm.preferences button-layout "':minimize,maximize,close'"
printf '%s\n' 'GTK 4 and application-drawn controls may ignore these overrides [unverified].'
ina_finish
ina_refresh_window_controls
