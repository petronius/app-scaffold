#!/bin/bash
# gh-labels.sh: give the repository's GitHub issues the two labels
# CLAUDE.md names ("GitHub issues") and no others:
#
#   draft                   grey   an idea or deferred feature still being shaped
#   ready for development   green  specified well enough to build as it stands
#
# Each is created, or recoloured and redescribed if it exists. A label
# named `ready for build`, the old name of the second, is renamed, so the
# issues carrying it keep it; if both names exist, its issues move to the
# new one first. Every other label is then deleted, which takes it off
# every issue that carried it. Run it once on every new repository, and
# again whenever a label has crept in.
#
# Needs the GitHub CLI, signed in with access to the repository
# (`gh auth status`). `--dry-run` lists what it would change.
set -euo pipefail
cd "$(dirname "$0")/.."

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1
run() { if [ "$DRY" -eq 1 ]; then echo "    would run: $*"; else "$@"; fi; }

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
DRAFT="draft"
READY="ready for development"
OLD_READY="ready for build"
GREY=cfd3d7
GREEN=0e8a16

labels=$(gh label list --repo "$REPO" --limit 500 --json name -q '.[].name')
has() { printf '%s\n' "$labels" | grep -qxF "$1"; }

echo "==> Labels of $REPO"
if has "$OLD_READY" && ! has "$READY"; then
    echo "==> Renaming \"$OLD_READY\" to \"$READY\""
    run gh label edit "$OLD_READY" --repo "$REPO" --name "$READY"
    labels=$(printf '%s\n' "$labels" | sed "s/^$OLD_READY\$/$READY/")
elif has "$OLD_READY"; then
    for n in $(gh issue list --repo "$REPO" --label "$OLD_READY" --state all --limit 1000 --json number -q '.[].number'); do
        echo "==> Issue #$n: \"$OLD_READY\" becomes \"$READY\""
        run gh issue edit "$n" --repo "$REPO" --add-label "$READY" --remove-label "$OLD_READY"
    done
fi

run gh label create "$DRAFT" --repo "$REPO" --color "$GREY" --force \
    --description "An idea or deferred feature still being shaped"
run gh label create "$READY" --repo "$REPO" --color "$GREEN" --force \
    --description "Specified well enough to build as it stands"

printf '%s\n' "$labels" | while IFS= read -r name; do
    [ -n "$name" ] || continue
    case "$name" in
        "$DRAFT"|"$READY") ;;
        *)
            echo "==> Deleting the label \"$name\""
            run gh label delete "$name" --repo "$REPO" --yes
            ;;
    esac
done
echo "==> $REPO has two labels: \"$DRAFT\" (grey) and \"$READY\" (green)"
