#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init install "$@"
available=(icons window-controls widgets vscode firefox gaming-mode wallpaper cursor taskbar nemo animations grub lockscreen)
printf '%s\n' 'Ina components. Nothing is selected by default.'
for index in "${!available[@]}"; do printf '%d. %s\n' "$((index + 1))" "${available[index]}"; done
if (("${#INA_COMPONENTS[@]}" == 0)) && [[ -t 0 ]] && ! "$INA_EXPLICIT_DRY"; then
    read -r -p 'Enter component numbers separated by spaces, or Enter to exit: ' answer
    read -r -a numbers <<< "$answer"
    for number in "${numbers[@]}"; do
        [[ "$number" =~ ^[1-9][0-9]*$ && "${#number}" -le 2 ]] || ina_error 'Invalid selection'
        ((number <= ${#available[@]})) || ina_error 'Selection out of range'
        INA_COMPONENTS+=("${available[number-1]}")
    done
fi
if (("${#INA_COMPONENTS[@]}" == 0)); then printf '%s\n' 'Choose --components NAME... . No changes.'; exit 0; fi
declare -A selected=()
components=()
for name in "${INA_COMPONENTS[@]}"; do
    found=false
    for allowed in "${available[@]}"; do [[ "$name" != "$allowed" ]] || found=true; done
    "$found" || ina_error "Unknown or older component: $name"
    [[ -z "${selected[$name]:-}" ]] || continue
    selected["$name"]=1; components+=("$name")
    if ! "$INA_DRY"; then
        case "$name" in
            lockscreen) ina_error 'Live lock rotation is unavailable' ;;
            vscode) [[ -n "$INA_SETTINGS" ]] || ina_error 'VS Code requires --settings PATH' ;;
            firefox) [[ -n "$INA_PROFILE" ]] || ina_error 'Firefox requires --profile PATH' ;;
            widgets) (("${#INA_WIDGETS[@]}" > 0)) || ina_error 'Select --widgets NAME...' ;;
            wallpaper) [[ -n "$INA_IMAGE" ]] && "$INA_APPROVED" || ina_error 'Wallpaper requires --image PATH --approved' ;;
            grub) "$INA_BOOT" || ina_error 'GRUB requires --allow-boot-change' ;;
            gaming-mode) (("${#INA_COMMAND[@]}" > 0)) || ina_error 'Gaming mode requires a command after --' ;;
        esac
    fi
done
for name in "${components[@]}"; do
    case "$name" in
        vscode|firefox|grub|lockscreen) ;;
        *) ina_desktop ;;
    esac
done
common=()
[[ -z "$INA_TEST" ]] || common+=(--test-root "$INA_TEST")
"$INA_DESKTOP" && common+=(--apply-desktop)
component_args() {
    args=("${common[@]}")
    case "$1" in
        vscode) [[ -z "$INA_SETTINGS" ]] || args+=(--settings "$INA_SETTINGS") ;;
        firefox) [[ -z "$INA_PROFILE" ]] || args+=(--profile "$INA_PROFILE"); "$INA_CHROME" && args+=(--user-chrome) ;;
        wallpaper) [[ -z "$INA_IMAGE" ]] || args+=(--image "$INA_IMAGE"); "$INA_APPROVED" && args+=(--approved) ;;
        widgets) (("${#INA_WIDGETS[@]}" == 0)) || args+=(--widgets "${INA_WIDGETS[@]}") ;;
        grub) "$INA_BOOT" && args+=(--allow-boot-change) ;;
        gaming-mode) [[ -z "$INA_POWER" ]] || args+=(--power-profile "$INA_POWER") ;;
    esac
    return 0
}
# Preview every selection before applying any. Each child owns its backup.
for name in "${components[@]}"; do
    component_args "$name"
    if [[ "$name" == gaming-mode ]]; then
        bash "$SCRIPT_DIR/$name.sh" "${args[@]}" --dry-run -- "${INA_COMMAND[@]}"
    else bash "$SCRIPT_DIR/$name.sh" "${args[@]}" --dry-run; fi
done
if ! "$INA_DRY"; then
    for name in "${components[@]}"; do
        component_args "$name"
        printf 'Applying %s. Restore it with: bash %q --component %q --apply\n' "$name" "$SCRIPT_DIR/restore.sh" "$name"
        if [[ "$name" == gaming-mode ]]; then
            bash "$SCRIPT_DIR/$name.sh" "${args[@]}" --apply -- "${INA_COMMAND[@]}"
        else bash "$SCRIPT_DIR/$name.sh" "${args[@]}" --apply; fi
    done
fi
