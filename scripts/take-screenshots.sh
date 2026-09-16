#!/usr/bin/env bash
#
# take-screenshots.sh
#
# Captures the App Store screenshot set headlessly. Outputs to
# docs/screenshots/, one PNG per app screen. Reproducible — re-run
# any time the UI changes.
#
# All five screens are reachable via MB_LAUNCH_TO env-var routes
# (DEBUG builds only; see MorseBeaconApp.swift). The script handles
# state setup (UserDefaults writes for safety acknowledgement,
# sample message text, settings) so each capture is isolated.
#
# Output naming: 1-input.png, 2-beacon.png, etc. — matches the
# numbering in docs/app-store.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

# simctl io needs absolute paths for the screenshot output (it appears to
# resolve relative to its own working dir, which isn't ours).
OUT_DIR="$(pwd)/docs/screenshots"
mkdir -p "$OUT_DIR"

# Build first so the .app exists and is fresh.
./scripts/build-ios.sh

# The bundle ID lives in the pbxproj so this script keeps working after the
# placeholder is replaced with the real one.
BUNDLE_ID=$(grep -m1 -E 'PRODUCT_BUNDLE_IDENTIFIER = [^;]*;' MorseBeacon.xcodeproj/project.pbxproj \
  | sed -E 's/.*= (.*);/\1/')

# App Store Connect requires the 6.9" iPhone size (1320x2868) and accepts
# nothing smaller as the mandatory set, so prefer a Pro Max simulator.
# Override with SIM=<udid>.
SIM="${SIM:-}"
if [[ -z "$SIM" ]]; then
  SIM=$(xcrun simctl list devices available | grep -E '^[[:space:]]+iPhone [0-9]+ Pro Max ' | head -1 \
    | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/' || true)
fi
if [[ -z "$SIM" ]]; then
  SIM=$(xcrun simctl list devices available | grep -E '^[[:space:]]+iPhone ' | head -1 \
    | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/')
fi
if ! xcrun simctl list devices booted | grep -q "$SIM"; then
  echo "Booting simulator $SIM..."
  xcrun simctl boot "$SIM"
  sleep 3
fi

APP=$(find ~/Library/Developer/Xcode/DerivedData -name MorseBeacon.app \
  -path "*Debug-iphonesimulator*" 2>/dev/null | head -1)
if [[ -z "$APP" ]]; then
  echo "ERROR: MorseBeacon.app not found"
  exit 1
fi

xcrun simctl uninstall "$SIM" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"

capture() {
  local route="$1"
  local name="$2"
  local out="$OUT_DIR/$name.png"

  xcrun simctl terminate "$SIM" "$BUNDLE_ID" 2>/dev/null || true

  if [[ -n "$route" ]]; then
    SIMCTL_CHILD_MB_LAUNCH_TO="$route" xcrun simctl launch "$SIM" "$BUNDLE_ID" \
      > /dev/null
  else
    xcrun simctl launch "$SIM" "$BUNDLE_ID" > /dev/null
  fi

  # Generous settle time so SwiftUI completes the first render and
  # any animated content (countdown numericText, beacon flash) has a
  # representative state.
  sleep 2
  xcrun simctl io "$SIM" screenshot "$out" 2>&1 | tail -1
  echo "  → $out"
}

# Forward all args after the key so calls like `set_default key -bool YES`
# (3+ args) work the same as `set_default key value` (2 args).
set_default() {
  local key="$1"
  shift
  xcrun simctl spawn "$SIM" defaults write "$BUNDLE_ID" "$key" "$@" \
    >/dev/null 2>&1
}

set_default_int() {
  set_default "$1" -int "$2"
}

delete_default() {
  xcrun simctl spawn "$SIM" defaults delete "$BUNDLE_ID" "$1" 2>/dev/null || true
}

# 0. Photosensitivity warning (no ack stored). Default route.
echo "[0] Safety warning..."
delete_default safetyAcknowledgedV1
delete_default settings.lastMessage
capture "" "0-safety-warning"

# 1. Input view with sample message. Pre-ack and pre-fill.
echo "[1] Input..."
set_default safetyAcknowledgedV1 -bool YES
set_default settings.lastMessage "SOS HELP"
capture "input" "1-input"

# 2. Settings.
echo "[2] Settings (PARIS)..."
set_default settings.timingModel paris
set_default_int settings.characterWPM 12
capture "settings" "2-settings"

# 3. Countdown.
echo "[3] Countdown..."
capture "countdown" "3-countdown"

# 4. Beacon transmitting. The MB_LAUNCH_TO=beacon route uses a slow
# PARIS @ 5 WPM 'SOS PARIS' schedule (from MorseBeaconApp's previewSession),
# so a 2s delay catches a tick mid-flight.
echo "[4] Beacon..."
capture "beacon" "4-beacon"

# 5. Finished.
echo "[5] Finished..."
capture "finished" "5-finished"

# Cleanup
xcrun simctl terminate "$SIM" "$BUNDLE_ID" 2>/dev/null || true

echo
echo "All screenshots written to $OUT_DIR/"
ls -la "$OUT_DIR"
