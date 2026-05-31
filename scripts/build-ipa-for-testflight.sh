#!/bin/bash

# Build and upload Content Calendar IPA for App Store Connect.
# One iPhone-only IPA is used for BOTH TestFlight and App Store review submission.
# Usage:
#   ./scripts/build-ipa-for-testflight.sh           # build only
#   ./scripts/build-ipa-for-testflight.sh --upload  # build + upload to ASC
#
# After upload, in App Store Connect:
#   1. TestFlight → build appears for internal/external testing
#   2. App Store → select the SAME build on your version → Submit for Review
#      (uploading to TestFlight alone does NOT submit for App Review)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK_DIR="/tmp/contentcalendar-testflight-build.lock.d"
if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
  echo "❌ Another Content Calendar TestFlight build is already running."
  echo "   Wait for it to finish, or remove ${LOCK_DIR} if it is stale."
  exit 1
fi

IOS_DIR="${PROJECT_ROOT}/ios"
SCHEME="Runner"
WORKSPACE="Runner.xcworkspace"
CONFIGURATION="Release"
APP_NAME="Runner"
BUNDLE_ID="com.calendar.content"
TEAM_ID="94QA2FVSW2"
ASC_PROVIDER_PUBLIC_ID="76ab0bd9-90a9-4df5-ab29-e80f06841bb6"
CONFIG_FILE="${PROJECT_ROOT}/scripts/app-store-config.json"

ARCHIVE_PATH="${PROJECT_ROOT}/build/${APP_NAME}.xcarchive"
EXPORT_PATH="${PROJECT_ROOT}/build/export"
IPA_PATH="${PROJECT_ROOT}/build/ipa/${APP_NAME}.ipa"
UPLOAD_LOG="/tmp/testflight_upload_contentcalendar.log"
EXPORT_OPTIONS_PLIST="$(mktemp /tmp/contentcalendar-export-options.XXXXXX.plist)"

UPLOAD=false
if [[ "${1:-}" == "--upload" ]]; then
  UPLOAD=true
fi

cleanup() {
  rm -f "$EXPORT_OPTIONS_PLIST"
  rmdir "${LOCK_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

if [[ -f "${CONFIG_FILE}" ]]; then
  ASC_APP_NUMERIC_ID="$(python3 - <<PY
import json
from pathlib import Path
data = json.loads(Path("${CONFIG_FILE}").read_text())
print(data.get("asc_app_numeric_id", "") or "")
PY
)"
else
  ASC_APP_NUMERIC_ID=""
fi

resolve_asc_app_id() {
  local creds_file="$1"
  local apple_id="$2"
  local password="$3"
  if [[ -n "${ASC_APP_NUMERIC_ID}" ]]; then
    echo "${ASC_APP_NUMERIC_ID}"
    return 0
  fi
  python3 - <<PY
import re, subprocess, sys
bundle = "${BUNDLE_ID}"
apple_id = "${apple_id}"
password = "${password}"
proc = subprocess.run(
    ["xcrun", "altool", "--list-apps", "--username", apple_id, "--password", password],
    capture_output=True,
    text=True,
)
text = proc.stdout + "\n" + proc.stderr
current_name = ""
current_id = ""
current_bundle = ""
for line in text.splitlines():
    line = line.strip()
    if line.startswith("= Name:"):
        current_name = line.split(":", 1)[1].strip()
    elif line.startswith("= ID:"):
        current_id = line.split(":", 1)[1].strip()
    elif line.startswith("= Bundle ID:"):
        current_bundle = line.split(":", 1)[1].strip()
        if current_bundle == bundle and current_id.isdigit():
            print(current_id)
            sys.exit(0)
print("")
PY
}

cat >"$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF

echo "📦 Building iPhone-only IPA for App Store Connect..."
echo "Bundle ID: ${BUNDLE_ID}"
echo "Team ID: ${TEAM_ID}"
echo "Device family: iPhone only (no iPad)"
echo ""

