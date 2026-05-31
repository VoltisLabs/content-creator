#!/bin/bash
# Resolve Voltis shared setup-testflight-api-key.sh from any app scripts/ folder.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
dir="${HERE}"
for _ in 1 2 3 4 5 6 7 8; do
  if [[ -x "${dir}/shared/setup-testflight-api-key.sh" ]]; then
    exec "${dir}/shared/setup-testflight-api-key.sh" "$@"
  fi
  if [[ -x "${dir}/Voltis labs/shared/setup-testflight-api-key.sh" ]]; then
    exec "${dir}/Voltis labs/shared/setup-testflight-api-key.sh" "$@"
  fi
  parent="$(dirname "${dir}")"
  [[ "${parent}" == "${dir}" ]] && break
  dir="${parent}"
done
echo "Could not find Voltis labs/shared/setup-testflight-api-key.sh" >&2
exit 1
