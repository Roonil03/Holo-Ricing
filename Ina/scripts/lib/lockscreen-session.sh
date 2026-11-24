#!/usr/bin/env bash
set -euo pipefail
# Original MIT code. Start the managed worker from the Cinnamon login session.
ina_session_error() { printf 'Error: %s\n' "$*" >&2; exit 1; }
dry=false
check_session=false
if [[ $# -eq 1 && "$1" == --dry-run ]]; then
    dry=true
elif [[ $# -eq 1 && "$1" == --check-session ]]; then
    check_session=true
elif [[ $# -ne 0 ]]; then
    ina_session_error 'Usage: lockscreen-session.sh [--dry-run|--check-session]'
fi
((EUID != 0)) || ina_session_error 'Run as your desktop user, not root'
[[ ":${XDG_CURRENT_DESKTOP:-}:" == *:X-Cinnamon:* ||
   ":${XDG_CURRENT_DESKTOP:-}:" == *:Cinnamon:* ]] || ina_session_error 'Requires Cinnamon on X11'
[[ "${XDG_SESSION_TYPE:-}" == x11 && -n "${DISPLAY:-}" ]] || ina_session_error 'Requires Cinnamon on X11 with DISPLAY set'
command -v systemctl >/dev/null 2>&1 || ina_session_error 'Required command missing: systemctl'
if "$check_session"; then exit 0; fi
if "$dry"; then
    printf '%s\n' 'Would import DISPLAY, XAUTHORITY, XDG_CURRENT_DESKTOP, and XDG_SESSION_TYPE into the user manager, reload its units, and start ina-lockscreen.service.'
    exit 0
fi
# Empty XAUTHORITY preserves Xlib default discovery and clears any stale value
# inherited by a user manager that survived the previous graphical session.
export DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
export XAUTHORITY="${XAUTHORITY:-}"
systemctl --user import-environment DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
systemctl --user daemon-reload
# start is idempotent: an already active worker is never restarted here.
systemctl --user start ina-lockscreen.service
