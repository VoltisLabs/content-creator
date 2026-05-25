#!/bin/bash
# Installable drag-and-drop DMG for Content Calendar (app + Applications alias).
# Usage: ./scripts/build-dmg-installer.sh [output.dmg]

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
OUTPUT_PATH="${1:-$HOME/Downloads/content_calendar-installer-$TS.dmg}"
VOLNAME="Content Calendar"
LEGACY_APP="/Applications/content_calendar.app"
INSTALL_APP="/Applications/Content Calendar.app"

export PATH="$HOME/flutter/bin:$HOME/.gem/ruby/2.6.0/bin:$PATH"
cd "$PROJECT_ROOT"

echo "Building macOS release..."
flutter pub get
flutter build macos --release

APP_FILENAME_FILE="$PROJECT_ROOT/macos/Flutter/ephemeral/.app_filename"
if [[ -f "$APP_FILENAME_FILE" ]]; then
  APP_NAME="$(tr -d '[:space:]' < "$APP_FILENAME_FILE")"
else
  APP_NAME="Content Calendar.app"
fi

RELEASE_APP="$PROJECT_ROOT/build/macos/Build/Products/Release/$APP_NAME"
if [[ ! -d "$RELEASE_APP" ]]; then
  # Fallback if ephemeral filename is stale.
  RELEASE_APP="$(find "$PROJECT_ROOT/build/macos/Build/Products/Release" -maxdepth 1 -name '*.app' -print -quit)"
fi
if [[ -z "${RELEASE_APP:-}" || ! -d "$RELEASE_APP" ]]; then
  echo "Missing release app under build/macos/Build/Products/Release"
  exit 1
fi
APP_NAME="$(basename "$RELEASE_APP")"
echo "Packaging: $APP_NAME"

STAGING="$PROJECT_ROOT/build/dmg/staging"
RW_DMG="$PROJECT_ROOT/build/dmg/content_calendar-rw.dmg"
rm -rf "$STAGING" "$RW_DMG" "$OUTPUT_PATH"
mkdir -p "$STAGING" "$(dirname "$OUTPUT_PATH")"

cp -R "$RELEASE_APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -size 220m -volname "$VOLNAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" "$RW_DMG"
MOUNT_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
MOUNT_POINT="$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/.*' | head -1)"
if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
  echo "Failed to mount DMG: $MOUNT_OUTPUT"
  exit 1
fi

cp -R "$STAGING/$APP_NAME" "$MOUNT_POINT/"
ln -s /Applications "$MOUNT_POINT/Applications"

if command -v osascript >/dev/null 2>&1; then
  osascript <<EOF || true
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {120, 120, 640, 420}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set position of item "$APP_NAME" of container window to {120, 160}
    set position of item "Applications" of container window to {380, 160}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
EOF
fi

hdiutil detach "$MOUNT_POINT" -quiet || hdiutil detach "$MOUNT_POINT" -force
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_PATH"
rm -f "$RW_DMG"

echo ""
echo "Installable DMG ready: $OUTPUT_PATH"
echo ""
echo "IMPORTANT — replace the old Mac app:"
echo "  1. Quit Content Calendar (and content_calendar if still running)."
echo "  2. Delete BOTH if present:"
echo "       $LEGACY_APP"
echo "       $INSTALL_APP"
echo "  3. Open the DMG and drag \"$APP_NAME\" into Applications."
echo "  4. Launch \"Content Calendar\" from Applications (not an old DMG copy)."
echo ""
echo "Built from: $PROJECT_ROOT"
echo "Binary time: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$RELEASE_APP/Contents/MacOS/"* 2>/dev/null | head -1)"
