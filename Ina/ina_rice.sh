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
    grub-script-check /boot/grub/grub.cfg || fail "Generated GRUB configuration failed validation. Use the printed recovery and fallback commands. Backup: $state"
    printf '%s\n' 'No automatic restart. Boot rendering and recovery remain [unverified].'
}
# Archive only after restoration and configuration validation succeed. Keep every
# generation, including adopted originals, for manual recovery.
archive_boot_journal() {
    local state="$1" archive="$1.restored-$(date -u +%Y%m%dT%H%M%SZ)-$$"
    plain_path "$archive"
    [[ ! -e "$archive" && ! -L "$archive" ]] || fail "Backup destination already exists: $archive"
    mv -T --no-clobber -- "$state" "$archive" || fail "Could not archive boot backup: $state"
    [[ "$archive/lock" -ef "/proc/self/fd/$boot_lock" ]] || fail "Backup was not moved; inspect $state and $archive"
    printf 'Archived boot backup: %s\n' "$archive"
    printf 'Generated-menu fallback: sudo cp -p -- %q /boot/grub/grub.cfg\n' "$archive/grub.cfg.before"
    if [[ -f "$archive/adopted" ]]; then
        printf 'Adopted original theme: %s\nAdopted original override: %s\n' "$archive/original/theme" "$archive/original/90-ina.cfg"
    fi
}
# Privileged code is kept in this file. It owns only the fixed Ina destinations.
boot_operation() {
    ((EUID == 0)) || fail 'Internal boot operation requires root'
    need install cmp flock update-grub grub-script-check cp stat rmdir dirname rm mv date
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
        if [[ "$operation" == restore ]]; then archive_boot_journal "$state"; fi
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
    grub-script-check /boot/grub/grub.cfg || fail "Generated GRUB configuration failed validation. Use the printed recovery and fallback commands. Backup: $state"
    if [[ "$operation" == restore ]]; then
        archive_boot_journal "$state"
    fi
    printf '%s\n' 'No automatic restart. Boot rendering and recovery remain [unverified].'
}
if [[ "${1:-}" == --internal-grub ]]; then
    (($# >= 3 && $# <= 5)) || fail 'Invalid internal operation'
    [[ "$2" == --apply ]] || fail 'Internal boot changes require --apply'
    [[ "${5:-false}" == true || "${5:-false}" == false ]] || fail 'Invalid adoption flag'
    boot_operation "$3" "${4:-}" "${5:-false}"
    exit 0
fi
apply=false dry=false approved=false install_boot=false restore_boot=false adopt_boot=false grub_only=false enable_lock=false chrome=false skip_code=false skip_firefox=false
image='' grub_image='' settings='' profile='' asset_config=''; game=()
while (($#)); do
    case "$1" in
        --apply) apply=true; shift ;; --dry-run) dry=true; shift ;; --approved) approved=true; shift ;;
        --install-grub) install_boot=true; shift ;; --grub-only) grub_only=true; shift ;; --adopt-existing-grub) adopt_boot=true; shift ;; --restore-grub) restore_boot=true; shift ;;
        --enable-lock-rotation) enable_lock=true; shift ;;
        --user-chrome) chrome=true; shift ;; --skip-vscode) skip_code=true; shift ;; --skip-firefox) skip_firefox=true; shift ;;
        --desktop-image|--grub-image|--vscode-settings|--firefox-profile|--asset-config)
            (($# >= 2)) && [[ "$2" != --* && -n "$2" ]] || fail "Missing value for $1"
            case "$1" in --desktop-image) image="$2" ;; --grub-image) grub_image="$2" ;; --vscode-settings) settings="$2" ;; --firefox-profile) profile="$2" ;; --asset-config) asset_config="$2" ;; esac
            shift 2 ;;
        --) shift; game=("$@"); break ;;
        --help)
            cat <<'HELP'
Preview: bash Ina/ina.sh --dry-run [path choices]
Apply selected configuration: sudo bash Ina/ina.sh [path choices]
Missing or ambiguous image/application selections stop before desktop writes.
Apply all supported components: bash Ina/ina_rice.sh --apply --approved \
  --desktop-image PATH --vscode-settings PATH --firefox-profile PATH
