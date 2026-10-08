#!/usr/bin/env bash
set -euo pipefail
# Original MIT code. Shared Bash backup and restore handling.
ina_error() { printf 'Error: %s\n' "$*" >&2; exit 1; }
ina_need() {
    local name
    for name in "$@"; do command -v "$name" >/dev/null 2>&1 || ina_error "Required command missing: $name"; done
}
ina_path() {
    local candidate="$1" current
    [[ "$candidate" == /* && "$candidate" != *$'\n'* ]] || ina_error "Expected an absolute single-line path: $candidate"
    current="$candidate"
    while [[ "$current" != / ]]; do
        [[ ! -L "$current" ]] || ina_error "Refusing symbolic link: $current"
        current="$(dirname -- "$current")"
    done
    realpath -m -- "$candidate"
}
ina_user_path() {
    local path
    path="$(ina_path "$1")"
    [[ "$path" == "$INA_HOME/"* ]] || ina_error "Only files beneath $INA_HOME may be changed: $path"
    printf '%s' "$path"
}
ina_init() {
    INA_COMPONENT="$1"; shift
    INA_APPLY=false INA_DRY=true INA_DESKTOP=false INA_APPROVED=false INA_BOOT=false INA_EXPLICIT_DRY=false
    INA_IMAGE='' INA_ASSETS='' INA_TEST='' INA_RESTORE='' INA_POWER='' INA_SETTINGS='' INA_PROFILE='' INA_CHROME=false
    INA_COMPONENTS=() INA_WIDGETS=() INA_COMMAND=()
    while (($#)); do
        case "$1" in
            --apply) INA_APPLY=true; shift ;;
            --dry-run) INA_EXPLICIT_DRY=true; shift ;;
            --apply-desktop) INA_DESKTOP=true; shift ;;
            --approved) INA_APPROVED=true; shift ;;
            --allow-boot-change) INA_BOOT=true; shift ;;
            --user-chrome) INA_CHROME=true; shift ;;
            --image|--asset-config|--test-root|--component|--power-profile|--settings|--profile)
                (($# >= 2)) && [[ "$2" != --* && -n "$2" ]] || ina_error "Missing value for $1"
                case "$1" in
                    --image) INA_IMAGE="$2" ;; --asset-config) INA_ASSETS="$2" ;;
                    --test-root) INA_TEST="$2" ;; --component) INA_RESTORE="$2" ;;
                    --power-profile) INA_POWER="$2" ;; --settings) INA_SETTINGS="$2" ;;
                    --profile) INA_PROFILE="$2" ;;
                esac
                shift 2 ;;
            --components|--widgets)
                local list="$1"; shift
                (($#)) && [[ "$1" != --* ]] || ina_error "Missing selection for $list"
                while (($#)) && [[ "$1" != --* ]]; do
                    if [[ "$list" == --components ]]; then INA_COMPONENTS+=("$1"); else INA_WIDGETS+=("$1"); fi
                    shift
                done ;;
            --) shift; INA_COMMAND=("$@"); break ;;
            --help)
                printf '%s\n' 'Preview: --dry-run. Apply: --apply. Desktop opt-in: --apply-desktop.' \
                    'Choices: --image PATH --approved, --widgets NAME..., --components NAME...,' \
                    '--allow-boot-change, --settings PATH, --profile PATH, --power-profile NAME, -- COMMAND.'
                exit 0 ;;
            *) ina_error "Unsupported argument: $1" ;;
        esac
    done
    [[ "$INA_COMPONENT" =~ ^[a-z][a-z-]*$ ]] || ina_error 'Invalid component name'
    if "$INA_APPLY" && ! "$INA_EXPLICIT_DRY"; then INA_DRY=false; fi
    ina_need jq realpath dirname base64 stat mktemp mv cp chmod mkdir rm flock awk sed grep cmp cat tr sort date rmdir
    INA_HOME="$(ina_path "$HOME")"
    INA_CONFIG="$(ina_path "${XDG_CONFIG_HOME:-$INA_HOME/.config}")"
    INA_DATA="$(ina_path "${XDG_DATA_HOME:-$INA_HOME/.local/share}")"
    INA_STATE="$(ina_path "${XDG_STATE_HOME:-$INA_HOME/.local/state}/ina")"
    if [[ -n "$INA_TEST" ]]; then
        INA_TEST="$(ina_path "$INA_TEST")"
        [[ "$INA_TEST" == /tmp/* && -d "$INA_TEST" ]] || ina_error '--test-root must be an existing real directory beneath /tmp'
        INA_HOME="$INA_TEST/home" INA_CONFIG="$INA_TEST/home/.config"
        INA_DATA="$INA_TEST/home/.local/share" INA_STATE="$INA_TEST/state"
    fi
    ina_user_path "$INA_CONFIG" >/dev/null; ina_user_path "$INA_DATA" >/dev/null
    [[ -n "$INA_TEST" ]] || ina_user_path "$INA_STATE" >/dev/null
    INA_BACKUP="$INA_STATE/backups/$INA_COMPONENT" INA_MANIFEST="$INA_STATE/backups/$INA_COMPONENT/manifest.json"
    if [[ -n "$INA_ASSETS" ]]; then
        INA_ASSETS="$(ina_path "$INA_ASSETS")"
        [[ -f "$INA_ASSETS" ]] || ina_error "Asset configuration missing: $INA_ASSETS"
        jq -e 'type == "object" and ((.desktop_image // "") | type == "string")' "$INA_ASSETS" >/dev/null
        [[ -n "$INA_IMAGE" ]] || INA_IMAGE="$(jq -r '.desktop_image // ""' "$INA_ASSETS")"
    fi
    INA_FINISHED=false
    source "$SCRIPT_DIR/../dotfiles/colors.sh"
}
ina_desktop() {
    ina_need gsettings
    if ! "$INA_DRY" && [[ -z "$INA_TEST" ]]; then
        "$INA_DESKTOP" || ina_error 'Desktop changes require --apply --apply-desktop'
        ((EUID != 0)) || ina_error 'Run as your desktop user, not root'
        ina_need cinnamon
        [[ -f /etc/linuxmint/info ]] && grep -qx 'RELEASE=22.3' /etc/linuxmint/info || ina_error 'Requires Linux Mint 22.3'
        [[ "$(cinnamon --version)" == 'Cinnamon 6.6.9' ]] || ina_error 'Requires Cinnamon 6.6.9'
        [[ "${XDG_CURRENT_DESKTOP:-}" == *Cinnamon* && "${XDG_SESSION_TYPE:-}" == x11 ]] || ina_error 'Requires Cinnamon on X11'
    fi
}
ina_b64() { printf '%s' "$1" | base64 -w0; }
ina_atomic() {
    local path="$1" bytes="$2" mode="${3:-600}" temporary
    ina_path "$path" >/dev/null
    [[ ! -e "$path" || -f "$path" ]] || ina_error "Not a regular file: $path"
    mkdir -p -- "$(dirname -- "$path")"
    temporary="$(mktemp "$(dirname -- "$path")/.ina-XXXXXX")"
    if ! printf '%s' "$bytes" | base64 --decode > "$temporary"; then rm -- "$temporary"; ina_error 'Invalid backup encoding'; fi
    chmod "$mode" "$temporary"
    mv -fT -- "$temporary" "$path"
}
ina_save() { ina_atomic "$INA_MANIFEST" "$(ina_b64 "$INA_JSON")" 600; }
ina_track_dirs() {
    local directory
    directory="$(dirname -- "$1")"
    while [[ "$directory" != "$INA_HOME" && ! -d "$directory" ]]; do
        ina_user_path "$directory" >/dev/null
        [[ ! -e "$directory" ]] || ina_error "Not a directory: $directory"
        INA_JSON="$(jq --arg d "$directory" '.directories=((.directories // []) + [$d] | unique)' <<< "$INA_JSON")"
        directory="$(dirname -- "$directory")"
    done
}
ina_load() {
    ina_path "$INA_MANIFEST" >/dev/null
    if [[ -f "$INA_MANIFEST" ]]; then
        INA_JSON="$(cat -- "$INA_MANIFEST")"
        jq -e --arg c "$INA_COMPONENT" '.component == $c and .format == "ina-bash-1" and (.files|type == "object") and (.settings|type == "object")' <<< "$INA_JSON" >/dev/null ||
            ina_error 'Older or invalid backup. Restore it with restore.sh before applying this Bash component.'
    else INA_JSON="$(jq -n --arg c "$INA_COMPONENT" '{format:"ina-bash-1",component:$c,files:{},settings:{}}')"; fi
}
ina_begin() {
    printf 'Backup: %s\nRecovery: bash %q --component %q --apply\n' "$INA_MANIFEST" "$SCRIPT_DIR/restore.sh" "$INA_COMPONENT"
    printf 'Text-console recovery: dbus-run-session -- bash %q --component %q --apply\n' "$SCRIPT_DIR/restore.sh" "$INA_COMPONENT"
    if "$INA_DRY"; then ina_load; return; fi
    ((EUID != 0)) || ina_error 'Run as your desktop user, not root'
    umask 077
    ina_path "$INA_STATE" >/dev/null
    mkdir -p -- "$INA_STATE"; chmod 700 "$INA_STATE"
    ina_path "$INA_STATE/transaction.lock" >/dev/null
    exec {INA_LOCK_FD}>"$INA_STATE/transaction.lock"
    flock -n "$INA_LOCK_FD" || ina_error 'Another Ina operation is running'
    ina_load
    trap 'ina_exit "$?"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP
}
ina_exit() {
    local status="$1"
    trap - EXIT INT TERM HUP
    if ! "$INA_FINISHED" && [[ -f "$INA_MANIFEST" ]]; then
        printf '%s\n' 'Operation interrupted. Attempting restoration from the saved backup.' >&2
        local restore_status
        set +e
        ( set -euo pipefail; ina_restore_records )
        restore_status="$?"
        set -e
        if ((restore_status != 0)); then
            printf 'Automatic restoration failed. Use: bash %q --component %q --apply\n' "$SCRIPT_DIR/restore.sh" "$INA_COMPONENT" >&2
            [[ "$status" != 0 ]] || status=1
        fi
    fi
    exit "$status"
}
ina_finish() { INA_FINISHED=true; }
ina_get() {
    local schema="$1" key="$2" result
    if [[ -n "$INA_TEST" && -f "$INA_TEST/settings.json" ]]; then
        result="$(jq -r --arg id "$schema/$key" '.[$id] // empty' "$INA_TEST/settings.json")"
        if [[ -n "$result" ]]; then printf '%s' "$result"; return; fi
    fi
    ina_need gsettings
    gsettings get "$schema" "$key"
}
ina_put() {
    local schema="$1" key="$2" value="$3" text
    if [[ -n "$INA_TEST" ]]; then
        text='{}'; [[ ! -f "$INA_TEST/settings.json" ]] || text="$(cat -- "$INA_TEST/settings.json")"
        text="$(jq --arg id "$schema/$key" --arg v "$value" '.[$id]=$v' <<< "$text")"
        ina_atomic "$INA_TEST/settings.json" "$(ina_b64 "$text")" 600
    else gsettings set "$schema" "$key" "$value"; fi
}
ina_setting() {
    local schema="$1" key="$2" wanted="$3" current original applied id
    current="$(ina_get "$schema" "$key")"
    printf '%s/%s = %s\n' "$schema" "$key" "$wanted"
    "$INA_DRY" && return 0
    id="$schema/$key"
    if jq -e --arg id "$id" '.settings | has($id)' <<< "$INA_JSON" >/dev/null; then
        original="$(jq -r --arg id "$id" '.settings[$id].original' <<< "$INA_JSON")"
        applied="$(jq -r --arg id "$id" '.settings[$id].applied' <<< "$INA_JSON")"
        [[ "$current" == "$original" || "$current" == "$applied" ]] || ina_error "Setting changed externally: $id"
    else original="$current"; fi
    [[ "$current" != "$wanted" ]] || return 0
    INA_JSON="$(jq --arg id "$id" --arg s "$schema" --arg k "$key" --arg o "$original" --arg a "$wanted" '.settings[$id]={schema:$s,key:$k,original:$o,applied:$a}' <<< "$INA_JSON")"
    ina_save; ina_put "$schema" "$key" "$wanted"
}
ina_file() {
    local path content mode current entry saved_mode
    path="$(ina_user_path "$1")"; content="$2"; mode="${3:-600}"
    [[ ! -e "$path" || -f "$path" ]] || ina_error "Not a regular file: $path"
    printf 'File: %s\n' "$path"
    "$INA_DRY" && return 0
    current='null'; [[ ! -f "$path" ]] || current="$(base64 -w0 -- "$path" | jq -Rs .)"
    if jq -e --arg p "$path" '.files|has($p)' <<< "$INA_JSON" >/dev/null; then
        entry="$(jq --arg p "$path" '.files[$p]' <<< "$INA_JSON")"
        jq -e --argjson c "$current" '$c == .original or $c == .applied' <<< "$entry" >/dev/null || ina_error "File changed externally: $path"
    else
        saved_mode="$mode"; [[ ! -f "$path" ]] || saved_mode="$(stat -c '%a' -- "$path")"
        entry="$(jq -n --argjson o "$current" --arg m "$saved_mode" '{original:$o,mode:$m}')"
    fi
    entry="$(jq --arg a "$content" --arg m "$mode" '.applied=$a | .applied_mode=$m' <<< "$entry")"
    INA_JSON="$(jq --arg p "$path" --argjson e "$entry" '.files[$p]=$e' <<< "$INA_JSON")"
    ina_track_dirs "$path"
    ina_save
    if [[ "$current" != "$(printf '%s' "$content" | jq -Rs .)" || "$(stat -c '%a' -- "$path" 2>/dev/null || true)" != "$mode" ]]; then ina_atomic "$path" "$content" "$mode"; fi
}
ina_text() {
    local mode="${3:-600}"
    if (($# < 3)) && [[ -f "$1" ]]; then mode="$(stat -c '%a' -- "$1")"; fi
    ina_file "$1" "$(ina_b64 "$2")" "$mode"
}
ina_copy() {
    local source
    source="$(ina_path "$1")"
    [[ -f "$source" ]] || ina_error "Required source file missing: $source"
    ina_file "$2" "$(base64 -w0 -- "$source")" "${3:-644}"
}
ina_read_text() {
    INA_TEXT="$(cat -- "$1" || ina_error "Cannot read $1"; printf '\001')"
    INA_TEXT="${INA_TEXT%$'\001'}"
}
ina_decode_text() {
    INA_TEXT="$(printf '%s' "$1" | base64 --decode || ina_error 'Invalid backup encoding'; printf '\001')"
    INA_TEXT="${INA_TEXT%$'\001'}"
}
ina_block_parts() {
    local path="$1" begin="/* $2 begin */" end="/* $2 end */" rest
    INA_BLOCK_BEFORE='' INA_BLOCK_AFTER='' INA_BLOCK_OWNED=''
    [[ ! -e "$path" || -f "$path" ]] || ina_error "Not a regular file: $path"
    [[ ! -f "$path" ]] || { ina_read_text "$path"; INA_BLOCK_BEFORE="$INA_TEXT"; }
    if [[ "$INA_BLOCK_BEFORE" == *"$begin"* ]]; then
        rest="${INA_BLOCK_BEFORE#*"$begin"}"
        INA_BLOCK_BEFORE="${INA_BLOCK_BEFORE%%"$begin"*}"
        [[ "$INA_BLOCK_BEFORE" != *"$end"* && "$rest" == *"$end"* && "$rest" != *"$begin"* ]] || ina_error "Malformed or duplicate CSS block: $path"
        INA_BLOCK_OWNED="$begin${rest%%"$end"*}$end"
        INA_BLOCK_AFTER="${rest#*"$end"}"
        [[ "$INA_BLOCK_AFTER" != *"$end"* ]] || ina_error "Duplicate CSS end marker: $path"
        if [[ "$INA_BLOCK_AFTER" == $'\n'* ]]; then
            INA_BLOCK_OWNED+=$'\n'; INA_BLOCK_AFTER="${INA_BLOCK_AFTER#$'\n'}"
        fi
    elif [[ "$INA_BLOCK_BEFORE" == *"$end"* ]]; then ina_error "CSS end marker without begin: $path"; fi
}
ina_block() {
    local path marker="$2" content="$3"$'\n' current entry mode=600 existed=false original before after separator=''
    path="$(ina_user_path "$1")"
    if [[ -f "$path" ]]; then
        existed=true; mode="$(stat -c '%a' -- "$path")"
    elif [[ -e "$path" ]]; then ina_error "Not a regular file: $path"; fi
    ina_block_parts "$path" "$marker"
    current="$INA_BLOCK_OWNED"; before="$INA_BLOCK_BEFORE"; after="$INA_BLOCK_AFTER"
    printf 'CSS block: %s in %s\n' "$marker" "$path"
    "$INA_DRY" && return 0
    if jq -e --arg p "$path" '.files|has($p)' <<< "$INA_JSON" >/dev/null; then
        entry="$(jq --arg p "$path" '.files[$p]' <<< "$INA_JSON")"
        [[ "$(jq -r '.block_marker // ""' <<< "$entry")" == "$marker" ]] || ina_error 'File already owned by another operation'
        ina_decode_text "$(jq -r '.block_original' <<< "$entry")"; original="$INA_TEXT"
        ina_decode_text "$(jq -r '.block_applied' <<< "$entry")"
        [[ "$current" == "$original" || "$current" == "$INA_TEXT" ]] || ina_error "CSS block changed externally: $path"
    else
        # Record a separator added only when the existing file lacks a final newline.
        if [[ -z "$current" && -n "$before" && "$before" != *$'\n' ]]; then separator=$'\n'; fi
        entry="$(jq -n --arg o "$(ina_b64 "$current")" --arg m "$mode" --arg sep "$(ina_b64 "$separator")" --argjson exists "$existed" '{block_original:$o,mode:$m,existed:$exists,separator:$sep}')"
    fi
    entry="$(jq --arg marker "$marker" --arg a "$(ina_b64 "$content")" '.block_marker=$marker | .block_applied=$a' <<< "$entry")"
    INA_JSON="$(jq --arg p "$path" --argjson e "$entry" '.files[$p]=$e' <<< "$INA_JSON")"
    ina_track_dirs "$path"
    ina_save
    [[ "$current" != "$content" ]] || return 0
    ina_atomic "$path" "$(ina_b64 "$before$separator$content$after")" "$mode"
}
ina_restore_records() {
    local entry schema key current original applied path marker text mode separator
    while IFS= read -r entry; do
        schema="$(jq -r '.schema' <<< "$entry")"; key="$(jq -r '.key' <<< "$entry")"
        current="$(ina_get "$schema" "$key")"
        original="$(jq -r '.original' <<< "$entry")"; applied="$(jq -r '.applied' <<< "$entry")"
        [[ "$current" == "$original" || "$current" == "$applied" ]] || ina_error "Setting changed externally: $schema/$key"
    done < <(jq -c '.settings[]' <<< "$INA_JSON")
    while IFS= read -r path; do
        path="$(ina_user_path "$path")"; entry="$(jq --arg p "$path" '.files[$p]' <<< "$INA_JSON")"
        [[ ! -e "$path" || -f "$path" ]] || ina_error "Not a regular file: $path"
        mode="$(jq -r '.mode' <<< "$entry")"
        [[ "$mode" =~ ^[0-7]{3,4}$ ]] || ina_error "Invalid mode in backup for $path"
        if [[ -f "$path" ]]; then
            current="$(stat -c '%a' -- "$path")"
            [[ "$current" == "$mode" || "$current" == "$(jq -r '.applied_mode // .mode' <<< "$entry")" ]] || ina_error "File permissions changed externally: $path"
        fi
        marker="$(jq -r '.block_marker // ""' <<< "$entry")"
        if [[ -n "$marker" ]]; then
            ina_block_parts "$path" "$marker"; current="$INA_BLOCK_OWNED"
            ina_decode_text "$(jq -r '.block_original' <<< "$entry")"; original="$INA_TEXT"
            ina_decode_text "$(jq -r '.block_applied' <<< "$entry")"; applied="$INA_TEXT"
            [[ "$current" == "$original" || "$current" == "$applied" ]] || ina_error "CSS block changed externally: $path"
        else
            current='null'; [[ ! -f "$path" ]] || current="$(base64 -w0 -- "$path" | jq -Rs .)"
            jq -e --argjson c "$current" '$c == .original or $c == .applied' <<< "$entry" >/dev/null || ina_error "File changed externally: $path"
        fi
    done < <(jq -r '.files|keys[]' <<< "$INA_JSON")
    if jq -e '.power != null' <<< "$INA_JSON" >/dev/null; then
        ina_need powerprofilesctl
        current="$(powerprofilesctl get)"
        [[ "$current" == "$(jq -r '.power.original' <<< "$INA_JSON")" || "$current" == "$(jq -r '.power.applied' <<< "$INA_JSON")" ]] || ina_error 'Power profile changed externally'
    fi
    while IFS= read -r path; do
        entry="$(jq --arg p "$path" '.files[$p]' <<< "$INA_JSON")"
        printf 'Restore: %s\n' "$path"
        "$INA_DRY" && continue
        marker="$(jq -r '.block_marker // ""' <<< "$entry")"; mode="$(jq -r '.mode' <<< "$entry")"
        if [[ -n "$marker" ]]; then
            ina_block_parts "$path" "$marker"
            ina_decode_text "$(jq -r '.block_original' <<< "$entry")"; original="$INA_TEXT"
            ina_decode_text "$(jq -r '.separator // ""' <<< "$entry")"; separator="$INA_TEXT"
            if [[ -n "$separator" && "$INA_BLOCK_BEFORE" == *"$separator" && -n "$INA_BLOCK_OWNED" ]]; then INA_BLOCK_BEFORE="${INA_BLOCK_BEFORE%"$separator"}"; fi
            text="$INA_BLOCK_BEFORE$original$INA_BLOCK_AFTER"
            if [[ -z "$text" && "$(jq -r '.existed' <<< "$entry")" == false ]]; then
                [[ ! -e "$path" ]] || rm -- "$path"
            else ina_atomic "$path" "$(ina_b64 "$text")" "$mode"; fi
        elif jq -e '.original == null' <<< "$entry" >/dev/null; then
            [[ ! -e "$path" ]] || rm -- "$path"
        else ina_atomic "$path" "$(jq -r '.original' <<< "$entry")" "$mode"; fi
    done < <(jq -r '.files|keys[]' <<< "$INA_JSON")
    while IFS= read -r entry; do
        schema="$(jq -r '.schema' <<< "$entry")"; key="$(jq -r '.key' <<< "$entry")"; original="$(jq -r '.original' <<< "$entry")"
        printf 'Restore: %s/%s = %s\n' "$schema" "$key" "$original"
        "$INA_DRY" || ina_put "$schema" "$key" "$original"
    done < <(jq -c '.settings[]' <<< "$INA_JSON")
    if ! "$INA_DRY" && jq -e '.power != null' <<< "$INA_JSON" >/dev/null; then powerprofilesctl set "$(jq -r '.power.original' <<< "$INA_JSON")"; fi
    while IFS= read -r path; do
        path="$(ina_user_path "$path")"
        printf 'Remove if empty: %s\n' "$path"
        if ! "$INA_DRY" && [[ -d "$path" ]]; then rmdir --ignore-fail-on-non-empty -- "$path"; fi
    done < <(jq -r '(.directories // []) | sort_by(length) | reverse | .[]' <<< "$INA_JSON")
}
ina_quote() {
    local value="$1"
    value="${value//\\/\\\\}"; value="${value//\'/\\\'}"
    printf "'%s'" "$value"
}
ina_array_read() {
    local text="$1" item
    INA_ARRAY=(); text="${text#@as }"
    [[ "$text" == \[*\] ]] || ina_error 'Unsupported settings array'
    text="${text:1:${#text}-2}"
    while [[ "$text" =~ ^[[:space:]]*\'([^\'\\]*)\'[[:space:]]*(,|$) ]]; do
        item="${BASH_REMATCH[1]}"; INA_ARRAY+=("$item"); text="${text:${#BASH_REMATCH[0]}}"
    done
    [[ "$text" =~ ^[[:space:]]*$ ]] || ina_error 'Unsupported or escaped array entry'
}
ina_array() {
    local item separator=''
    printf '['
    for item in "$@"; do printf '%s' "$separator"; ina_quote "$item"; separator=', '; done
    printf ']'
}
