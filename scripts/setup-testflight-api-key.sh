#!/bin/bash
# One-time setup: save App Store Connect API key + issuer ID for TestFlight auto-distribute.
#
# Usage:
#   ./scripts/setup-testflight-api-key.sh <issuer_id>
#   ASC_ISSUER_ID=<uuid> ./scripts/setup-testflight-api-key.sh
#
# Issuer ID: App Store Connect → Users and Access → Integrations → App Store Connect API
# (UUID shown at the top of the page, not the Team ID).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/scripts/app-store-config.json"
API_CREDS_FILE="${PROJECT_ROOT}/scripts/testflight-api-key.json"
KEY_ID="B3SJX8QWUX"
KEY_DIR="${HOME}/.appstoreconnect/private_keys"
KEY_PATH="${KEY_DIR}/AuthKey_${KEY_ID}.p8"

ISSUER_ID="${1:-${ASC_ISSUER_ID:-}}"

if [[ -z "${ISSUER_ID}" ]]; then
  echo "Opening App Store Connect API keys page…"
  open "https://appstoreconnect.apple.com/access/integrations/api" 2>/dev/null || true
  echo ""
  echo "Copy the Issuer ID (UUID at the top of the page)."
  read -r -p "Issuer ID: " ISSUER_ID
fi

if [[ ! "${ISSUER_ID}" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
  echo "❌ Invalid Issuer ID format (expected UUID)."
  exit 1
fi

mkdir -p "${KEY_DIR}"
if [[ ! -f "${KEY_PATH}" ]]; then
  for src in "${HOME}/Downloads/AuthKey_${KEY_ID}.p8" "${PROJECT_ROOT}/scripts/AuthKey_${KEY_ID}.p8"; do
    if [[ -f "${src}" ]]; then
      cp "${src}" "${KEY_PATH}"
      chmod 600 "${KEY_PATH}"
      echo "Installed API key: ${KEY_PATH}"
      break
    fi
  done
fi

if [[ ! -f "${KEY_PATH}" ]]; then
  echo "❌ AuthKey_${KEY_ID}.p8 not found."
  echo "   Place it in ~/Downloads or ${KEY_DIR}/"
  exit 1
fi

python3 - <<PY
import json, sys, time, urllib.request, urllib.error
from pathlib import Path
import jwt

issuer = "${ISSUER_ID}"
key_id = "${KEY_ID}"
key_path = Path("${KEY_PATH}")
private_key = key_path.read_text(encoding="utf-8")
now = int(time.time())
token = jwt.encode(
    {"iss": issuer, "exp": now + 1200, "aud": "appstoreconnect-v1"},
    private_key,
    algorithm="ES256",
    headers={"alg": "ES256", "kid": key_id, "typ": "JWT"},
)
req = urllib.request.Request(
    "https://api.appstoreconnect.apple.com/v1/apps?limit=1",
    headers={"Authorization": f"Bearer {token}"},
)
try:
    with urllib.request.urlopen(req, timeout=30) as resp:
        if resp.status != 200:
            raise SystemExit(f"Unexpected status {resp.status}")
except urllib.error.HTTPError as e:
    print(f"❌ API key validation failed ({e.code}). Check Issuer ID and key access.", file=sys.stderr)
    raise SystemExit(1)
print("✅ App Store Connect API key validated.")
PY

python3 - <<PY
import json
from pathlib import Path

api_creds = {
    "method": "api_key",
    "api_key_id": "${KEY_ID}",
    "issuer_id": "${ISSUER_ID}",
    "api_key_path": "${KEY_PATH}",
}
Path("${API_CREDS_FILE}").write_text(json.dumps(api_creds, indent=2) + "\n")
print("Saved ${API_CREDS_FILE}")

config_path = Path("${CONFIG_FILE}")
data = json.loads(config_path.read_text()) if config_path.exists() else {}
data["asc_api_key_id"] = "${KEY_ID}"
data["asc_issuer_id"] = "${ISSUER_ID}"
config_path.write_text(json.dumps(data, indent=2) + "\n")
print("Updated ${CONFIG_FILE}")
PY

echo ""
echo "TestFlight auto-distribute is ready."
echo "Push with: ./scripts/build-ipa-for-testflight.sh --upload"