Use --skip-vscode or --skip-firefox to explicitly omit an application.
Existing Ina assets/backup selections, Code settings and configured Firefox defaults
are reused when unambiguous. --asset-config PATH selects an existing image config.
Relative input paths resolve from this file, not the current directory.
Optional: --user-chrome, --install-grub, --adopt-existing-grub, or -- GAME ARGUMENTS.
Existing live lock rotation is retained; new activation requires --enable-lock-rotation.
For boot only: --grub-only --install-grub [--grub-image PATH] --approved --apply
GRUB preparation requires --grub-image, a configured grub_image, or --install-grub.
Only --install-grub activates GRUB using the privileged helper.
Sudo invocation: sudo --preserve-env=DISPLAY,XAUTHORITY,DBUS_SESSION_BUS_ADDRESS,XDG_RUNTIME_DIR,XDG_SESSION_TYPE,XDG_CURRENT_DESKTOP,XDG_CONFIG_HOME,XDG_DATA_HOME,XDG_STATE_HOME bash Ina/ina_rice.sh [options]
Restore boot files: sudo bash Ina/ina_rice.sh --restore-grub --apply
User backups: scripts/restore.sh --component NAME --apply
Use --enable-lock-rotation to lock active screensavers and rotate the ordered lock playlist.
Legacy installers and cursor-toggle.sh are excluded. No packages or restarts run.
Gaming mode runs only a command explicitly supplied after -- and restores on exit.
Runtime application, repeat runs, rollback and boot recovery are [unverified].
HELP
            exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done
