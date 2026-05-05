#!/usr/bin/env bash
#
# test-ios.sh
#
# Runs the Xcode unit-test target on the iOS Simulator. Currently only
# the placeholder MorseBeaconTests.swift; this script exists so that
# when iOS-only tests appear (UI snapshots, on-device timing per task
# 2.2.10, etc.) the invocation is already standardised.
#
# Picks the first available iPhone simulator runtime so the script
# works across Xcode versions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

# Find the first iPhone simulator name available on this host. macOS
# (BSD) sed doesn't support \s — use [[:space:]] explicitly.
SIMULATOR=$(xcrun simctl list devices available 2>/dev/null \
    | grep -E '^[[:space:]]+iPhone ' \
    | head -1 \
    | sed -E 's/^[[:space:]]+(iPhone [^(]+) \(.*$/\1/' \
    | sed -E 's/[[:space:]]+$//')

if [[ -z "${SIMULATOR}" ]]; then
    echo "ERROR: no iPhone simulator available."
    echo "Install an iOS runtime: xcodebuild -downloadPlatform iOS"
    exit 2
fi

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

if xcodebuild test \
    -scheme MorseBeacon \
    -project MorseBeacon.xcodeproj \
    -destination "platform=iOS Simulator,name=${SIMULATOR}" \
    -quiet \
    CODE_SIGNING_ALLOWED=NO \
    > "$LOG" 2>&1
then
    echo "iOS tests: OK (${SIMULATOR})"
else
    echo "iOS tests: FAILED on ${SIMULATOR}"
    echo "---- xcodebuild output ----"
    cat "$LOG"
    exit 1
fi
