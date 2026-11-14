#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'Plymouth configuration is unsupported because it changes boot files and has no managed recovery.' >&2
exit 1
