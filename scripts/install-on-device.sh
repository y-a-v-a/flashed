#!/usr/bin/env bash
#
# install-on-device.sh
#
# The no-App-Store path: build a Debug copy signed with your development
# team, then install + launch it on a connected iPhone via `devicectl`
# (Xcode 15+). One-time device setup (Developer Mode, trusting the
# certificate) and the free-account limits are documented in
# docs/install-on-device.md.
#
# Usage:
#   TEAM_ID=ABCDE12345 BUNDLE_ID=com.you.morsebeacon ./scripts/install-on-device.sh
#   ./scripts/install-on-device.sh          # once the project remembers signing
#
#   TEAM_ID    10-char Apple Developer team ID. Optional if a team is
#              already set in the project via Xcode.
#   BUNDLE_ID  Override com.example.morsebeacon. Free-tier App IDs are
#              global-first-come-first-served, so pick your own.
#   DEVICE     devicectl device identifier. Optional when exactly one
#              device is connected; list with `xcrun devicectl list devices`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

if ! command -v xcrun >/dev/null 2>&1; then
    echo "install-on-device.sh: xcrun not found — this script needs macOS with Xcode 15+." >&2
    exit 2
fi

BUNDLE_ID="${BUNDLE_ID:-com.example.morsebeacon}"

# Resolve the target device. devicectl prints identifiers as UUIDs; with
# exactly one device connected we can pick it up without parsing columns.
if [[ -z "${DEVICE:-}" ]]; then
    DEVICES=()
    while IFS= read -r id; do DEVICES+=("$id"); done < <(
        xcrun devicectl list devices 2>/dev/null \
            | grep -Eio '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' \
            | sort -u
    )
    if [[ ${#DEVICES[@]} -eq 0 ]]; then
        echo "install-on-device.sh: no device found. Connect the iPhone (unlocked," >&2
        echo "trusted, Developer Mode on) and check: xcrun devicectl list devices" >&2
        exit 1
    elif [[ ${#DEVICES[@]} -gt 1 ]]; then
        echo "install-on-device.sh: multiple devices found — set DEVICE=<identifier>:" >&2
        xcrun devicectl list devices >&2
        exit 1
    fi
    DEVICE="${DEVICES[0]}"
fi

DERIVED="build/install-on-device"
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

echo "Building for device (signing team: ${TEAM_ID:-project default})..."
if xcodebuild build \
    -scheme MorseBeacon \
    -project MorseBeacon.xcodeproj \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    -quiet \
    ${TEAM_ID:+DEVELOPMENT_TEAM="$TEAM_ID"} \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    > "$LOG" 2>&1
then
    echo "Build: OK"
else
    echo "Build: FAILED"
    echo "---- xcodebuild output ----"
    cat "$LOG"
    echo "Signing problems? See docs/install-on-device.md (TEAM_ID, unique BUNDLE_ID)." >&2
    exit 1
fi

APP="${DERIVED}/Build/Products/Debug-iphoneos/MorseBeacon.app"
if [[ ! -d "$APP" ]]; then
    echo "install-on-device.sh: built app not found at ${APP}" >&2
    exit 1
fi

echo "Installing on ${DEVICE}..."
xcrun devicectl device install app --device "$DEVICE" "$APP"

# Launch is best-effort: it fails harmlessly if the phone is locked or
# the developer certificate hasn't been trusted yet.
if xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1; then
    echo "Installed and launched ${BUNDLE_ID}."
else
    echo "Installed ${BUNDLE_ID}. Launch it from the home screen — first time:"
    echo "Settings → General → VPN & Device Management → Trust."
fi
