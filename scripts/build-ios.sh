#!/usr/bin/env bash
#
# build-ios.sh
#
# Compiles the iOS app target via xcodebuild for the iOS Simulator SDK.
# Catches compile errors that `swift test` cannot — anything that uses
# UIKit, SwiftUI iOS-only APIs, or depends on the Xcode app's monolithic
# module structure (e.g., the #if SWIFT_PACKAGE-gated imports in Runtime).
#
# Quiet on success (one-line summary). Verbose dump on failure (whole log).
#
# Use `generic/platform=iOS Simulator` to avoid pinning a specific device
# that Apple may rename across Xcode versions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

if xcodebuild build \
    -scheme MorseBeacon \
    -project MorseBeacon.xcodeproj \
    -destination 'generic/platform=iOS Simulator' \
    -quiet \
    CODE_SIGNING_ALLOWED=NO \
    > "$LOG" 2>&1
then
    echo "iOS build: OK (Debug, generic iOS Simulator)"
else
    echo "iOS build: FAILED"
    echo "---- xcodebuild output ----"
    cat "$LOG"
    exit 1
fi
