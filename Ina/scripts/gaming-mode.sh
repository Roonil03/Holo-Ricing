#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init gaming-mode "$@"
ina_desktop
if [[ -n "$INA_POWER" ]]; then
    [[ "$INA_POWER" =~ ^(power-saver|balanced|performance)$ ]] || ina_error 'Unsupported power profile'
    [[ -z "$INA_TEST" ]] || ina_error 'Optional power profiles are disabled in --test-root mode'
    ina_need powerprofilesctl
    grep -qE "^[[:space:]*]*$INA_POWER:" < <(powerprofilesctl list) || ina_error 'Requested power profile is unavailable'
fi
printf 'Chosen command:'; printf ' %q' "${INA_COMMAND[@]}"; printf '\n'
if ! "$INA_DRY"; then
    (("${#INA_COMMAND[@]}" > 0)) || ina_error 'Supply a command after --'
    ina_need setsid sleep kill
    command -v "${INA_COMMAND[0]}" >/dev/null 2>&1 || ina_error 'Chosen command is unavailable'
fi
ina_begin
if ! "$INA_DRY"; then
    jq -e '.gaming_active != true' <<< "$INA_JSON" >/dev/null || ina_error 'An interrupted gaming run requires restore before another run'
    # Retain the prior run journal before starting a fresh snapshot.
    if [[ -f "$INA_MANIFEST" ]]; then
        archive="$INA_BACKUP/run-$(date -u +%Y%m%dT%H%M%S)-$$.json"
        ina_atomic "$archive" "$(ina_b64 "$INA_JSON")" 600
    fi
    INA_JSON="$(jq '.settings={} | .files={} | .power=null | .gaming_active=true' <<< "$INA_JSON")"
    ina_save
    if [[ -n "$INA_POWER" ]]; then
        original_power="$(powerprofilesctl get)"
        INA_JSON="$(jq --arg o "$original_power" --arg a "$INA_POWER" '.power={original:$o,applied:$a}' <<< "$INA_JSON")"
        ina_save
    fi
fi
ina_setting org.cinnamon.desktop.notifications display-notifications false
ina_setting org.cinnamon desktop-effects false
ina_setting org.cinnamon desktop-effects-workspace false
if "$INA_DRY"; then
    printf '%s\n' 'Preview only. No command or power-profile change.'
    ina_finish
    exit 0
fi
[[ -z "$INA_POWER" ]] || powerprofilesctl set "$INA_POWER"
child=''
game_cleanup() {
    local status="$1" attempt
    trap - EXIT INT TERM HUP
    if [[ -n "$child" ]] && kill -0 "$child" 2>/dev/null; then
        kill -TERM -- "-$child" 2>/dev/null || true
        for ((attempt=0; attempt<50; attempt++)); do
            kill -0 "$child" 2>/dev/null || break
            sleep 0.1
        done
        kill -KILL -- "-$child" 2>/dev/null || true
        wait "$child" 2>/dev/null || true
    fi
    # Restoration errors preserve the active journal and print recovery.
    local restore_status
    set +e
    ( set -euo pipefail; ina_restore_records )
    restore_status="$?"
    set -e
    if ((restore_status == 0)); then
        INA_JSON="$(jq '.gaming_active=false' <<< "$INA_JSON")"
        ina_save
    else
        printf 'Restoration failed. Run: bash %q --component gaming-mode --apply\n' "$SCRIPT_DIR/restore.sh" >&2
        [[ "$status" != 0 ]] || status=1
    fi
    ina_finish
    exit "$status"
}
trap 'game_cleanup "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
# Job control stays disabled so setsid can use the child's PID as its session ID.
set +m
(
    exec {INA_LOCK_FD}>&-
    exec setsid --wait -- "${INA_COMMAND[@]}"
) &
child="$!"
status=0
wait "$child" || status="$?"
exit "$status"
