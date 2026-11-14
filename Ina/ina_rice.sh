#!/usr/bin/env bash
set -euo pipefail
# Original MIT code. Paths to components are relative to this file.
SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SELF_DIR/ina_rice.sh"
SCRIPTS="$SELF_DIR/scripts"
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need() { local c; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || fail "Required command missing: $c"; done; }
plain_path() {
    local p="$1" ancestor
    [[ "$p" == /* && "$p" != *$'\n'* ]] || fail "Expected an absolute single-line path: $p"
    ancestor="$p"
    while [[ "$ancestor" != / ]]; do
        [[ ! -L "$ancestor" ]] || fail "Symbolic link refused: $ancestor"
        ancestor="$(dirname -- "$ancestor")"
    done
}
# Only the known Ina files may be adopted. Preserve their complete original
# tree under the root-owned journal before touching boot destinations.
adopted_boot() {
    local operation="$1" source_dir="$2" state="$3" path file original expected entry
    local -a new=(theme.txt background.jpg LICENSE NOTICE selected_c.png selected_e.png selected_w.png 90-ina.cfg)
    local -a all=(theme.txt background.jpg LICENSE NOTICE selected_c.png selected_e.png selected_w.png selectors/selected_c.png selectors/selected_e.png selectors/selected_w.png 90-ina.cfg)
    local theme=/boot/grub/themes/ina override=/etc/default/grub.d/90-ina.cfg
    # Reject unknown entries and symlinks, including hidden entries.
    if [[ -e "$theme" ]]; then
        [[ -d "$theme" && ! -L "$theme" ]] || fail 'Invalid existing Ina theme directory'
        for entry in "$theme"/* "$theme"/.[!.]* "$theme"/..?*; do
            [[ -e "$entry" || -L "$entry" ]] || continue
            case "${entry##*/}" in
                theme.txt|background.jpg|LICENSE|NOTICE|selected_c.png|selected_e.png|selected_w.png) [[ -f "$entry" && ! -L "$entry" ]] || fail "Invalid theme file: $entry" ;;
                selectors)
                    [[ -d "$entry" && ! -L "$entry" ]] || fail "Invalid selectors directory: $entry"
                    for path in "$entry"/* "$entry"/.[!.]* "$entry"/..?*; do
                        [[ -e "$path" || -L "$path" ]] || continue
                        case "${path##*/}" in selected_c.png|selected_e.png|selected_w.png) [[ -f "$path" && ! -L "$path" ]] || fail "Invalid selector: $path" ;; *) fail "Unknown selector: $path" ;; esac
                    done ;;
                *) fail "Unknown theme entry: $entry" ;;
            esac
        done
    fi
    if [[ ! -f "$state/ready" ]]; then
        [[ "$operation" == install && -d "$theme" && -f "$override" && ! -L "$override" ]] || fail 'Adoption requires the existing Ina theme and override'
        [[ ! -e "$state/original" && ! -e "$state/files" && ! -e "$state/grub.cfg.before" && ! -e "$state/adopted" ]] || fail 'Incomplete boot journal; preserve it for manual recovery'
        cmp -s -- "$override" <(printf '%s\n' '# Original Ina override. Loaded after /etc/default/grub.' "GRUB_THEME='/boot/grub/themes/ina/theme.txt'") || fail 'Existing GRUB override is not the expected Ina override'
        plain_path "$source_dir"
        for file in "${new[@]}"; do plain_path "$source_dir/$file"; [[ -f "$source_dir/$file" ]] || fail "Prepared file missing: $file"; done
        cmp -s -- "$source_dir/90-ina.cfg" "$override" || fail 'Unexpected prepared override'
        cp -p -- /boot/grub/grub.cfg "$state/grub.cfg.before"
        install -d -m 700 "$state/files" "$state/original"
        cp -a -- "$theme" "$state/original/theme"
        cp -p -- "$override" "$state/original/90-ina.cfg"
        for file in "${new[@]}"; do install -m 600 "$source_dir/$file" "$state/files/$file"; done
        printf '%s\n' 'adopted' > "$state/adopted"
        printf '%s\n' 'Original Ina files retained in original/.' > "$state/ready"
    fi
    [[ -f "$state/adopted" && -f "$state/ready" ]] || fail 'Incomplete adoption journal; preserve it for manual recovery'
    if [[ "$operation" == install ]]; then
        for file in "${new[@]}"; do plain_path "$source_dir/$file"; cmp -s -- "$source_dir/$file" "$state/files/$file" || fail "Prepared theme differs from journal: $file"; done
    else [[ "$operation" == restore ]] || fail 'Invalid boot operation'; fi
    for file in "${all[@]}"; do
        path="$theme/$file"; original="$state/original/theme/$file"
        if [[ "$file" == 90-ina.cfg ]]; then path="$override"; original="$state/original/90-ina.cfg"; fi
        plain_path "$path"; plain_path "$original"
        [[ -e "$path" ]] || continue
        [[ -f "$path" ]] || fail "Invalid boot file: $path"
        expected="$state/files/$file"
        if [[ -f "$expected" ]] && cmp -s -- "$path" "$expected" && [[ "$(stat -c '%u:%a' -- "$path")" == 0:644 ]]; then continue; fi
        if [[ -f "$original" ]] && cmp -s -- "$path" "$original" && [[ "$(stat -c '%u:%g:%a' -- "$path")" == "$(stat -c '%u:%g:%a' -- "$original")" ]]; then continue; fi
        fail "Boot file changed outside this runner: $path"
    done
    printf 'Boot backup: %s\nRecovery: sudo bash %q --restore-grub --apply\n' "$state" "$SELF"
    printf 'Generated-menu fallback: sudo cp -p -- %q /boot/grub/grub.cfg\n' "$state/grub.cfg.before"
    for file in "${all[@]}"; do
        path="$theme/$file"; [[ "$file" != 90-ina.cfg ]] || path="$override"
        [[ ! -f "$path" ]] || rm -- "$path"
    done
    [[ ! -d "$theme/selectors" ]] || rmdir -- "$theme/selectors"
    [[ ! -d "$theme" ]] || rmdir -- "$theme"
    if [[ "$operation" == install ]]; then
        install -d -m 755 "$theme" /etc/default/grub.d
        for file in "${new[@]}"; do path="$theme/$file"; [[ "$file" != 90-ina.cfg ]] || path="$override"; install -m 644 "$state/files/$file" "$path"; done
    else
        cp -a -- "$state/original/theme" "$theme"
        cp -p -- "$state/original/90-ina.cfg" "$override"
    fi
    update-grub || fail "update-grub failed. Use the printed recovery and fallback commands. Backup: $state"
    printf '%s\n' 'No automatic restart. Boot rendering and recovery remain [unverified].'
}
# Privileged code is kept in this file. It owns only the fixed Ina destinations.
boot_operation() {
    ((EUID == 0)) || fail 'Internal boot operation requires root'
    need install cmp flock update-grub cp stat rmdir dirname rm
    local operation="$1" source_dir="${2:-}" adopt="${3:-false}" state=/var/lib/ina-rice-grub file destination
    local -a names=(theme.txt background.jpg LICENSE NOTICE selected_c.png selected_e.png selected_w.png 90-ina.cfg)
    plain_path "$state"; plain_path /boot/grub/themes/ina; plain_path /etc/default/grub.d/90-ina.cfg
    [[ -d /boot/grub && -f /boot/grub/grub.cfg ]] || fail 'Expected /boot/grub/grub.cfg; no boot file was changed'
    plain_path /boot/grub/grub.cfg
    if [[ ! -d "$state" ]]; then
        [[ "$operation" == install ]] || { printf '%s\n' 'No runner GRUB backup exists.'; return; }
        [[ "$adopt" == true || ( ! -e /boot/grub/themes/ina && ! -e /etc/default/grub.d/90-ina.cfg ) ]] || fail 'Existing Ina boot destinations require explicit --adopt-existing-grub; nothing was overwritten'
        install -d -m 700 "$state"
    fi
    [[ "$(stat -c '%u:%a' -- "$state")" == 0:700 ]] || fail 'GRUB state must belong to root with mode 700'
    plain_path "$state/lock"
    exec {boot_lock}>"$state/lock"
    flock -n "$boot_lock" || fail 'Another runner boot operation is active'
    if [[ -f "$state/adopted" || ( "$adopt" == true && ! -f "$state/ready" ) ]]; then
        adopted_boot "$operation" "$source_dir" "$state"
        return
    fi
    # Older journals used a selectors subdirectory. Restore them using the
    # original paths before installing the revised layout.
    if [[ -f "$state/ready" && -f "$state/files/selectors/selected_c.png" ]]; then
        [[ "$operation" == restore ]] || fail 'Previous GRUB layout detected. Restore it before installing the revised theme.'
        names=(theme.txt background.jpg LICENSE NOTICE selectors/selected_c.png selectors/selected_e.png selectors/selected_w.png 90-ina.cfg)
    fi
    if [[ "$operation" == install ]]; then
        plain_path "$source_dir"
        [[ -d "$source_dir" ]] || fail 'Prepared GRUB directory missing'
        for file in "${names[@]}"; do
            plain_path "$source_dir/$file"
            [[ -f "$source_dir/$file" ]] || fail "Prepared file missing: $file"
        done
        cmp -s -- "$source_dir/90-ina.cfg" <(printf '%s\n' '# Original Ina override. Loaded after /etc/default/grub.' "GRUB_THEME='/boot/grub/themes/ina/theme.txt'") || fail 'Unexpected GRUB override content'
        if [[ ! -f "$state/ready" ]]; then
            [[ ! -e /boot/grub/themes/ina && ! -e /etc/default/grub.d/90-ina.cfg ]] || fail 'Boot destinations exist without a completed journal'
            # Snapshot generated boot configuration before any update-grub call.
            cp -p -- /boot/grub/grub.cfg "$state/grub.cfg.before"
            install -d -m 700 "$state/files"
            for file in "${names[@]}"; do install -m 600 "$source_dir/$file" "$state/files/$file"; done
            [[ -d /etc/default/grub.d ]] || printf '%s\n' absent > "$state/default-dir.before"
            printf '%s\n' 'Original Ina files: absent. Original generated menu: grub.cfg.before.' > "$state/ready"
        fi
        for file in "${names[@]}"; do cmp -s -- "$source_dir/$file" "$state/files/$file" || fail "Prepared theme differs from journal: $file. Restore the previous installation first."; done
    else
        [[ "$operation" == restore && -f "$state/ready" ]] || fail 'Incomplete or invalid boot journal; preserve it for manual recovery'
    fi
    # Check every file before changing any. Ignore only missing owned files.
    for file in "${names[@]}"; do
        destination="/boot/grub/themes/ina/$file"
        [[ "$file" != 90-ina.cfg ]] || destination=/etc/default/grub.d/90-ina.cfg
        plain_path "$destination"; plain_path "$state/files/$file"
        [[ -f "$state/files/$file" ]] || fail "Journal file missing: $file"
        if [[ -e "$destination" ]]; then
            [[ -f "$destination" ]] && cmp -s -- "$destination" "$state/files/$file" || fail "Boot file changed outside this runner: $destination"
            [[ "$(stat -c '%u:%a' -- "$destination")" == 0:644 ]] || fail "Boot file ownership or permissions changed: $destination"
        fi
    done
    printf 'Boot backup: %s\nRecovery: sudo bash %q --restore-grub --apply\n' "$state" "$SELF"
    printf 'Generated-menu fallback: sudo cp -p -- %q /boot/grub/grub.cfg\n' "$state/grub.cfg.before"
    if [[ "$operation" == install ]]; then
        install -d -m 755 /boot/grub/themes/ina /etc/default/grub.d
    fi
    for file in "${names[@]}"; do
        destination="/boot/grub/themes/ina/$file"
        [[ "$file" != 90-ina.cfg ]] || destination=/etc/default/grub.d/90-ina.cfg
        if [[ "$operation" == install ]]; then
            if [[ ! -e "$destination" ]]; then install -m 644 "$state/files/$file" "$destination"; fi
        elif [[ -f "$destination" ]]; then rm -- "$destination"; fi
    done
    if [[ "$operation" == restore ]]; then
        for destination in /boot/grub/themes/ina/selectors /boot/grub/themes/ina; do
            [[ ! -d "$destination" ]] || rmdir --ignore-fail-on-non-empty -- "$destination"
        done
        if [[ -f "$state/default-dir.before" && -d /etc/default/grub.d ]]; then rmdir --ignore-fail-on-non-empty -- /etc/default/grub.d; fi
    fi
    update-grub || fail "update-grub failed. Use the printed recovery and fallback commands. Backup: $state"
    printf '%s\n' 'No automatic restart. Boot rendering and recovery remain [unverified].'
}
if [[ "${1:-}" == --internal-grub ]]; then
    (($# >= 3 && $# <= 5)) || fail 'Invalid internal operation'
    [[ "$2" == --apply ]] || fail 'Internal boot changes require --apply'
    [[ "${5:-false}" == true || "${5:-false}" == false ]] || fail 'Invalid adoption flag'
    boot_operation "$3" "${4:-}" "${5:-false}"
    exit 0
fi
apply=false dry=false approved=false install_boot=false restore_boot=false adopt_boot=false chrome=false skip_code=false skip_firefox=false
image='' settings='' profile=''; game=()
while (($#)); do
    case "$1" in
        --apply) apply=true; shift ;; --dry-run) dry=true; shift ;; --approved) approved=true; shift ;;
        --install-grub) install_boot=true; shift ;; --adopt-existing-grub) adopt_boot=true; shift ;; --restore-grub) restore_boot=true; shift ;;
        --user-chrome) chrome=true; shift ;; --skip-vscode) skip_code=true; shift ;; --skip-firefox) skip_firefox=true; shift ;;
        --desktop-image|--vscode-settings|--firefox-profile)
            (($# >= 2)) && [[ "$2" != --* && -n "$2" ]] || fail "Missing value for $1"
            case "$1" in --desktop-image) image="$2" ;; --vscode-settings) settings="$2" ;; --firefox-profile) profile="$2" ;; esac
            shift 2 ;;
        --) shift; game=("$@"); break ;;
        --help)
            cat <<'HELP'
