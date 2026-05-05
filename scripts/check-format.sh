#!/usr/bin/env bash
#
# check-format.sh
#
# Lints all Swift files against .swift-format with --strict (warnings
# escalate to non-zero exit). Use as a CI gate; locally, run
# scripts/format.sh first to auto-fix.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

ROOTS=(MorseBeacon MorseBeaconTests Package.swift)

FILES=()
for root in "${ROOTS[@]}"; do
    if [[ -d "$root" ]]; then
        while IFS= read -r f; do FILES+=("$f"); done < <(find "$root" -name '*.swift' -type f)
    elif [[ -f "$root" ]]; then
        FILES+=("$root")
    fi
done

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "check-format.sh: no Swift files found"
    exit 0
fi

if xcrun swift-format lint --strict -p --configuration .swift-format "${FILES[@]}"; then
    echo "Format check: OK (${#FILES[@]} files clean)"
else
    echo
    echo "Format check: FAILED"
    echo "Run ./scripts/format.sh to auto-fix."
    exit 1
fi