export PATH="$HOME/flutter/bin:$PATH"
cd "${PROJECT_ROOT}"

if [[ "${UPLOAD}" == true && "${SKIP_FLUTTER_CLEAN:-}" != "1" ]]; then
  echo "🧹 Full clean before release upload (prevents stale Dart / parallel-build cache)..."
  flutter clean
elif [[ "${UPLOAD}" == true ]]; then
  echo "ℹ️ Skipping flutter clean (SKIP_FLUTTER_CLEAN=1)."
fi

flutter pub get
dart run flutter_launcher_icons

if [[ -f "${IOS_DIR}/Podfile" ]] && [[ ! -f "${IOS_DIR}/Pods/Pods.xcodeproj/project.pbxproj" ]]; then
  echo "📱 Running pod install in ios/..."
  (cd "${IOS_DIR}" && pod install)
fi

echo "Syncing iOS build number from pubspec.yaml..."
flutter build ios --config-only

echo "Step 0: Release readiness checks..."
VERIFY_ARGS=()
if [[ "${UPLOAD}" == true ]]; then
  VERIFY_ARGS+=(--upload)
fi
python3 "${PROJECT_ROOT}/scripts/verify-release-readiness.py" "${VERIFY_ARGS[@]}"
"${PROJECT_ROOT}/scripts/run-release-integrity-test.sh"
echo ""

echo "🧹 Cleaning previous iOS archive/export..."
rm -rf "${ARCHIVE_PATH}" "${EXPORT_PATH}" "${PROJECT_ROOT}/build/ios_derived_data"
mkdir -p "${PROJECT_ROOT}/build/ipa"

echo ""
echo "Step 1: Archiving iOS app..."
pushd "${IOS_DIR}" >/dev/null
xcodebuild archive \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -archivePath "${ARCHIVE_PATH}" \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  -derivedDataPath "${PROJECT_ROOT}/build/ios_derived_data" \
  | tee /tmp/testflight_archive_contentcalendar.log
popd >/dev/null

echo "✅ Archive created: ${ARCHIVE_PATH}"

echo ""
echo "Step 2: Exporting IPA..."
pushd "${IOS_DIR}" >/dev/null
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
  -allowProvisioningUpdates \
  | tee /tmp/testflight_export_contentcalendar.log
popd >/dev/null

if [[ -f "${EXPORT_PATH}/${APP_NAME}.ipa" ]]; then
  cp "${EXPORT_PATH}/${APP_NAME}.ipa" "${IPA_PATH}"
elif [[ -f "${EXPORT_PATH}/content_calendar.ipa" ]]; then
  cp "${EXPORT_PATH}/content_calendar.ipa" "${IPA_PATH}"
else
  echo "❌ IPA not found in ${EXPORT_PATH}"
  ls -la "${EXPORT_PATH}" || true
  exit 1
fi

echo "✅ IPA exported successfully: ${IPA_PATH}"

verify_ipa_release() {
  local plist_tmp app_tmp pubspec_build ipa_build
  plist_tmp="$(mktemp /tmp/contentcalendar-ipa-plist.XXXXXX)"
  app_tmp="$(mktemp /tmp/contentcalendar-app-bin.XXXXXX)"
  unzip -p "${IPA_PATH}" "Payload/Runner.app/Info.plist" >"${plist_tmp}"
  IPA_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "${plist_tmp}")"
  IPA_VERSION="$(plutil -extract CFBundleShortVersionString raw "${plist_tmp}")"
  IPA_BUILD="$(plutil -extract CFBundleVersion raw "${plist_tmp}")"
  rm -f "${plist_tmp}"
  pubspec_build="$(python3 - <<'PY'
