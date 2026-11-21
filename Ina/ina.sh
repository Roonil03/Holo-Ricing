#!/usr/bin/env bash
set -euo pipefail
# User-facing entry point: apply selected rice together; an explicit preview wins.
SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
arguments=("$@")
mode=false
for argument in "$@"; do
    case "$argument" in
        --) break ;;
        --dry-run|--apply|--help|--restore-grub|--internal-grub) mode=true ;;
    esac
done
if ! "$mode"; then arguments=(--apply "${arguments[@]}"); fi
exec bash "$SELF_DIR/ina_rice.sh" "${arguments[@]}"
