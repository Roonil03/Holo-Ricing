#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == --lock-now ]]; then
    shift
    if [[ "${1:-}" == --dry-run && $# -eq 1 ]]; then
        printf '%s\n' 'Would ask Cinnamon to lock, wait up to 60 seconds for its reply, then check that the screensaver is active.'
        exit 0
    fi
    if [[ $# -ne 0 || $EUID -eq 0 || "${XDG_SESSION_TYPE:-}" != x11 ]]; then
        printf '%s\n' 'Error: run --lock-now [--dry-run] as your Cinnamon X11 desktop user.' >&2
        exit 1
    fi
    for dependency in gdbus gsettings; do
        command -v "$dependency" >/dev/null || { printf 'Error: missing %s.\n' "$dependency" >&2; exit 1; }
    done
    if [[ "$(gsettings get org.cinnamon.desktop.screensaver lock-enabled)" != true ||
          "$(gsettings get org.cinnamon.desktop.lockdown disable-lock-screen)" != false ||
          "$(gsettings get org.cinnamon.desktop.screensaver custom-screensaver-command)" != "''" ]]; then
        printf '%s\n' 'Error: Cinnamon locking must be enabled and use the standard screensaver.' >&2
        exit 1
    fi
    locker=(--session --dest org.cinnamon.ScreenSaver --object-path /org/cinnamon/ScreenSaver)
    if ! gdbus call "${locker[@]}" --timeout 60 --method org.cinnamon.ScreenSaver.Lock '' >/dev/null; then
        printf '%s\n' 'Error: Cinnamon did not acknowledge the lock request. Check the screen before relying on the lock.' >&2
        exit 1
    fi
    if [[ "$(gdbus call "${locker[@]}" --timeout 5 --method org.cinnamon.ScreenSaver.GetActive)" != '(true,)' ]]; then
        printf '%s\n' 'Error: Cinnamon acknowledged the request but the screensaver is not confirmed active.' >&2
        exit 1
    fi
    printf '%s\n' 'Cinnamon acknowledged the lock request and reports an active screensaver.'
    exit 0
fi
download=false
for argument in "$@"; do
    case "$argument" in
        --download-images) download=true ;;
        --help)
            printf '%s\n' 'Prepare selected images: --download-images --dry-run' \
                'Download selected images: --download-images --apply --approved' \
                'Optional: --asset-config PATH or --image PATH for the independent desktop image.' \
                'Preparation downloads only user-local files. It does not enable live rotation.' \
                'Live setup: --asset-config PATH --approved --force-lock-on-activation --apply --apply-desktop.' \
                'Lock now with an extended reply timeout: --lock-now [--dry-run]. Unlock normally.' \
                'This locks the supervised Cinnamon screensaver immediately whenever it becomes active.' \
                'GTK pans and zooms each approved image in playlist order. The desktop stays static.' \
                'Optional: --lock-image-seconds 10..3600. The default is 300 seconds.' \
                'Requires Cinnamon on X11 and GTK animations enabled. Video is not decoded.' \
                'Use --test-root PATH for isolated simulation.' \
                'Restore prepared images: restore.sh --component lockscreen-images --apply'
            exit 0 ;;
    esac
done
if ! "$download"; then
    source "$SCRIPT_DIR/lib/common.sh"
    ina_main lockscreen "$@"
fi
source "$SCRIPT_DIR/lib/shell-common.sh"
source "$SCRIPT_DIR/lib/images.sh"
ina_init lockscreen-images "$@"
if ! "$INA_DRY"; then "$INA_APPROVED" || ina_error 'Image downloads require --apply --approved'; fi
jq -e '[.images[] | select(.role | startswith("lock-")) | .role] == [range(1; 9) | "lock-\(.)"]' \
    "$SCRIPT_DIR/../dotfiles/image-sources.json" >/dev/null || ina_error 'Expected exactly eight ordered lock sources'
prepared="$INA_DATA/ina/lockscreen"
# Preserve an explicit selection or the previous prepared playlist. Upgrades
# append the new sources; custom paths and the independent desktop stay selected.
existing="$INA_ASSETS"
if [[ -z "$existing" && -f "$prepared/assets.json" ]]; then existing="$prepared/assets.json"; fi
configuration='{}'
images=()
if [[ -n "$existing" ]]; then
    existing="$(ina_path "$existing")"
    configuration="$(cat -- "$existing")"
    jq -e 'type == "object" and ((.desktop_image // "") | type == "string") and
        (.lock_images | type == "array" and length >= 3 and length <= 8 and
        all(.[]; type == "string" and length > 0 and (contains("\n") | not)))' \
        <<< "$configuration" >/dev/null || ina_error 'Existing configuration requires 3 to 8 ordered lock paths'
    [[ -n "$INA_IMAGE" ]] || INA_IMAGE="$(jq -r '.desktop_image // ""' <<< "$configuration")"
    mapfile -t images < <(jq -r '.lock_images[]' <<< "$configuration")
fi
ina_begin
for number in {1..8}; do
    index=$((number - 1))
    ina_image_source "lock-$number"
    image="$prepared/lock-$number.jpg"
    if ((index < ${#images[@]})); then
        selected="$(ina_path "${images[index]}")"
        if [[ "$selected" != "$image" ]]; then
            # Existing approved local selections are inputs, never download destinations.
            ina_check_image "$selected" || ina_error "Existing lock image could not be decoded: $selected"
            printf 'Retained lock image %s: %s\n' "$number" "$selected"
            continue
        fi
    fi
    ina_download_image "$image"
    images[index]="$image"
done
playlist="$(printf '%s\n' "${images[@]}" | jq -R . | jq -s .)"
configuration="$(jq --arg desktop "$INA_IMAGE" --argjson images "$playlist" \
    '.desktop_image=$desktop | .lock_images=$images | .login_image=(.login_image // "") | .approved=false' <<< "$configuration")"
ina_text "$prepared/assets.json" "$configuration"$'\n' 600
printf 'Image configuration: %s\n' "$prepared/assets.json"
if "$INA_DRY"; then printf '%s\n' 'Preview only. Eight images would be prepared in the selected order.'
else printf '%s\n' 'Eight images prepared in the selected order.'; fi
printf '%s\n' 'Live motion cycles the selected playlist in order while locked.' \
    'Select an independent static desktop image in assets.json before enabling motion.' \
    'Live setup requires --force-lock-on-activation and locks each supervised Cinnamon screensaver.' \
    'No wallpaper, login-screen setting, service, or boot file was changed.'
ina_finish
