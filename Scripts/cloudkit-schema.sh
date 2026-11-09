#!/bin/bash
# cloudkit-schema.sh [--validate]: put the checked-in CloudKit schema
# (Scripts/cloudkit-schema.ckdb, the record types the iCloud sync writes)
# into the container's Development environment, or only validate the file.
#
# CloudKit creates record types on its own only in Development, and only
# from whatever record a debug build happens to save first. This script makes
# the file the source of truth instead: every type and field, reviewable in a
# diff, imported in one step. Production cannot be written from here: Apple's
# cktool has no deploy-to-production command. After the import, promote
# Development to Production in the CloudKit Console (Schema, Deploy Schema
# Changes) before the TestFlight build that needs it goes out. That promotion
# is additive only: a deployed type or field can never be removed or retyped,
# so get the file right before promoting.
#
# The file is the whole schema, not a patch: an import replaces Development
# with what the file holds, so a type missing from it is a request to delete
# that type, and a type deployed to Production can never be deleted. Keep
# retired types in the file.
#
# Needs a one-time management token: `xcrun cktool save-token` opens the
# Console to mint one and stores it in the keychain. TEAM_ID defaults to
# DEVELOPMENT_TEAM in project.yml.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEMA="$SCRIPT_DIR/cloudkit-schema.ckdb"
DEFAULT_TEAM=$(sed -n 's/^ *DEVELOPMENT_TEAM: *"\{0,1\}\([A-Z0-9]*\)"\{0,1\}$/\1/p' "$ROOT/project.yml" | head -1)
TEAM_ID="${TEAM_ID:-$DEFAULT_TEAM}"
CONTAINER_ID="${CONTAINER_ID:-iCloud.com.example.scaffold}"

[ -n "$TEAM_ID" ] || { echo "!!  set TEAM_ID, or DEVELOPMENT_TEAM in project.yml" >&2; exit 1; }

if [ "${1:-}" = "--validate" ]; then
    xcrun cktool validate-schema --team-id "$TEAM_ID" --container-id "$CONTAINER_ID" \
        --environment development --file "$SCHEMA"
    echo "==> $SCHEMA is valid for $CONTAINER_ID"
    exit 0
fi

xcrun cktool import-schema --team-id "$TEAM_ID" --container-id "$CONTAINER_ID" \
    --environment development --file "$SCHEMA"
echo "==> Imported into Development. Deploy to Production in the CloudKit Console"
echo "    (Schema, Deploy Schema Changes) before the TestFlight build that needs it."
