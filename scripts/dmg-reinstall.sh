#!/bin/bash
# /dmg — remove old installers, uninstall Mac apps, build fresh DMG, copy to Downloads, open DMG.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "Removing old DMG installers from Downloads..."
rm -f "$HOME/Downloads"/content_calendar-installer-*.dmg 2>/dev/null || true

echo "Quitting Content Calendar..."
osascript -e 'tell application "Content Calendar" to quit' 2>/dev/null || true
osascript -e 'tell application "content_calendar" to quit' 2>/dev/null || true
sleep 1

echo "Uninstalling Mac app copies..."
for app in "/Applications/content_calendar.app" "/Applications/Content Calendar.app"; do
  if [[ -d "$app" ]]; then
    if rm -rf "$app" 2>/dev/null; then
      echo "  Removed $app"
    else
      echo "  Could not remove $app (may need admin) — delete manually before installing."
    fi
  fi
done

OUTPUT="$("$PROJECT_ROOT/scripts/build-dmg-installer.sh")"
DMG_PATH="$(echo "$OUTPUT" | grep 'Installable DMG ready:' | sed 's/.*: //')"
if [[ -z "$DMG_PATH" || ! -f "$DMG_PATH" ]]; then
  echo "DMG build failed."
  exit 1
fi

echo "Opening DMG..."
open "$DMG_PATH"
