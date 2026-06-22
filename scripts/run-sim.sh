#!/usr/bin/env bash
#
# Build Budgetapp, boot an iOS Simulator, install, launch, and screenshot.
# macOS + Xcode 16 only. Nothing here runs automatically — invoke it yourself:
#
#   scripts/run-sim.sh                 # default: iPhone 16
#   scripts/run-sim.sh "iPhone 16 Pro" # pick a device
#
set -euo pipefail

SCHEME="Budgetapp"
PROJECT="Budgetapp.xcodeproj"
SIMULATOR="${1:-iPhone 16}"
DERIVED="build"
BUNDLE_ID="com.tanay.Budgetapp"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"

cd "$(dirname "$0")/.."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild not found." >&2
  echo "Install Xcode 16+, then: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

echo "▸ Building Budgetapp for '$SIMULATOR'…"
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -derivedDataPath "$DERIVED"

echo "▸ Booting simulator…"
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
open -a Simulator

echo "▸ Installing and launching…"
xcrun simctl install booted "$APP"
xcrun simctl launch booted "$BUNDLE_ID"

# Give the app a moment to render, then capture a screenshot.
sleep 3
mkdir -p "$DERIVED"
if xcrun simctl io booted screenshot "$DERIVED/screenshot.png" 2>/dev/null; then
  echo "▸ Saved screenshot to $DERIVED/screenshot.png"
fi
echo "▸ Done."
