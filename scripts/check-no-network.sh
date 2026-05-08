#!/usr/bin/env bash
#
# check-no-network.sh
#
# NFR-2: "No network calls of any kind. No third-party SDKs. No analytics."
#
# Greps the entire app target source for any networking primitive. Exit 0
# if clean; non-zero on any hit.
#
# This is a static check — it can't catch dynamically-loaded frameworks
# at runtime, but for a project with no third-party deps and no
# Obj-C interop, the whole attack surface is what's typed in .swift
# files. Sufficient for the PRD's NFR-2.
#
# See: TASKS 6.7.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/../MorseBeacon"

if [[ ! -d "${APP_DIR}" ]]; then
  echo "ERROR: app directory not found at ${APP_DIR}"
  exit 2
fi

# Networking primitives. URL by itself is allowed (used for mailto: in
# AboutView), but URLSession / URLRequest / dataTask / etc. are not.
PATTERNS=(
  'URLSession'
  'URLRequest'
  'NSURLSession'
  'NSURLRequest'
  'dataTask'
  'downloadTask'
  'uploadTask'
  'CFHTTPMessage'
  'CFNetwork'
  'NSURLConnection'
  'import Network'
  'import CFNetwork'
  'URLProtocol'
)

EXIT_CODE=0

for pattern in "${PATTERNS[@]}"; do
  if matches=$(grep -rn --include='*.swift' -F "$pattern" "$APP_DIR" 2>/dev/null); then
    echo "FORBIDDEN: '$pattern' (network primitive) found in app target:"
    echo "$matches" | sed 's/^/  /'
    echo
    EXIT_CODE=1
  fi
done

if [[ $EXIT_CODE -eq 0 ]]; then
  FILE_COUNT=$(find "$APP_DIR" -name '*.swift' -type f | wc -l | tr -d ' ')
  echo "Network-free check: OK"
  echo "  ${FILE_COUNT} Swift file(s) in app target, no networking primitives found."
fi

exit $EXIT_CODE
