#!/usr/bin/env bash
#
# measure-core-coverage.sh
#
# Runs Core tests with coverage and prints the per-file report.
# Used for NFR-3 verification (Core/ must have ≥90% line coverage).
#
# See: TASKS 1.7.1, docs/coverage.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

swift test --enable-code-coverage > /dev/null 2>&1

BIN_PATH=$(swift build --show-bin-path)
PROF="${BIN_PATH}/codecov/default.profdata"
TEST_BIN="${BIN_PATH}/MorseBeaconCorePackageTests.xctest/Contents/MacOS/MorseBeaconCorePackageTests"

if [[ ! -f "$PROF" || ! -f "$TEST_BIN" ]]; then
    echo "ERROR: coverage artifacts not found. Did 'swift test' succeed?"
    exit 2
fi

xcrun llvm-cov report "$TEST_BIN" \
    -instr-profile="$PROF" \
    -ignore-filename-regex="Tests|.build"
