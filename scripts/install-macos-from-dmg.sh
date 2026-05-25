#!/bin/bash
# Install the latest local release build into /Applications (replaces legacy names).
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_FILENAME_FILE="$PROJECT_ROOT/macos/Flutter/ephemeral/.app_filename"
if [[ -f "$APP_FILENAME_FILE" ]]; then
  APP_NAME="$(tr -d '[:space:]' < "$APP_FILENAME_FILE")"
else
  APP_NAME="Content Calendar.app"
fi

RELEASE_APP="$PROJECT_ROOT/build/macos/Build/Products/Release/$APP_NAME"
if [[ ! -d "$RELEASE_APP" ]]; then
  echo "Run ./scripts/build-dmg-installer.sh first (no release build found)."
  exit 1
fi

osascript -e 'tell application "Content Calendar" to quit' 2>/dev/null || true
osascript -e 'tell application "content_calendar" to quit' 2>/dev/null || true
sleep 1

sudo rm -rf "/Applications/content_calendar.app" "/Applications/Content Calendar.app"
sudo cp -R "$RELEASE_APP" "/Applications/Content Calendar.app"

echo "Installed: /Applications/Content Calendar.app"
open -a "/Applications/Content Calendar.app"
