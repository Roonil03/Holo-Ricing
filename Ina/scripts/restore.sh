#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init restore "$@"
if [[ -z "$INA_RESTORE" ]]; then
    if [[ -d "$INA_STATE/backups" ]]; then
        for directory in "$INA_STATE/backups/"*; do [[ ! -d "$directory" ]] || printf '%s\n' "${directory##*/}"; done
    else printf '%s\n' 'No backups.'; fi
    exit 0
fi
[[ "$INA_RESTORE" =~ ^[a-z][a-z-]*$ ]] || ina_error 'Invalid backup component'
INA_COMPONENT="$INA_RESTORE" INA_BACKUP="$INA_STATE/backups/$INA_RESTORE"
INA_MANIFEST="$INA_BACKUP/manifest.json"
ina_path "$INA_MANIFEST" >/dev/null
if [[ ! -f "$INA_MANIFEST" ]]; then printf 'No active backup for %s.\n' "$INA_COMPONENT"; exit 0; fi
if [[ "$(jq -r '.format // ""' "$INA_MANIFEST")" != ina-bash-1 ]]; then
    # Existing Python journals remain readable, including the retained editors.
    ina_need python3
    args=(restore --component "$INA_COMPONENT")
    [[ -z "$INA_TEST" ]] || args+=(--test-root "$INA_TEST")
    if "$INA_DRY"; then args+=(--dry-run); else args+=(--apply); fi
    case "$INA_COMPONENT" in
        vscode|firefox|lockscreen) ;;
        *) args+=(--archive-backup) ;;
    esac
    managed=false
    if [[ "$INA_COMPONENT" == lockscreen ]] && jq -e '.service_managed == true' "$INA_MANIFEST" >/dev/null; then
        managed=true
        printf '%s\n' 'Stop and disable ina-lockscreen.service before restoring files and settings.'
        if ! "$INA_DRY" && [[ -z "$INA_TEST" ]]; then
            # Check owned files before invoking a service whose executable and unit
            # are among those files. Preserve external edits instead of running them.
            while IFS= read -r path; do
                path="$(ina_user_path "$path")"
                [[ ! -e "$path" || -f "$path" ]] || ina_error "Not a regular file: $path"
                entry="$(jq --arg p "$path" '.files[$p]' "$INA_MANIFEST")"
                current='null'
                [[ ! -f "$path" ]] || current="$(base64 -w0 -- "$path" | jq -Rs .)"
                [[ "$current" == "$(jq -c '.original' <<< "$entry")" || "$current" == "$(jq -c '.applied' <<< "$entry")" ]] || ina_error "File changed externally: $path"
            done < <(jq -r '.files|keys[]' "$INA_MANIFEST")
            ina_need systemctl
            unit_path="$INA_CONFIG/systemd/user/ina-lockscreen.service"
            if [[ -f "$unit_path" ]] || systemctl --user is-active --quiet ina-lockscreen.service; then
                systemctl --user disable --now ina-lockscreen.service || ina_error 'Could not stop and disable lockscreen service'
            fi
            live_lock="$INA_STATE/lock-rotation-live.lock"
            ina_path "$live_lock" >/dev/null
            if [[ -e "$live_lock" ]]; then
                [[ -f "$live_lock" && "$(stat -c '%u:%a:%h:%s' -- "$live_lock")" == "$EUID:600:1:0" ]] || ina_error 'Invalid rotation lock file'
                exec {INA_LIVE_LOCK_FD}<>"$live_lock"
                flock -n "$INA_LIVE_LOCK_FD" || ina_error 'Another lockscreen worker is running'
            fi
        fi
    fi
    source "$SCRIPT_DIR/../dotfiles/colors.sh"
    PYTHONDONTWRITEBYTECODE=1 python3 "$SCRIPT_DIR/lib/engine.py" "${args[@]}"
    if "$managed" && ! "$INA_DRY" && [[ -z "$INA_TEST" ]]; then systemctl --user daemon-reload; fi
    exit 0
fi
ina_begin
# Restoring does not need a running Cinnamon session or the application opt-in.
ina_restore_records
if ! "$INA_DRY" && [[ "$INA_COMPONENT" == gaming-mode ]]; then
    INA_JSON="$(jq '.gaming_active=false' <<< "$INA_JSON")"; ina_save
fi
ina_finish