import re
from pathlib import Path
text = Path("pubspec.yaml").read_text()
match = re.search(r"^version:\s*[\d.]+\+(\d+)\s*$", text, re.MULTILINE)
print(match.group(1) if match else "")
PY
)"
  if [[ -z "${pubspec_build}" || "${pubspec_build}" != "${IPA_BUILD}" ]]; then
    echo "❌ IPA build number ${IPA_BUILD} does not match pubspec +${pubspec_build}."
    exit 1
  fi
  unzip -p "${IPA_PATH}" "Payload/Runner.app/Frameworks/App.framework/App" >"${app_tmp}"
  if ! strings "${app_tmp}" | grep -q "Send to Voltiscore"; then
    echo "❌ IPA is missing the in-app bug report form (Send to Voltiscore)."
    exit 1
  fi
  if strings "${app_tmp}" | grep -q "Email support"; then
    echo "❌ IPA still contains the removed Email support button."
    exit 1
  fi
  rm -f "${app_tmp}"
  echo "✅ IPA verified: ${IPA_VERSION} (${IPA_BUILD}) includes bug report form."
}

verify_ipa_release

DEVICE_FAMILY="$(unzip -p "${IPA_PATH}" "Payload/Runner.app/Info.plist" | plutil -extract UIDeviceFamily xml1 -o - - 2>/dev/null | grep -o '[0-9]' | tr '\n' ',' | sed 's/,$//')"
echo "UIDeviceFamily in IPA: ${DEVICE_FAMILY:-unknown} (1 = iPhone only)"
if [[ "${DEVICE_FAMILY}" == *"2"* ]]; then
  echo "⚠️  Warning: IPA includes iPad (family 2). App Store review may require iPhone-only binary."
fi

if [[ "${UPLOAD}" == false ]]; then
  echo ""
  echo "ℹ️ IPA ready at: ${IPA_PATH}"
  echo "To upload, run: ./scripts/build-ipa-for-testflight.sh --upload"
  exit 0
fi

echo ""
echo "Step 3: Uploading to TestFlight..."

CREDENTIALS=""
CREDS_FILE="${PROJECT_ROOT}/scripts/testflight-credentials.json"
API_CREDS_FILE="${PROJECT_ROOT}/scripts/testflight-api-key.json"
NOTEPAD_CREDS="${PROJECT_ROOT}/../notepad-pro/scripts/testflight-credentials.json"
CLIPSTACK_CREDS="${PROJECT_ROOT}/../clipstack/frontend/scripts/testflight-credentials.json"
PRELURA_SWIFT_CREDS="${PROJECT_ROOT}/../prelura/prelura-swift/frontend/scripts/testflight-credentials.json"

if [[ -f "${CREDS_FILE}" ]]; then
  CREDENTIALS="$(<"${CREDS_FILE}")"
  echo "Using credentials from scripts/testflight-credentials.json"
elif [[ -f "${NOTEPAD_CREDS}" ]]; then
  CREDS_FILE="${NOTEPAD_CREDS}"
  CREDENTIALS="$(<"${CREDS_FILE}")"
  echo "Using credentials from ../notepad-pro/scripts/testflight-credentials.json"
elif [[ -f "${CLIPSTACK_CREDS}" ]]; then
  CREDS_FILE="${CLIPSTACK_CREDS}"
  CREDENTIALS="$(<"${CREDS_FILE}")"
  echo "Using credentials from ../clipstack/frontend/scripts/testflight-credentials.json"
elif [[ -f "${PRELURA_SWIFT_CREDS}" ]]; then
  CREDS_FILE="${PRELURA_SWIFT_CREDS}"
  CREDENTIALS="$(<"${CREDS_FILE}")"
  echo "Using credentials from ../prelura/prelura-swift/frontend/scripts/testflight-credentials.json"
fi

if [[ -z "${CREDENTIALS}" ]]; then
  CREDENTIALS="$(security find-generic-password -s "AC_PASSWORD" -a "clipstack" -w 2>/dev/null || true)"
fi
if [[ -z "${CREDENTIALS}" ]]; then
  CREDENTIALS="$(security find-generic-password -s "AC_PASSWORD" -a "Prelura-swift" -w 2>/dev/null || true)"
