#!/bin/bash
# testflight.sh [--archive-only]: archive Scaffold (phone app, watch app,
# complication and widget) for Release and upload it to TestFlight.
#
# Authentication uses the team's App Store Connect API key, which
# Scripts/asc-env.sh reads (see its header).
#
# The build number is a UTC timestamp, so every upload is unique and strictly
# increasing. The marketing version comes from project.yml.
#
# Every upload carries its release notes (Scripts/release-notes.sh): the
# commits since the last build tag become the build's article in the
# Library's Release notes section before the archive, so the build bundles
# them, and after a successful upload the built commit is tagged
# build/<build number> and the article committed and pushed. A failed
# archive or upload takes the article back out. With no build tag yet, the
# release notes of every earlier build are written first, from the builds
# App Store Connect lists.
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

# shellcheck source=Scripts/asc-env.sh
source Scripts/asc-env.sh

if [ "$ARCHIVE_ONLY" -eq 0 ]; then
    git fetch -q --tags origin || echo "!!  Could not fetch the build tags from origin." >&2
    if ! Scripts/release-notes.sh has-builds; then Scripts/release-notes.sh backfill; fi
    Scripts/release-notes.sh preview
fi

BUILD=$(date -u +%Y%m%d%H%M)
WORK=$(mktemp -d)
STAMPED=0
cleanup() {
    if [ "$STAMPED" -eq 1 ]; then Scripts/release-notes.sh unstamp "$BUILD"; fi
    rm -rf "$WORK"
}
trap cleanup EXIT
ARCHIVE="$WORK/Scaffold.xcarchive"
# A derived-data path of our own, thrown away with $WORK: the shared default
# can carry build descriptions from earlier project shapes.
DERIVED="$WORK/DerivedData"

echo "==> Regenerating project"
xcodegen generate --quiet

if [ "$ARCHIVE_ONLY" -eq 0 ]; then
    VERSION=$(sed -n 's/^ *MARKETING_VERSION: *//p' project.yml | head -1 | tr -d "\"'")
    Scripts/release-notes.sh stamp "$BUILD" "$VERSION"
    STAMPED=1
fi

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

STAMPED=0
Scripts/release-notes.sh publish "$BUILD" \
    || echo "!!  Build $BUILD is uploaded, but its release notes were not committed. Commit them by hand." >&2

echo "==> Submitted build $BUILD. Apple processes it for 10 to 60 min; it then"
echo "    appears on the app's TestFlight tab."
