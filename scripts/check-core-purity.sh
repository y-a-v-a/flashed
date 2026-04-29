#!/usr/bin/env bash
#
# check-core-purity.sh
#
# Enforces CLAUDE.md / LAYOUT.md / PRD §6 rule:
#   MorseBeacon/Core/ is pure Swift. No UIKit, SwiftUI, Combine, Dispatch,
#   Foundation timers, CoreFoundation runloops, or any other platform-bound
#   API. Int milliseconds only; deterministic.
#
# Exit 0 on success (Core is clean), non-zero on any violation.
#
# See: TASKS 0.9, 1.7.2.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="${SCRIPT_DIR}/../MorseBeacon/Core"

if [[ ! -d "${CORE_DIR}" ]]; then
    echo "ERROR: Core directory not found at ${CORE_DIR}"
    exit 2
fi

# Plain-string patterns. Each is forbidden anywhere in any .swift file under Core/.
FORBIDDEN_LITERAL=(
    'import UIKit'
    'import SwiftUI'
    'import Combine'
    'import Dispatch'
    'Foundation.Timer'
    'NSTimer'
    'DispatchQueue'
    'DispatchSource'
    'DispatchTime'
    'CFAbsoluteTime'
    'CFRunLoop'
    'RunLoop.'
)

# Regex patterns for cases needing word-boundary handling (avoid false positives
# from legitimate names like "TimingProfile" colliding with "Timer").
FORBIDDEN_REGEX=(
    '\bTimer\('     # Timer(...) constructor; matches Timer( but not TimerProfile
)

EXIT_CODE=0
VIOLATIONS=0

check_pattern() {
    local pattern="$1"
    local mode="$2"   # "literal" or "regex"
    local matches

    if [[ "$mode" == "literal" ]]; then
        matches=$(grep -rn --include='*.swift' -F "$pattern" "$CORE_DIR" 2>/dev/null || true)
    else
        matches=$(grep -rn --include='*.swift' -E "$pattern" "$CORE_DIR" 2>/dev/null || true)
    fi

    if [[ -n "$matches" ]]; then
        echo "FORBIDDEN PATTERN '$pattern' in Core/:"
        echo "$matches" | sed 's/^/  /'
        echo
        EXIT_CODE=1
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
}

for p in "${FORBIDDEN_LITERAL[@]}"; do
    check_pattern "$p" literal
done

for p in "${FORBIDDEN_REGEX[@]}"; do
    check_pattern "$p" regex
done

FILE_COUNT=$(find "$CORE_DIR" -name '*.swift' -type f | wc -l | tr -d ' ')

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "Core purity check: OK"
    echo "  ${FILE_COUNT} Swift file(s) in Core/, no forbidden patterns found."
else
    echo "Core purity check: FAILED"
    echo "  ${VIOLATIONS} forbidden pattern(s) found in Core/."
fi

exit $EXIT_CODE
