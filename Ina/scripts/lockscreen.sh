#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
download=false
for argument in "$@"; do
    case "$argument" in
        --download-images) download=true ;;
        --help)
            printf '%s\n' 'Prepare selected images: --download-images --dry-run' \
                'Download selected images: --download-images --apply --approved' \
                'Optional: --asset-config PATH or --image PATH for the independent desktop image.' \
                'Preparation downloads only user-local files. It does not enable live rotation.' \
                'Without --download-images, use --images PATH PATH PATH --image PATH --approved for the test-only model.' \
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
printf '%s\n' 'Interval for the test-only model: 300 seconds.' \
    'Select an independent static desktop image in assets.json before using the model.' \
    'Live rotation remains disabled until lock-state detection and restoration are tested.' \
    'No wallpaper, login-screen setting, service, or boot file was changed.'
ina_finish