fi

if [[ -z "${CREDENTIALS}" ]]; then
  echo "❌ No credentials found."
  echo "   Copy scripts/testflight-credentials.json.example → scripts/testflight-credentials.json"
  exit 1
fi

METHOD="$(printf '%s' "${CREDENTIALS}" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("method",""))' 2>/dev/null || true)"
if [[ -z "${METHOD}" ]]; then
  echo "❌ Credentials JSON missing method field."
  exit 1
fi

PKG_INFO="$(mktemp /tmp/contentcalendar-ipa-plist.XXXXXX)"
unzip -p "${IPA_PATH}" "Payload/Runner.app/Info.plist" >"${PKG_INFO}"
if [[ -z "${IPA_BUILD:-}" ]]; then
  IPA_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "${PKG_INFO}")"
  IPA_VERSION="$(plutil -extract CFBundleShortVersionString raw "${PKG_INFO}")"
  IPA_BUILD="$(plutil -extract CFBundleVersion raw "${PKG_INFO}")"
fi
rm -f "${PKG_INFO}"
echo "IPA: bundle=${IPA_BUNDLE_ID} version=${IPA_VERSION} build=${IPA_BUILD}"

set +e
if [[ "${METHOD}" == "password" ]]; then
  APPLE_ID="$(printf '%s' "${CREDENTIALS}" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("apple_id",""))' 2>/dev/null)"
  APP_SPECIFIC_PASSWORD="$(printf '%s' "${CREDENTIALS}" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("app_specific_password",""))' 2>/dev/null)"

  if [[ -z "${ASC_APP_NUMERIC_ID}" ]]; then
    ASC_APP_NUMERIC_ID="$(resolve_asc_app_id "${CREDS_FILE}" "${APPLE_ID}" "${APP_SPECIFIC_PASSWORD}")"
  fi

  if [[ -n "${ASC_APP_NUMERIC_ID}" ]]; then
    echo "ASC app id=${ASC_APP_NUMERIC_ID} (upload-package)"
    xcrun altool --upload-package "${IPA_PATH}" \
      -t ios \
      --apple-id "${ASC_APP_NUMERIC_ID}" \
      --bundle-version "${IPA_BUILD}" \
      --bundle-short-version-string "${IPA_VERSION}" \
      --bundle-id "${IPA_BUNDLE_ID}" \
      --provider-public-id "${ASC_PROVIDER_PUBLIC_ID}" \
      --username "${APPLE_ID}" \
      --password "${APP_SPECIFIC_PASSWORD}" \
      --wait \
      2>&1 | tee "${UPLOAD_LOG}"
    ALTOOL_EXIT=${PIPESTATUS[0]}
  else
    echo "ASC numeric app id not found — trying upload-app (create app record in App Store Connect if this fails)."
    xcrun altool --upload-app \
      --type ios \
      --file "${IPA_PATH}" \
      --username "${APPLE_ID}" \
      --password "${APP_SPECIFIC_PASSWORD}" \
      2>&1 | tee "${UPLOAD_LOG}"
    ALTOOL_EXIT=${PIPESTATUS[0]}
  fi
elif [[ "${METHOD}" == "api_key" ]]; then
  API_KEY_ID="$(printf '%s' "${CREDENTIALS}" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("api_key_id",""))' 2>/dev/null)"
  ISSUER_ID="$(printf '%s' "${CREDENTIALS}" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("issuer_id",""))' 2>/dev/null)"
  if [[ -z "${ASC_APP_NUMERIC_ID}" ]]; then
    echo "❌ Set asc_app_numeric_id in scripts/app-store-config.json for API key uploads."
    exit 1
  fi
  xcrun altool --upload-package "${IPA_PATH}" \
    -t ios \
    --apple-id "${ASC_APP_NUMERIC_ID}" \
    --bundle-version "${IPA_BUILD}" \
    --bundle-short-version-string "${IPA_VERSION}" \
    --bundle-id "${IPA_BUNDLE_ID}" \
    --provider-public-id "${ASC_PROVIDER_PUBLIC_ID}" \
    --apiKey "${API_KEY_ID}" \
    --apiIssuer "${ISSUER_ID}" \
    --wait \
    2>&1 | tee "${UPLOAD_LOG}"
  ALTOOL_EXIT=${PIPESTATUS[0]}
