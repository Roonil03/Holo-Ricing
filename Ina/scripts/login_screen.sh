#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/shell-common.sh"
ina_init login-screen "$@"
configuration=/etc/lightdm/slick-greeter.conf
[[ -z "$INA_TEST" ]] || configuration="$INA_TEST/system/slick-greeter.conf"
ina_path "$configuration" >/dev/null
printf '%s\n' 'The current login background is preserved. This component performs no writes.'
if [[ -f "$configuration" ]]; then
    [[ -r "$configuration" ]] || ina_error "Cannot read greeter configuration: $configuration"
    background="$(awk '
        /^[[:space:]]*\[/ { inside=($0 ~ /^[[:space:]]*\[Greeter\][[:space:]]*$/) }
        inside && /^[[:space:]]*background[[:space:]]*=/ {
            sub(/^[^=]*=[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print
        }
    ' "$configuration")"
    printf 'Configuration: %s\n' "$configuration"
    if [[ -n "$background" ]]; then printf 'Configured background: %s\n' "$background"
    else printf '%s\n' 'No background key in this configuration. The effective fallback is [unverified].'; fi
else
    printf 'No configuration at %s. The effective greeter background is [unverified].\n' "$configuration"
fi
printf '%s\n' 'Lock rotation never selects or changes the login background.'
