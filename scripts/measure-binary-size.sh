#!/usr/bin/env bash
#
# measure-binary-size.sh
#
# NFR-4: "App binary size target: < 5 MB."
#
# Measures the size of the built MorseBeacon.app bundle in
# DerivedData (Release config — Debug builds carry symbols and are
# always larger than ship size).
#
# Builds Release if no Release artifact exists yet. Reports a
# non-zero exit code if the binary exceeds the threshold.
#
# See: TASKS 6.5.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

THRESHOLD_BYTES=$((5 * 1024 * 1024))   # 5 MB

# Build Release into a temp DerivedData so we don't disturb Debug builds
# the dev loop is using.
DERIVED=$(mktemp -d)
trap 'rm -rf "$DERIVED"' EXIT

echo "Building Release into $DERIVED..."
xcodebuild build \
  -scheme MorseBeacon \
  -project MorseBeacon.xcodeproj \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -quiet \
  CODE_SIGNING_ALLOWED=NO \
  > /dev/null 2>&1

APP=$(find "$DERIVED" -name 'MorseBeacon.app' -path '*Release-iphonesimulator*' | head -1)
if [[ -z "$APP" ]]; then
  echo "ERROR: MorseBeacon.app not found in DerivedData after Release build"
  exit 2
fi

# du -sk gives KB; we convert to bytes for the threshold compare.
KB=$(du -sk "$APP" | awk '{print $1}')
BYTES=$((KB * 1024))

# Pretty-print human-readable size.
HUMAN=$(du -sh "$APP" | awk '{print $1}')

echo
echo "Binary size: $HUMAN ($BYTES bytes)"
echo "Threshold:   5 MB ($THRESHOLD_BYTES bytes)"

if [[ $BYTES -gt $THRESHOLD_BYTES ]]; then
  echo "Binary size: FAILED (exceeds 5 MB)"
  exit 1
fi

echo "Binary size: OK"
