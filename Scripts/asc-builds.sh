#!/bin/bash
# asc-builds.sh: every build of the app uploaded to App Store Connect, one per
# line: the build number, a space, and the upload time in seconds since 1970.
# Scripts/release-notes.sh backfill reads it.
#
# It signs an App Store Connect API token with the team's key, which it reads
# the way Scripts/testflight.sh does (Scripts/asc-env.sh), and needs openssl,
# curl and python3, all on a Mac with Xcode.
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck source=Scripts/asc-env.sh
source Scripts/asc-env.sh

BUNDLE_ID=$(sed -n 's/^ *PRODUCT_BUNDLE_IDENTIFIER: *//p' project.yml | head -1 | tr -d "\"'")
[ -n "$BUNDLE_ID" ] || { echo "!!  no PRODUCT_BUNDLE_IDENTIFIER in project.yml" >&2; exit 1; }
API=https://api.appstoreconnect.apple.com/v1

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

# An ES256 JSON Web Token for the API, valid for 15 minutes. openssl signs in
# DER, a sequence of two integers; the token wants r and s as 32 bytes each.
token() {
    local now header payload signature
    now=$(date +%s)
    header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | b64url)
    payload=$(printf '{"iss":"%s","iat":%d,"exp":%d,"aud":"appstoreconnect-v1"}' \
        "$ASC_ISSUER_ID" "$now" $((now + 900)) | b64url)
    signature=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -sign "$ASC_KEY_PATH" | python3 -I -c '
import base64, sys
der = sys.stdin.buffer.read()
r_len = der[3]
r = der[4:4 + r_len]
s = der[6 + r_len:6 + r_len + der[5 + r_len]]
raw = r[-32:].rjust(32, b"\0") + s[-32:].rjust(32, b"\0")
print(base64.urlsafe_b64encode(raw).decode().rstrip("="))')
    printf '%s.%s.%s' "$header" "$payload" "$signature"
}

TOKEN=$(token)
api() { curl -sSf -H "Authorization: Bearer $TOKEN" "$1"; }

APP_ID=$(api "$API/apps?filter%5BbundleId%5D=$BUNDLE_ID&fields%5Bapps%5D=bundleId" \
    | python3 -I -c 'import json, sys; d = json.load(sys.stdin)["data"]; print(d[0]["id"] if d else "")')
if [ -z "$APP_ID" ]; then
    echo "==> No app record for $BUNDLE_ID in App Store Connect, so no builds." >&2
    exit 0
fi

url="$API/builds?filter%5Bapp%5D=$APP_ID&limit=200&fields%5Bbuilds%5D=version,uploadedDate"
while [ -n "$url" ]; do
    page=$(api "$url")
    printf '%s' "$page" | python3 -I -c '
import datetime, json, sys
for build in json.load(sys.stdin)["data"]:
    a = build["attributes"]
    when = datetime.datetime.fromisoformat(a["uploadedDate"].replace("Z", "+00:00"))
    print(a["version"], int(when.timestamp()))'
    url=$(printf '%s' "$page" | python3 -I -c 'import json, sys; print(json.load(sys.stdin).get("links", {}).get("next", ""))')
done
