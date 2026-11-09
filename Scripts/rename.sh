#!/bin/bash
# rename.sh: turn a fresh copy of the scaffold into a new project. Run it
# once, from a clean checkout, before the first commit of the new app.
#
#   Scripts/rename.sh --name "Field Notes" --product FieldNotes \
#       --bundle-id com.yourname.fieldnotes [--team ABCDE12345]
#
#   --name       the name people see: home screen, Library, copy table, docs
#   --product    the code name: targets, types, files. Letters and digits,
#                starting with a capital
#   --bundle-id  the app's bundle id. The App Group becomes group.<bundle-id>
#                and the iCloud container iCloud.<bundle-id>
#   --team       your Apple developer team id (optional; set later in
#                project.yml as DEVELOPMENT_TEAM)
#
# What it does, in order:
#   1. replaces com.example.scaffold with the bundle id, everywhere;
#   2. replaces "Scaffold" with the display name in the prose (docs/, Copy/,
#      spec/ and the top-level Markdown) and with the product name
#      everywhere else, "scaffold" and "SCAFFOLD" with its lower- and
#      upper-case forms;
#   3. sets DEVELOPMENT_TEAM, and the bundle id prefix in project.yml;
#   4. renames every file and folder whose name holds "Scaffold";
#   5. replaces README.md with a short README for the new project;
#   6. deletes the generated Scaffold.xcodeproj (gitignored, rebuilt by
#      xcodegen), regenerates the copy table's Swift and the Xcode project.
#
# It refuses to run twice: it checks that project.yml still says
# `name: Scaffold`. Review the diff before committing.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="" PRODUCT="" BUNDLE="" TEAM=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --name) NAME="$2"; shift 2 ;;
        --product) PRODUCT="$2"; shift 2 ;;
        --bundle-id) BUNDLE="$2"; shift 2 ;;
        --team) TEAM="$2"; shift 2 ;;
        *) echo "!!  unknown argument: $1 (see the header of this script)" >&2; exit 2 ;;
    esac
done

[ -n "$NAME" ] && [ -n "$PRODUCT" ] && [ -n "$BUNDLE" ] || {
    echo "!!  usage: rename.sh --name \"Display Name\" --product ProductName --bundle-id com.you.product [--team TEAMID]" >&2
    exit 2
}
[[ "$PRODUCT" =~ ^[A-Z][A-Za-z0-9]*$ ]] || { echo "!!  --product must be letters and digits, starting with a capital" >&2; exit 2; }
[[ "$BUNDLE" =~ ^[a-z0-9-]+(\.[a-z0-9-]+)+$ ]] || { echo "!!  --bundle-id must look like com.yourname.app, in lower case" >&2; exit 2; }
[[ -z "$TEAM" || "$TEAM" =~ ^[A-Z0-9]{10}$ ]] || { echo "!!  --team must be the ten-character team id" >&2; exit 2; }
grep -q '^name: Scaffold$' project.yml || { echo "!!  project.yml no longer says name: Scaffold; already renamed?" >&2; exit 1; }

LOWER=$(printf '%s' "$PRODUCT" | tr '[:upper:]' '[:lower:]')
UPPER=$(printf '%s' "$PRODUCT" | tr '[:lower:]' '[:upper:]')
PREFIX="${BUNDLE%.*}"
export NAME PRODUCT BUNDLE LOWER UPPER PREFIX

# Every text file we own: no git internals, build products, the generated
# project or binary files.
text_files() {
    find . \( -name .git -o -name .build -o -name DerivedData -o -name '*.xcodeproj' -o -name xcuserdata \) -prune \
        -o -type f ! -name '*.png' ! -name rename.sh -print | while read -r f; do
        if grep -Iq . "$f" 2>/dev/null; then echo "$f"; fi
    done
}

is_prose() {
    case "$1" in
        ./docs/*|./Copy/*|./spec/*|./*.md|./.taskbot/*.md) return 0 ;;
        *) return 1 ;;
    esac
}

echo "==> Rewriting names"
text_files | while read -r f; do
    perl -pi -e '
        s/\Qcom.example.scaffold\E/$ENV{BUNDLE}/g;
        s/\bcom\.example\b/$ENV{PREFIX}/g;
    ' "$f"
    if is_prose "$f"; then
        # Code in backticks takes the product name, the prose around it the
        # display name: "`Scaffold.xcodeproj`" and "Scaffold keeps your data".
        perl -pi -e '
            s{(`[^`]*`)|Scaffold}{defined $1 ? ($1 =~ s/Scaffold/$ENV{PRODUCT}/gr) : $ENV{NAME}}ge;
            s/scaffold/$ENV{LOWER}/g;
            s/SCAFFOLD/$ENV{UPPER}/g;
        ' "$f"
    else
        perl -pi -e '
            s/Scaffold/$ENV{PRODUCT}/g;
            s/scaffold/$ENV{LOWER}/g;
            s/SCAFFOLD/$ENV{UPPER}/g;
        ' "$f"
    fi
done

# The display name where the system shows it.
DISPLAY="$NAME" perl -pi -e 's/^(\s*CFBundleDisplayName:).*$/$1 "$ENV{DISPLAY}"/' project.yml
if [ -n "$TEAM" ]; then
    TEAM="$TEAM" perl -pi -e 's/^(\s*DEVELOPMENT_TEAM:).*$/$1 $ENV{TEAM}/' project.yml
fi

echo "==> Renaming files"
find . \( -name .git -o -name .build -o -name '*.xcodeproj' \) -prune -o -depth -name '*Scaffold*' -print | while read -r path; do
    dir=$(dirname "$path"); base=$(basename "$path")
    mv "$path" "$dir/${base//Scaffold/$PRODUCT}"
done

echo "==> Writing README.md"
cat > README.md <<EOF
# $NAME

<!-- One paragraph: what $NAME is and who it is for. SPEC.md holds the detail. -->

An iPhone, iPad and Apple Watch app. Local-first: each device keeps the data, and iCloud keeps the devices in step.

- \`SPEC.md\`: what the app does.
- \`CLAUDE.md\`: how the project is built and the rules every change follows.
- \`docs/\`: the Library, the user-facing manual bundled into the app.

## Build and test

\`\`\`bash
Scripts/build.sh
\`\`\`

\`\`\`bash
Scripts/test.sh
\`\`\`

## First run on a device

Simulator builds need none of this. A signed build on a device, and iCloud sync anywhere, need the identifiers registered with Apple (developer portal, Certificates, Identifiers & Profiles):

1. App IDs: \`$BUNDLE\`, \`$BUNDLE.widget\`, \`$BUNDLE.watchkitapp\`, \`$BUNDLE.watchkitapp.widget\`.
2. On every App ID: App Groups, with the group \`group.$BUNDLE\`.
3. On the app and the watch app: iCloud (CloudKit) with the container \`iCloud.$BUNDLE\`, and Push Notifications.
4. With automatic signing, Xcode can create most of this on the first device build; check the portal afterwards.
5. Before the first TestFlight build: create the app record in App Store Connect, run \`Scripts/cloudkit-schema.sh\`, and deploy the schema to Production in the CloudKit Console.
EOF

echo "==> Regenerating"
# The old generated project names the old targets; xcodegen writes a new one.
[ -d Scaffold.xcodeproj ] && rm -r Scaffold.xcodeproj
Scripts/gen-copy.sh
xcodegen generate --quiet

cat <<EOF
==> Renamed to $NAME ($PRODUCT, $BUNDLE).

Next:
  1. Review the diff, then commit.
  2. Before a device build: register the App IDs, App Group and iCloud
     container listed in README.md, "First run on a device".
  3. Write SPEC.md, then replace the Item example with the app's own model.
  4. Replace the placeholder icon: design/icon/README.md.
EOF