Preview: bash Ina/ina_rice.sh --dry-run [path choices]
Apply all supported components: bash Ina/ina_rice.sh --apply --approved \
  --desktop-image PATH --vscode-settings PATH --firefox-profile PATH
Use --skip-vscode or --skip-firefox to explicitly omit an application.
Relative input paths resolve from this file, not the current directory.
Optional: --user-chrome, --install-grub, --adopt-existing-grub, or -- GAME ARGUMENTS.
GRUB activation uses sudo only with --install-grub. Preparation runs otherwise.
Sudo invocation: sudo --preserve-env=DISPLAY,XAUTHORITY,DBUS_SESSION_BUS_ADDRESS,XDG_RUNTIME_DIR,XDG_SESSION_TYPE,XDG_CURRENT_DESKTOP,XDG_CONFIG_HOME,XDG_DATA_HOME,XDG_STATE_HOME bash Ina/ina_rice.sh [options]
Restore boot files: sudo bash Ina/ina_rice.sh --restore-grub --apply
User backups: scripts/restore.sh --component NAME --apply
Existing scripts are unchanged. Legacy scripts, missing cursor.sh, live lock
rotation and unavailable media are excluded. No packages or restarts run.
Gaming mode runs only a command explicitly supplied after -- and restores on exit.
Runtime application, repeat runs, rollback and boot recovery are [unverified].
HELP
            exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done
