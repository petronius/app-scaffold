#!/bin/bash
# testflight.sh [--archive-only]: archive Scaffold (phone app, watch app,
# complication and widget) for Release and upload it to TestFlight.
#
# Authentication uses an App Store Connect API key with Admin access (cloud
# signing mints the distribution certificate, which an App Manager key may
# not do). The key is the team's, so one key serves every app. The script
# reads it from the first of these files that exists, never from the
# repository:
#
#   $SCAFFOLD_ASC_ENV
#   ~/.scaffold-asc.env
#   ~/.asc.env
#
# The file exports ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (the
# AuthKey_*.p8 file, kept outside the repository). Variables already set in
# the environment win.
#
# The build number is a UTC timestamp, so every upload is unique and strictly
# increasing. The marketing version comes from project.yml.
#
# `--archive-only` archives and signs for Release and stops before the upload,
# to check signing and the App IDs without sending a build.
#
# Before the first upload: the app record exists in App Store Connect, and
# the CloudKit schema is deployed to Production (Scripts/cloudkit-schema.sh).
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE_ONLY=0
if [ "${1:-}" = "--archive-only" ]; then ARCHIVE_ONLY=1; fi

if [ -z "${ASC_KEY_ID:-}" ]; then
    for candidate in "${SCAFFOLD_ASC_ENV:-}" "$HOME/.scaffold-asc.env" "$HOME/.asc.env"; do
        if [ -n "$candidate" ] && [ -f "$candidate" ]; then
            echo "==> Reading the App Store Connect key settings from $candidate"
            # shellcheck disable=SC1090
            source "$candidate"
            break
        fi
    done
fi

: "${ASC_KEY_ID:?set ASC_KEY_ID (see the header of this script)}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
: "${ASC_KEY_PATH:?set ASC_KEY_PATH to the AuthKey_*.p8 file}"

# xcodebuild demands an absolute path to the key.
ASC_KEY_PATH="$(cd "$(dirname "$ASC_KEY_PATH")" && pwd)/$(basename "$ASC_KEY_PATH")"
[ -f "$ASC_KEY_PATH" ] || { echo "!!  key not found at $ASC_KEY_PATH" >&2; exit 1; }

BUILD=$(date -u +%Y%m%d%H%M)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
ARCHIVE="$WORK/Scaffold.xcarchive"
# A derived-data path of our own, thrown away with $WORK: the shared default
# can carry build descriptions from earlier project shapes.
DERIVED="$WORK/DerivedData"

echo "==> Regenerating project"
xcodegen generate --quiet

echo "==> Archiving (Release, build $BUILD)"
set +e
xcodebuild archive \
    -project Scaffold.xcodeproj -scheme Scaffold \
    -configuration Release -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    | grep -E '^\*\* ARCHIVE|error:|^ +note: '
ARCHIVE_STATUS=${PIPESTATUS[0]}
set -e
if [ "$ARCHIVE_STATUS" -ne 0 ]; then
    echo "!!  Archive failed (status $ARCHIVE_STATUS). Nothing uploaded." >&2
    exit "$ARCHIVE_STATUS"
fi

if [ "$ARCHIVE_ONLY" -eq 1 ]; then
    echo "==> Archive of build $BUILD signed. Not uploaded (--archive-only)."
    exit 0
fi

echo "==> Signing and uploading to App Store Connect"
set +e
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist ExportOptions.plist \
    -exportPath "$WORK/export" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    | grep -Ei 'Upload succeeded|EXPORT SUCCEEDED|error:'
EXPORT_STATUS=${PIPESTATUS[0]}
set -e
if [ "$EXPORT_STATUS" -ne 0 ]; then
    echo "!!  Export or upload failed (status $EXPORT_STATUS). Build $BUILD was NOT submitted." >&2
    echo "    Needed: an app record for com.example.scaffold in App Store Connect," >&2
    echo "    and an API key with Admin access." >&2
    exit "$EXPORT_STATUS"
fi

echo "==> Submitted build $BUILD. Apple processes it for 10 to 60 min; it then"
echo "    appears on the app's TestFlight tab."