else
  echo "❌ Unknown authentication method: ${METHOD}"
  exit 1
fi
set -e

if [[ ${ALTOOL_EXIT} -ne 0 ]]; then
  echo "❌ UPLOAD FAILED"
  echo "Upload log: ${UPLOAD_LOG}"
  exit ${ALTOOL_EXIT}
fi

if python3 - <<PY
import pathlib, sys
log = pathlib.Path("${UPLOAD_LOG}")
if not log.exists():
    sys.exit(1)
text = log.read_text(encoding="utf-8", errors="ignore")
bad_markers = [
    "UPLOAD FAILED",
    "Validation failed",
    "Failed to upload package.",
    "= BUILD-STATUS: FAILED",
    "PROCESSING-ERRORS:",
]
sys.exit(0 if any(m in text for m in bad_markers) else 1)
PY
then
  echo "❌ UPLOAD FAILED"
  echo "Upload log: ${UPLOAD_LOG}"
  exit 1
fi

if [[ -n "${ASC_APP_NUMERIC_ID}" ]]; then
  python3 - <<PY
import json
from pathlib import Path
path = Path("${CONFIG_FILE}")
data = json.loads(path.read_text()) if path.exists() else {}
if not data.get("asc_app_numeric_id"):
    data["asc_app_numeric_id"] = "${ASC_APP_NUMERIC_ID}"
    path.write_text(json.dumps(data, indent=2) + "\n")
    print("Saved asc_app_numeric_id to scripts/app-store-config.json")
PY
fi

echo "✅ UPLOAD SUCCEEDED"
echo "Upload log saved to: ${UPLOAD_LOG}"

echo ""
echo "Step 4: Auto-distributing to TestFlight beta groups..."
mkdir -p "${HOME}/.appstoreconnect/private_keys"
if compgen -G "${HOME}/Downloads/AuthKey_"*.p8 >/dev/null 2>&1; then
  for src in "${HOME}"/Downloads/AuthKey_*.p8; do
    dest="${HOME}/.appstoreconnect/private_keys/$(basename "${src}")"
    if [[ ! -f "${dest}" ]]; then
      cp "${src}" "${dest}"
      chmod 600 "${dest}"
      echo "Installed API key: ${dest}"
    fi
  done
fi
DISTRIBUTE_CREDS="${API_CREDS_FILE}"
if [[ ! -f "${DISTRIBUTE_CREDS}" ]]; then
  DISTRIBUTE_CREDS="${CREDS_FILE}"
fi
if python3 "${PROJECT_ROOT}/scripts/distribute-testflight-build.py" \
  --config "${CONFIG_FILE}" \
  --credentials "${DISTRIBUTE_CREDS}" \
  --version "${IPA_VERSION}" \
  --build "${IPA_BUILD}" \
  --wait; then
  echo "✅ TestFlight groups updated; internal testers should get a notification."
else
  echo "ℹ️ Auto-distribute skipped (API key not configured)."
  echo "   Upload succeeded — internal testers should still be notified via App Store Connect"
  echo "   (same as Mockups) once processing finishes."
fi

echo ""
echo "Next steps in App Store Connect (https://appstoreconnect.apple.com):"
echo "  • TestFlight: build ${IPA_VERSION} (${IPA_BUILD}) processing / notifying testers"
echo "  • App Review: App Store tab → your version → select this build → Submit for Review"
echo "  • Ensure subscription com.calendar.content.pro.monthly is attached to this version"
