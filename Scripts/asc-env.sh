# asc-env.sh: sourced by Scripts/testflight.sh and Scripts/asc-builds.sh. It
# loads the App Store Connect API key with Admin access (cloud signing mints
# the distribution certificate, which an App Manager key may not do). The key
# is the team's, so one key serves every app. It is read from the first of
# these files that exists, never from the repository:
#
#   $SCAFFOLD_ASC_ENV
#   ~/.scaffold-asc.env
#   ~/.asc.env
#
# The file exports ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (the
# AuthKey_*.p8 file, kept outside the repository). Variables already set in
# the environment win.

if [ -z "${ASC_KEY_ID:-}" ]; then
    for candidate in "${SCAFFOLD_ASC_ENV:-}" "$HOME/.scaffold-asc.env" "$HOME/.asc.env"; do
        if [ -n "$candidate" ] && [ -f "$candidate" ]; then
            echo "==> Reading the App Store Connect key settings from $candidate" >&2
            # shellcheck disable=SC1090
            source "$candidate"
            break
        fi
    done
fi

: "${ASC_KEY_ID:?set ASC_KEY_ID (see the header of Scripts/asc-env.sh)}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
: "${ASC_KEY_PATH:?set ASC_KEY_PATH to the AuthKey_*.p8 file}"

# xcodebuild demands an absolute path to the key.
ASC_KEY_PATH="$(cd "$(dirname "$ASC_KEY_PATH")" && pwd)/$(basename "$ASC_KEY_PATH")"
[ -f "$ASC_KEY_PATH" ] || { echo "!!  key not found at $ASC_KEY_PATH" >&2; exit 1; }
export ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH
