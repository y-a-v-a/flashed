#!/usr/bin/env bash
#
# check-screen-isolation.sh
#
# Enforces CLAUDE.md / LAYOUT.md rule (sharpened during TASKS 2.1):
#   The ONLY file in the codebase permitted to reference `UIScreen` or
#   `isIdleTimerDisabled` is MorseBeacon/Runtime/UIKitScreenProxy.swift.
#
# This is tighter than the original rule ("only ScreenController") because
# the controller is now pure logic and delegates to a ScreenProxy. All
# UIKit screen-twiddling lives behind the proxy, in one file.
#
# Exit 0 if the rule holds, non-zero on any violation.
#
# See: TASKS 0.10, 2.1.3.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/../MorseBeacon"
ALLOWED_FILE="${APP_DIR}/Runtime/UIKitScreenProxy.swift"

if [[ ! -d "${APP_DIR}" ]]; then
    echo "ERROR: app directory not found at ${APP_DIR}"
    exit 2
fi

# Match the qualified UIKit access patterns specifically. The bare names
# `UIScreen` and `isIdleTimerDisabled` legitimately appear in doc comments
# and on our own ScreenProxy protocol — those are not violations of the rule.
# The rule is about UIKit *usage*, which always goes through one of:
#   - `UIScreen.` (e.g., UIScreen.main)
#   - `UIApplication.shared.isIdleTimerDisabled`
PATTERNS=(
    'UIScreen.'
    'UIApplication.shared.isIdleTimerDisabled'
)

EXIT_CODE=0

for pattern in "${PATTERNS[@]}"; do
    # Find any .swift file under MorseBeacon/ that contains the pattern,
    # excluding the single allowed file.
    matches=$(grep -rln --include='*.swift' -F "$pattern" "$APP_DIR" 2>/dev/null \
        | grep -v -F "$ALLOWED_FILE" || true)

    if [[ -n "$matches" ]]; then
        echo "FORBIDDEN: '$pattern' found outside UIKitScreenProxy.swift:"
        while IFS= read -r file; do
            echo "  $file"
            grep -n -F "$pattern" "$file" | sed 's/^/    /'
        done <<< "$matches"
        echo
        EXIT_CODE=1
    fi
done

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "Screen isolation check: OK"
    echo "  UIScreen / isIdleTimerDisabled appear only in UIKitScreenProxy.swift"
fi

exit $EXIT_CODE
