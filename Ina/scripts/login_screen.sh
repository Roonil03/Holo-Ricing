#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'The legacy login screen installer is unsupported because it changes LightDM and restarts the display manager.' >&2
exit 1
