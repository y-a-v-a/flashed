#!/usr/bin/env bash
#
# format.sh
#
# Runs swift-format in-place across all .swift files in the project.
# Use this BEFORE committing if check-format.sh complains.
#
# swift-format ships with Xcode 14+; we invoke via xcrun for portability.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

# Roots to format. Excludes .build, DerivedData, and any third-party trees
# (we have none of those in v1, but the find expression is robust to it).
ROOTS=(
    MorseBeacon
    MorseBeaconTests
    Package.swift
)

FILES=()
for root in "${ROOTS[@]}"; do
    if [[ -d "$root" ]]; then
        while IFS= read -r f; do FILES+=("$f"); done < <(find "$root" -name '*.swift' -type f)
    elif [[ -f "$root" ]]; then
        FILES+=("$root")
    fi
done

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "format.sh: no Swift files found"
    exit 0
fi

xcrun swift-format format -i -p --configuration .swift-format "${FILES[@]}"
echo "Formatted ${#FILES[@]} Swift file(s)."
