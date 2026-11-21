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
                'GTK continuously pans and zooms the first approved still; the desktop stays static.' \
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
jq -e '[.images[] | select(.role | startswith("lock-")) | .role] == ["lock-1", "lock-2", "lock-3"]' \
    "$SCRIPT_DIR/../dotfiles/image-sources.json" >/dev/null || ina_error 'Expected exactly three ordered lock sources'
prepared="$INA_DATA/ina/lockscreen"
# Keep the desktop selection when repeating image preparation without --image.
if [[ -z "$INA_IMAGE" && -f "$prepared/assets.json" ]]; then
    ina_path "$prepared/assets.json" >/dev/null
    INA_IMAGE="$(jq -er '.desktop_image | select(type == "string")' "$prepared/assets.json")" || ina_error 'Invalid existing image configuration'
fi
ina_begin
images=()
for number in 1 2 3; do
    ina_image_source "lock-$number"
    image="$prepared/lock-$number.jpg"
    ina_download_image "$image"
    images+=("$image")
done
configuration="$(jq -n --arg desktop "$INA_IMAGE" --arg a "${images[0]}" --arg b "${images[1]}" --arg c "${images[2]}" \
    '{desktop_image:$desktop,lock_images:[$a,$b,$c],login_image:"",approved:false}')"
ina_text "$prepared/assets.json" "$configuration"$'\n' 600
printf 'Image configuration: %s\n' "$prepared/assets.json"
if "$INA_DRY"; then printf '%s\n' 'Preview only. Three images would be prepared in the selected order.'
else printf '%s\n' 'Three images prepared in the selected order.'; fi
printf '%s\n' 'Live motion uses the first selected still; the remaining paths are retained for compatibility.' \
    'Select an independent static desktop image in assets.json before enabling motion.' \
    'Live setup requires --force-lock-on-activation and locks each supervised Cinnamon screensaver.' \
    'No wallpaper, login-screen setting, service, or boot file was changed.'
ina_finish