"$dry" && apply=false
if "$adopt_boot" && ! "$install_boot"; then fail '--adopt-existing-grub requires --install-grub'; fi
need bash realpath dirname
if "$restore_boot"; then
    if ! "$apply"; then printf 'Would restore runner-owned boot files using sudo bash %q --restore-grub --apply\n' "$SELF"; exit 0; fi
    if ((EUID == 0)); then boot_operation restore; else need sudo; sudo bash "$SELF" --internal-grub --apply restore; fi
    exit 0
fi
if ((EUID == 0)); then
    target="${SUDO_USER:-}"
    [[ -n "$target" && "$target" != root ]] || fail 'Run through sudo from your Cinnamon account, or run without sudo'
    need sudo getent env
    entry="$(getent passwd "$target")"; IFS=: read -r _ _ uid _ _ target_home _ <<< "$entry"
    environment=("HOME=$target_home" "USER=$target" "LOGNAME=$target")
    for key in DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR XDG_SESSION_TYPE XDG_CURRENT_DESKTOP XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME; do
        [[ -z "${!key:-}" ]] || environment+=("$key=${!key}")
    done
    if "$apply"; then
        [[ "${XDG_SESSION_TYPE:-}" == x11 && "${XDG_CURRENT_DESKTOP:-}" == *Cinnamon* && -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] || fail 'Preserve the Cinnamon environment using the sudo command shown by --help'
    fi
    # Rebuild arguments without shell evaluation. Desktop writes use this account.
    arguments=()
    if "$apply"; then arguments+=(--apply); else arguments+=(--dry-run); fi
    "$approved" && arguments+=(--approved); "$install_boot" && arguments+=(--install-grub); "$adopt_boot" && arguments+=(--adopt-existing-grub)
    "$chrome" && arguments+=(--user-chrome); "$skip_code" && arguments+=(--skip-vscode); "$skip_firefox" && arguments+=(--skip-firefox)
    [[ -z "$image" ]] || arguments+=(--desktop-image "$image")
    [[ -z "$settings" ]] || arguments+=(--vscode-settings "$settings")
    [[ -z "$profile" ]] || arguments+=(--firefox-profile "$profile")
    ((${#game[@]} == 0)) || arguments+=(-- "${game[@]}")
    exec sudo -u "$target" -- env "${environment[@]}" bash "$SELF" "${arguments[@]}"
fi
resolve() { local path="$1"; [[ "$path" == /* ]] || path="$SELF_DIR/$path"; plain_path "$path"; realpath -m -- "$path"; }
[[ -z "$image" ]] || image="$(resolve "$image")"
[[ -z "$settings" ]] || settings="$(resolve "$settings")"
[[ -z "$profile" ]] || profile="$(resolve "$profile")"
if "$apply"; then
    "$approved" || fail 'Applying images requires --approved'
    [[ -n "$image" && -f "$image" ]] || fail 'Select an existing independent --desktop-image PATH'
    "$skip_code" || [[ -n "$settings" ]] || fail 'Select --vscode-settings PATH or --skip-vscode'
    "$skip_firefox" || [[ -n "$profile" && -d "$profile" ]] || fail 'Select --firefox-profile PATH or --skip-firefox'
fi
components=(icons window-controls widgets taskbar nemo animations wallpaper vscode firefox lockscreen grub)
args_for() {
    args=()
    case "$1" in
        icons|window-controls|widgets|taskbar|nemo|animations|wallpaper|gaming-mode) args+=(--apply-desktop) ;;
    esac
    case "$1" in
        widgets) args+=(--widgets clock calendar system) ;;
        wallpaper) [[ -z "$image" ]] || args+=(--image "$image"); args+=(--approved) ;;
        vscode) [[ -z "$settings" ]] || args+=(--settings "$settings") ;;
        firefox) [[ -z "$profile" ]] || args+=(--profile "$profile"); "$chrome" && args+=(--user-chrome) ;;
        lockscreen) args+=(--download-images --approved); [[ -z "$image" ]] || args+=(--image "$image") ;;
        grub) args+=(--allow-boot-change --download-images --approved) ;;
    esac
    return 0
}
selected=()
for component in "${components[@]}"; do
    [[ "$component" != vscode ]] || ! "$skip_code" || continue
    [[ "$component" != firefox ]] || ! "$skip_firefox" || continue
    [[ -f "$SCRIPTS/$component.sh" && ! -L "$SCRIPTS/$component.sh" ]] || fail "Component missing or linked: $component"
    selected+=("$component")
done
if "$install_boot"; then need sudo; fi
printf '%s\n' 'Excluded: older scripts, missing cursor.sh, live lock rotation, Soundbox, and restore/install helper entry points.'
for component in "${selected[@]}"; do
    args_for "$component"
    printf 'Previewing %s\n' "$component"
    bash "$SCRIPTS/$component.sh" "${args[@]}" --dry-run
done
if "$apply"; then
    for component in "${selected[@]}"; do
        args_for "$component"
        printf 'Applying %s. Recovery: bash %q --component %q --apply\n' "$component" "$SCRIPTS/restore.sh" "$component"
        [[ "$component" != lockscreen ]] || printf 'Download recovery: bash %q --component lockscreen-images --apply\n' "$SCRIPTS/restore.sh"
        bash "$SCRIPTS/$component.sh" "${args[@]}" --apply
    done
    if "$install_boot"; then
        prepared="${XDG_DATA_HOME:-$HOME/.local/share}/ina/grub"
        sudo bash "$SELF" --internal-grub --apply install "$prepared" "$adopt_boot"
    fi
fi
if ((${#game[@]} > 0)); then
    mode=--dry-run; "$apply" && mode=--apply
    bash "$SCRIPTS/gaming-mode.sh" "$mode" --apply-desktop -- "${game[@]}"
else printf '%s\n' 'Gaming mode omitted: supply a command after -- to run it.'; fi