"$dry" && apply=false
if "$adopt_boot" && ! "$install_boot"; then fail '--adopt-existing-grub requires --install-grub'; fi
if "$grub_only" && ! "$install_boot"; then fail '--grub-only requires --install-grub'; fi
if "$grub_only" && ((${#game[@]} > 0)); then fail '--grub-only cannot run a game'; fi
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
    entry="$(getent passwd "$target")" || fail 'Cannot resolve the sudo caller'
    IFS=: read -r account _ uid gid _ target_home _ <<< "$entry"
    [[ "$account" == "$target" && "$uid" =~ ^[0-9]+$ && "$uid" != 0 && "${SUDO_UID:-}" == "$uid" && "${SUDO_GID:-}" == "$gid" ]] || fail 'Sudo caller identity does not match the account database'
    plain_path "$target_home"
    [[ -d "$target_home" ]] || fail 'Sudo caller home is missing'
    # Plain sudo commonly removes session variables. Recover only the supported
    # desktop variables from an actual Cinnamon process belonging to this UID.
    if "$apply" && ! "$grub_only" && [[ "${XDG_SESSION_TYPE:-}" != x11 || "${XDG_CURRENT_DESKTOP:-}" != *Cinnamon* || -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        need stat
        session_keys=(DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR XDG_SESSION_TYPE XDG_CURRENT_DESKTOP XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME)
        session_values=()
        for process in /proc/[0-9]*; do
            [[ "$(stat -c %u -- "$process" 2>/dev/null)" == "$uid" ]] || continue
            IFS= read -r name < "$process/comm" 2>/dev/null || continue
            [[ "$name" == cinnamon ]] || continue
            candidate=()
            for index in "${!session_keys[@]}"; do candidate[index]=''; done
            while IFS= read -r -d '' field; do
                for index in "${!session_keys[@]}"; do
                    [[ "$field" == "${session_keys[index]}="* ]] || continue
                    value="${field#*=}"
                    [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || fail 'Multiline desktop environment refused'
                    candidate[index]="$value"
                    break
                done
            done < "$process/environ" || continue
            [[ "${candidate[4]}" == x11 && "${candidate[5]}" == *Cinnamon* && -n "${candidate[2]}" ]] || continue
            if ((${#session_values[@]})); then
                for index in "${!session_keys[@]}"; do
                    [[ "${candidate[index]}" == "${session_values[index]}" ]] || fail 'Multiple Cinnamon sessions; preserve the intended desktop environment'
                done
            else
                session_values=("${candidate[@]}")
            fi
        done
        ((${#session_values[@]})) || fail 'No Cinnamon X11 session found; preserve its environment as shown by --help'
        for index in "${!session_keys[@]}"; do
            key="${session_keys[$index]}"
            [[ -z "${session_values[$index]:-}" ]] || printf -v "$key" '%s' "${session_values[$index]}"
        done
    fi
    environment=("HOME=$target_home" "USER=$target" "LOGNAME=$target")
    for key in DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR XDG_SESSION_TYPE XDG_CURRENT_DESKTOP; do
        [[ -z "${!key:-}" ]] || environment+=("$key=${!key}")
    done
    for key in XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME; do
        if [[ -n "${!key:-}" ]]; then
            plain_path "${!key}"
            [[ "${!key}" == "$target_home/"* ]] || fail "$key must be beneath the sudo caller's home"
            environment+=("$key=${!key}")
        fi
    done
    if "$apply" && ! "$grub_only"; then
        [[ "${XDG_SESSION_TYPE:-}" == x11 && "${XDG_CURRENT_DESKTOP:-}" == *Cinnamon* && -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] || fail 'Preserve the Cinnamon environment using the sudo command shown by --help'
    fi
    # Rebuild arguments without shell evaluation. Desktop writes use this account.
    arguments=()
    if "$apply"; then arguments+=(--apply); else arguments+=(--dry-run); fi
    "$approved" && arguments+=(--approved); "$install_boot" && arguments+=(--install-grub); "$adopt_boot" && arguments+=(--adopt-existing-grub); "$grub_only" && arguments+=(--grub-only)
    "$enable_lock" && arguments+=(--enable-lock-rotation)
    "$chrome" && arguments+=(--user-chrome); "$skip_code" && arguments+=(--skip-vscode); "$skip_firefox" && arguments+=(--skip-firefox)
    [[ -z "$image" ]] || arguments+=(--desktop-image "$image")
    [[ -z "$grub_image" ]] || arguments+=(--grub-image "$grub_image")
    [[ -z "$settings" ]] || arguments+=(--vscode-settings "$settings")
    [[ -z "$profile" ]] || arguments+=(--firefox-profile "$profile")
    [[ -z "$asset_config" ]] || arguments+=(--asset-config "$asset_config")
    ((${#game[@]} == 0)) || arguments+=(-- "${game[@]}")
    # A preview must not start a privileged helper or run desktop components as root.
    if ! "$apply"; then
        printf 'Dry-run: desktop components would run as %s (uid %s), HOME=%s.\n' "$target" "$uid" "$target_home"
        printf 'Run this preview from that desktop account: bash %q' "$SELF"
        printf ' %q' "${arguments[@]}"; printf '\n'
        printf '%s\n' 'No sudo command, component, boot helper, or game was executed.'
        exit 0
    fi
    exec sudo -u "$target" -- env "${environment[@]}" bash "$SELF" "${arguments[@]}"
fi
resolve() { local path="$1"; [[ "$path" == /* ]] || path="$SELF_DIR/$path"; plain_path "$path"; realpath -m -- "$path"; }
[[ -z "$image" ]] || image="$(resolve "$image")"
[[ -z "$grub_image" ]] || grub_image="$(resolve "$grub_image")"
[[ -z "$settings" ]] || settings="$(resolve "$settings")"
[[ -z "$profile" ]] || profile="$(resolve "$profile")"
[[ -z "$asset_config" ]] || asset_config="$(resolve "$asset_config")"
# Reuse only recorded choices or unambiguous application configuration. This
# resolver reads existing files; it never creates a profile or chooses a random one.
need python3
approved_explicit="$approved"
selection_output="$(PYTHONDONTWRITEBYTECODE=1 python3 - "$asset_config" "$settings" "$profile" "$skip_code" "$skip_firefox" "$grub_only" <<'PYSELECT'
import configparser
import json
import os
from pathlib import Path
import sys

home = Path.home()
config = Path(os.environ.get('XDG_CONFIG_HOME', home / '.config'))
data = Path(os.environ.get('XDG_DATA_HOME', home / '.local/share'))
state = Path(os.environ.get('XDG_STATE_HOME', home / '.local/state')) / 'ina'

def read(path):
    path = Path(path)
    for part in (path, *path.parents):
        if part.is_symlink():
            raise ValueError(f'Symbolic link refused: {part}')
    if not path.exists():
        return {}
    result = json.loads(path.read_text())
    if not isinstance(result, dict):
        raise ValueError(f'Expected an object: {path}')
    return result

def text(value):
    if not isinstance(value, str) or any(c in value for c in ('\n', '\r', '\0')):
        raise ValueError('Configured selections must be single-line strings')
    return value

try:
    explicit, selected_code, selected_profile, skip_code, skip_firefox, grub_only = sys.argv[1:]
    desktop = grub_only != 'true'
    need_code = desktop and skip_code != 'true' and not selected_code
    need_profile = desktop and skip_firefox != 'true' and not selected_profile
    choices = [Path(explicit)] if explicit else [config / 'ina/assets.json', data / 'ina/lockscreen/assets.json']
    found = [path for path in choices if path.is_file()]
    if explicit and not found:
        raise ValueError(f'Asset configuration missing: {explicit}')
    if len(found) > 1:
        raise ValueError('Multiple Ina image configurations; choose --asset-config PATH')
    assets = read(found[0]) if found else {}
    lockscreen = read(state / 'backups/lockscreen/manifest.json') if desktop else {}
    code = text(assets.get('vscode_settings', '')) if need_code else ''
    if need_code and not code:
        vscode = read(state / 'backups/vscode/manifest.json')
        candidates = list(vscode.get('files', {}))
        if not candidates:
            candidates = [str(path) for path in (
                config / 'Code/User/settings.json', config / 'Code - OSS/User/settings.json',
                config / 'VSCodium/User/settings.json',
                home / '.var/app/com.visualstudio.code/config/Code/User/settings.json'
            ) if path.is_file()]
        if len(candidates) == 1:
            code = text(candidates[0])
    profile = text(assets.get('firefox_profile', '')) if need_profile else ''
    if need_profile and not profile:
        firefox = read(state / 'backups/firefox/manifest.json')
        profile = text(firefox.get('firefox', {}).get('profile', ''))
    if need_profile and not profile:
        defaults = set()
        roots = [home / '.mozilla/firefox', home / '.var/app/org.mozilla.firefox/.mozilla/firefox',
                 home / 'snap/firefox/common/.mozilla/firefox']
        for root in roots:
            for filename in ('installs.ini', 'profiles.ini'):
                ini = root / filename
                if not ini.is_file():
                    continue
                for part in (ini, *ini.parents):
                    if part.is_symlink():
                        raise ValueError(f'Symbolic link refused: {part}')
                parser = configparser.ConfigParser(interpolation=None)
                parser.read(ini)
                for section in parser.values():
                    path = ''
                    if 'Default' in section and section['Default'] not in ('0', '1'):
                        path = section['Default']
                    elif section.get('Default') == '1' and section.get('Path'):
                        path = section['Path']
                    if path:
                        target = Path(path)
                        defaults.add(str(target if target.is_absolute() else root / target))
        if len(defaults) == 1:
            profile = text(defaults.pop())
    values = [str(found[0]) if found else '', text(assets.get('desktop_image', '')),
              text(assets.get('grub_image', '')), code, profile,
              'true' if assets.get('approved') is True else 'false',
              'true' if assets.get('force_lock_on_activation') is True or lockscreen.get('service_managed') is True else 'false',
              'true' if isinstance(assets.get('lock_images'), list) and 3 <= len(assets['lock_images']) <= 8 and all(isinstance(p, str) and p for p in assets['lock_images']) else 'false']
    for value in values:
        print(value)
except (OSError, ValueError, KeyError, TypeError, configparser.Error) as exc:
    print(f'Error resolving existing Ina selections: {exc}', file=sys.stderr)
    sys.exit(1)
PYSELECT
)" || fail 'Existing selections could not be read; no component was run'
mapfile -t selections <<< "$selection_output"
asset_config="${selections[0]}"
[[ -n "$image" || -z "${selections[1]}" ]] || image="$(resolve "${selections[1]}")"
[[ -n "$grub_image" || -z "${selections[2]}" ]] || grub_image="$(resolve "${selections[2]}")"
[[ -n "$settings" || -z "${selections[3]}" ]] || settings="$(resolve "${selections[3]}")"
[[ -n "$profile" || -z "${selections[4]}" ]] || profile="$(resolve "${selections[4]}")"
if "${selections[5]}" && ! "$approved"; then
    # A recorded approval applies only to the images in that configuration.
    configured_desktop='' configured_grub=''
    [[ -z "${selections[1]}" ]] || configured_desktop="$(resolve "${selections[1]}")"
    [[ -z "${selections[2]}" ]] || configured_grub="$(resolve "${selections[2]}")"
    if [[ "$image" == "$configured_desktop" && "$grub_image" == "$configured_grub" ]]; then approved=true; fi
fi
if ! "$grub_only" && "${selections[6]}"; then enable_lock=true; fi
local_lock_images="${selections[7]}"
if "$apply"; then
    "$approved" || fail 'Applying images requires --approved or approved:true in the selected asset configuration'
    if "$install_boot" && [[ -z "$grub_image" ]] && ! "$approved_explicit"; then
        fail 'Downloading the configured GRUB source requires explicit --approved, or select an approved grub_image in the asset configuration'
    fi
    if ! "$grub_only" && ! "$local_lock_images" && ! "$approved_explicit"; then
        fail 'Preparing missing lock images requires explicit --approved, or select 3 to 8 previously approved lock_images'
    fi
    if ! "$grub_only"; then
        [[ -n "$image" && -f "$image" ]] || fail 'Select an existing independent --desktop-image PATH'
        "$skip_code" || [[ -n "$settings" ]] || fail 'Select --vscode-settings PATH or --skip-vscode'
        "$skip_firefox" || [[ -n "$profile" && -d "$profile" ]] || fail 'Select --firefox-profile PATH or --skip-firefox'
    fi
fi
components=(icons cursor window-controls widgets taskbar nemo animations wallpaper vscode firefox lockscreen)
if "$install_boot" || [[ -n "$grub_image" ]]; then components+=(grub); fi
"$grub_only" && components=(grub)
if "$grub_only" && "$enable_lock"; then fail '--grub-only cannot enable lock rotation'; fi
args_for() {
    args=()
    case "$1" in
        icons|cursor|window-controls|widgets|taskbar|nemo|animations|wallpaper|gaming-mode) args+=(--apply-desktop) ;;
    esac
    case "$1" in
        widgets) args+=(--widgets clock calendar system) ;;
        wallpaper) [[ -z "$image" ]] || args+=(--image "$image"); args+=(--approved) ;;
        vscode) [[ -z "$settings" ]] || args+=(--settings "$settings") ;;
        firefox) [[ -z "$profile" ]] || args+=(--profile "$profile"); "$chrome" && args+=(--user-chrome) ;;
        lockscreen)
            if "$local_lock_images"; then
                args+=(--asset-config "$asset_config" --approved)
                if "$enable_lock"; then args+=(--force-lock-on-activation --apply-desktop); fi
            else
                args+=(--download-images --approved)
            fi
            [[ -z "$image" ]] || args+=(--image "$image") ;;
        grub) args+=(--allow-boot-change --approved); if [[ -n "$grub_image" ]]; then args+=(--image "$grub_image"); else args+=(--download-images); fi ;;
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
if "$install_boot" && "$apply"; then need sudo; fi
# dconf's read client may create a runtime cache. Confine it to disposable
# scratch space while retaining the real user's configuration and session bus.
if ! "$apply"; then
    need mktemp rm
    preview_runtime="$(mktemp -d "${TMPDIR:-/tmp}/ina-preview-runtime-XXXXXXXX")"
    trap 'rm -rf -- "$preview_runtime"' EXIT
    export XDG_RUNTIME_DIR="$preview_runtime"
fi
printf '%s\n' 'Excluded: legacy installers, cursor-toggle.sh, all music widgets, and restore/install helper entry points.'
for component in "${selected[@]}"; do
    args_for "$component"
    if [[ "$component" == lockscreen ]] && "$local_lock_images" && ! "$enable_lock"; then
        printf '%s\n' 'Lock images already configured; live rotation requires --enable-lock-rotation.'
        continue
    fi
    printf 'Previewing %s\n' "$component"
    bash "$SCRIPTS/$component.sh" "${args[@]}" --dry-run
done
if "$enable_lock"; then printf '%s\n' 'Live lock rotation selected: active screensavers will be explicitly locked. The configured playlist rotates every 300 seconds.'; fi
if "$apply"; then
    for component in "${selected[@]}"; do
        args_for "$component"
        if [[ "$component" == lockscreen ]] && "$local_lock_images" && ! "$enable_lock"; then continue; fi
        printf 'Applying %s. Recovery: bash %q --component %q --apply\n' "$component" "$SCRIPTS/restore.sh" "$component"
        [[ "$component" != lockscreen ]] || printf 'Download recovery: bash %q --component lockscreen-images --apply\n' "$SCRIPTS/restore.sh"
        bash "$SCRIPTS/$component.sh" "${args[@]}" --apply
    done
    if "$enable_lock" && ! "$grub_only" && ! "$local_lock_images"; then
        lock_config="${XDG_DATA_HOME:-$HOME/.local/share}/ina/lockscreen/assets.json"
        bash "$SCRIPTS/lockscreen.sh" --asset-config "$lock_config" --approved --force-lock-on-activation --apply-desktop --dry-run
        bash "$SCRIPTS/lockscreen.sh" --asset-config "$lock_config" --approved --force-lock-on-activation --apply-desktop --apply
    fi
    if "$install_boot"; then
        prepared="${XDG_DATA_HOME:-$HOME/.local/share}/ina/grub"
        sudo bash "$SELF" --internal-grub --apply install "$prepared" "$adopt_boot"
    fi
fi
if ((${#game[@]} > 0)); then
    mode=--dry-run; "$apply" && mode=--apply
    bash "$SCRIPTS/gaming-mode.sh" "$mode" --apply-desktop -- "${game[@]}"
else printf '%s\n' 'Gaming mode omitted: supply a command after -- to run it.'; fi
