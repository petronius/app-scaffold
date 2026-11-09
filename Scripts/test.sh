#!/bin/bash
# test.sh [derived-data-path] [simulator-udid]: every test suite.
#
#   1. the core tests (`swift test` in Core): models, sync rules, formatting,
#      the store, the CloudKit mapping, and the formatting source scan;
#   2. the copy table against its generated Swift;
#   3. the app's own tests on an iOS simulator (launch options, the Library);
#   4. a build of the watch app.
#
# Pass your own derived-data path and simulator when several runs share the
# machine. Without a UDID the app tests run on the first available iPhone.
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED="${1:-/private/tmp/scaffold-dd-$USER}"
UDID="${2:-}"

echo "==> Core tests"
(cd Core && swift test 2>&1 | grep -E 'error:|✘|Test run with|failed' | tail -20; exit "${PIPESTATUS[0]}")

echo "==> Copy table"
Scripts/gen-copy.sh --check

echo "==> App tests"
xcodegen generate --quiet
if [ -z "$UDID" ]; then
    UDID=$(xcrun simctl list devices available -j | python3 -I -c "import json,sys;d=json.load(sys.stdin)['devices'];print(next(x['udid'] for k,v in d.items() if 'iOS' in k for x in v if x['name'].startswith('iPhone')))")
fi
set +e
xcodebuild test \
    -project Scaffold.xcodeproj -scheme Scaffold \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
    | grep -E '^\*\* TEST|error:|✘|Test run with|failed'
STATUS=${PIPESTATUS[0]}
set -e
[ "$STATUS" -eq 0 ] || exit "$STATUS"

echo "==> Watch build"
set +e
xcodebuild build \
    -project Scaffold.xcodeproj -scheme ScaffoldWatch \
    -destination 'generic/platform=watchOS Simulator' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
    | grep -E '^\*\* BUILD|error:'
STATUS=${PIPESTATUS[0]}
set -e
exit "$STATUS"
