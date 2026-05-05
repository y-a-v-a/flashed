#!/usr/bin/env bash
#
# check-all.sh
#
# Runs every local quality gate in dependency order and stops at the
# first failure. Mirrors what CI does. Intended as a pre-commit /
# pre-push sanity check.
#
# Order is chosen so cheap checks run first (fail fast):
#   1. Architecture rules (grep, ~ms)
#   2. Core+Runtime unit tests via SwiftPM (~300 ms)
#   3. iOS Simulator compile (~30-60 s, the slow one)
#   4. Xcode unit-test bundle (~minutes — only run when 1-3 pass)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

step() {
    echo
    echo "=== $1 ==="
}

step "Core purity"
./scripts/check-core-purity.sh

step "Screen isolation"
./scripts/check-screen-isolation.sh

step "SwiftPM unit tests"
swift test --quiet 2>&1 | grep -E 'Executed [0-9]+ test' | tail -1
# Re-exit with swift test's actual status (the pipe above masks it):
SWIFT_TEST_STATUS=${PIPESTATUS[0]}
if [[ $SWIFT_TEST_STATUS -ne 0 ]]; then
    echo "SwiftPM tests FAILED"
    exit $SWIFT_TEST_STATUS
fi

step "iOS Simulator build"
./scripts/build-ios.sh

# Xcode tests are slow because they boot a simulator. Only run on
# explicit opt-in via the env var, otherwise skip.
if [[ "${RUN_IOS_TESTS:-0}" == "1" ]]; then
    step "iOS Simulator tests"
    ./scripts/test-ios.sh
else
    echo
    echo "(skipping iOS Simulator tests — set RUN_IOS_TESTS=1 to enable)"
fi

echo
echo "All checks passed."
