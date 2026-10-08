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
# Privileged code is kept in this file. It owns only the fixed Ina destinations.
boot_operation() {
    ((EUID == 0)) || fail 'Internal boot operation requires root'
    need install cmp flock update-grub cp stat rmdir dirname rm
    local operation="$1" source_dir="${2:-}" state=/var/lib/ina-rice-grub file destination changed=false
    local -a names=(theme.txt background.jpg LICENSE NOTICE selectors/selected_c.png selectors/selected_e.png selectors/selected_w.png 90-ina.cfg)
    plain_path "$state"; plain_path /boot/grub/themes/ina; plain_path /etc/default/grub.d/90-ina.cfg
    [[ -d /boot/grub && -f /boot/grub/grub.cfg ]] || fail 'Expected /boot/grub/grub.cfg; no boot file was changed'
    plain_path /boot/grub/grub.cfg
    if [[ ! -d "$state" ]]; then
        [[ "$operation" == install ]] || { printf '%s\n' 'No runner GRUB backup exists.'; return; }
        [[ ! -e /boot/grub/themes/ina && ! -e /etc/default/grub.d/90-ina.cfg ]] || fail 'Existing Ina boot destinations require manual inspection; nothing was overwritten'
        install -d -m 700 "$state"
    fi
    [[ "$(stat -c '%u:%a' -- "$state")" == 0:700 ]] || fail 'GRUB state must belong to root with mode 700'
    plain_path "$state/lock"
    exec {boot_lock}>"$state/lock"
    flock -n "$boot_lock" || fail 'Another runner boot operation is active'
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
            install -d -m 700 "$state/files/selectors"
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
        install -d -m 755 /boot/grub/themes/ina/selectors /etc/default/grub.d
    fi
    for file in "${names[@]}"; do
        destination="/boot/grub/themes/ina/$file"
        [[ "$file" != 90-ina.cfg ]] || destination=/etc/default/grub.d/90-ina.cfg
        if [[ "$operation" == install ]]; then
            if [[ ! -e "$destination" ]]; then install -m 644 "$state/files/$file" "$destination"; changed=true; fi
        elif [[ -f "$destination" ]]; then rm -- "$destination"; changed=true; fi
    done
    if [[ "$operation" == restore ]]; then
        for destination in /boot/grub/themes/ina/selectors /boot/grub/themes/ina; do
            [[ ! -d "$destination" ]] || rmdir --ignore-fail-on-non-empty -- "$destination"
        done
        if [[ -f "$state/default-dir.before" && -d /etc/default/grub.d ]]; then rmdir --ignore-fail-on-non-empty -- /etc/default/grub.d; fi
    fi
    if "$changed"; then update-grub || fail "update-grub failed. Use the printed recovery and fallback commands. Backup: $state"; fi
    printf '%s\n' 'No automatic restart. Boot rendering and recovery remain [unverified].'
}
if [[ "${1:-}" == --internal-grub ]]; then
    (($# == 3 || $# == 4)) || fail 'Invalid internal operation'
    [[ "$2" == --apply ]] || fail 'Internal boot changes require --apply'
    boot_operation "$3" "${4:-}"
    exit 0
fi
apply=false dry=false approved=false install_boot=false restore_boot=false chrome=false skip_code=false skip_firefox=false
image='' settings='' profile=''; game=()
while (($#)); do
    case "$1" in
        --apply) apply=true; shift ;; --dry-run) dry=true; shift ;; --approved) approved=true; shift ;;
        --install-grub) install_boot=true; shift ;; --restore-grub) restore_boot=true; shift ;;
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
Optional: --user-chrome, --install-grub, or -- GAME ARGUMENTS.
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
    "$approved" && arguments+=(--approved); "$install_boot" && arguments+=(--install-grub)
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
        sudo bash "$SELF" --internal-grub --apply install "$prepared"
    fi
fi
if ((${#game[@]} > 0)); then
    mode=--dry-run; "$apply" && mode=--apply
    bash "$SCRIPTS/gaming-mode.sh" "$mode" --apply-desktop -- "${game[@]}"
else printf '%s\n' 'Gaming mode omitted: supply a command after -- to run it.'; fi
