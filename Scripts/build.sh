#!/bin/bash
# build.sh [derived-data-path]: regenerate the Xcode project and build the
# phone app (with the embedded watch app, the complication and the widget)
# for the iOS simulator, Debug, signed ad hoc. Pass a derived-data path of your
# own when several builds run at once; the default is
# /private/tmp/scaffold-dd-$USER.
#
# Ad hoc, never CODE_SIGNING_ALLOWED=NO: an unsigned build carries no
# entitlements, and CloudKit traps at launch without the iCloud one. Ad hoc
# signing needs no team and keeps the simulated entitlements in the binary.
#
# Prints the built .app path on the last line.
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED="${1:-/private/tmp/scaffold-dd-$USER}"
xcodegen generate --quiet

set +e
xcodebuild build \
    -project Scaffold.xcodeproj -scheme Scaffold \
    -configuration Debug -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
    | grep -E '^\*\* BUILD|error:|warning: .*(deprecated|unused)|^ +note: '
STATUS=${PIPESTATUS[0]}
set -e
[ "$STATUS" -eq 0 ] || exit "$STATUS"
echo "$DERIVED/Build/Products/Debug-iphonesimulator/Scaffold.app"
