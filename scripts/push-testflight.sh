#!/bin/bash
# Canonical Voltis TestFlight release wrapper.
# Usage:
#   ./scripts/push-testflight.sh          # build + upload + auto-distribute
#   ./scripts/push-testflight.sh --build  # build only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ "${1:-}" == "--build" ]]; then
  if "${SCRIPT_DIR}/build-ipa-for-testflight.sh" --help 2>/dev/null | grep -q -- '--no-upload'; then
    exec "${SCRIPT_DIR}/build-ipa-for-testflight.sh" --no-upload
  fi
  exec "${SCRIPT_DIR}/build-ipa-for-testflight.sh"
fi

exec "${SCRIPT_DIR}/build-ipa-for-testflight.sh" --upload
