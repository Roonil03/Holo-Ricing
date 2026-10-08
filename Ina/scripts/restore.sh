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
    source "$SCRIPT_DIR/../dotfiles/colors.sh"
    PYTHONDONTWRITEBYTECODE=1 exec python3 "$SCRIPT_DIR/lib/engine.py" "${args[@]}"
fi
ina_begin
# Restoring does not need a running Cinnamon session or the application opt-in.
ina_restore_records
if ! "$INA_DRY" && [[ "$INA_COMPONENT" == gaming-mode ]]; then
    INA_JSON="$(jq '.gaming_active=false' <<< "$INA_JSON")"; ina_save
fi
ina_finish
