#!/bin/bash
# release-notes.sh: the Library's release notes, written from git history.
# Scripts/testflight.sh runs it for every upload; it can be run by hand.
#
# A build's release notes are the commits since the build before it. Every
# uploaded commit is tagged build/<build number>, so the commits a build adds
# are <previous build tag>..<its own tag>. Each commit subject is a
# Conventional Commit (CLAUDE.md, "Git practice"):
#
#   feat: <summary>   a line under "New features"
#   fix: <summary>    a line under "Fixes"
#   any other type    one line for the whole build under "Other changes":
#                     "Maintenance and performance improvements"
#
# A scope (`feat(tuner): ...`) is allowed and not shown. Merge commits and
# this script's own `chore(release)` commits are skipped. Commits made before
# the convention are classified in Scripts/release-notes-history.tsv (full
# sha, then feat, fix, internal or release, then the line), which wins over
# the subject; a release commit is skipped like a `chore(release)` one. Any other subject without a type counts as maintenance, and the
# script names it so the gap is seen.
#
#   release-notes.sh preview
#       The notes the next build will carry: HEAD since the last build tag.
#   release-notes.sh stamp <build> <version>
#       Writes docs/release-notes/build-<build>.md for HEAD and lists it in
#       docs/README.md, so the archive that follows bundles its own notes.
#       Fails when nothing was committed since the last build.
#   release-notes.sh unstamp <build>
#       Undoes stamp, for a build that was not uploaded.
#   release-notes.sh publish <build>
#       After a successful upload: tags HEAD build/<build>, commits the
#       article and the index as `chore(release)`, and pushes both. A failure
#       here never fails the upload; it says what to do by hand.
#   release-notes.sh has-builds
#       Succeeds when at least one build tag exists.
#   release-notes.sh backfill [<file>|-]
#       The notes for builds uploaded before the tags: one line per build,
#       "<build number> <upload time in seconds since 1970>", read from the
#       file, from stdin with "-", or fetched from App Store Connect
#       (Scripts/asc-builds.sh) with no argument. A build number that is a
#       timestamp needs no upload time; the article then takes its date.
#       Each build is tagged at the last commit on main before it was built:
#       the build number's own UTC minute where the number is a timestamp,
#       else its upload time. Then every build tagged here gets its article,
#       replacing one written before it had a tag, and the commit and the
#       tags are pushed.
#
# Written for the bash 3.2 and BSD tools macOS ships, and for Linux.
set -euo pipefail
cd "$(dirname "$0")/.."

DOCS=docs
INDEX="$DOCS/README.md"
SECTION_HEADING="## Release notes"
FOLDER="$DOCS/release-notes"
HISTORY=Scripts/release-notes-history.tsv
TAG_PREFIX=build/
RELEASE_SUBJECT="chore(release)"
MAINTENANCE="Maintenance and performance improvements"
# An index line as the rest of docs/README.md writes one: the separator
# between the link and the description, the description (version, then
# date) and what ends the line.
INDEX_SEPARATOR=": "
INDEX_DESCRIPTION="version %s, uploaded %s"
INDEX_END=""

die() { echo "!!  $*" >&2; exit 1; }

# A date as the Library writes one, 9 November 2026, in the user's time zone:
# today, or the given seconds since 1970.
library_date() {
    if [ $# -eq 0 ]; then
        LC_ALL=C date +"%e %B %Y"
    else
        LC_ALL=C date -r "$1" +"%e %B %Y" 2>/dev/null || LC_ALL=C date -d "@$1" +"%e %B %Y"
    fi | sed 's/^ //'
}

# The UTC minute a timestamp build number names (202611091530), in seconds
# since 1970; nothing for any other build number.
build_epoch() {
    local b="$1"
    case "$b" in
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) ;;
        *) return 0 ;;
    esac
    date -u -j -f "%Y%m%d%H%M" "$b" +%s 2>/dev/null \
        || date -u -d "${b:0:8} ${b:8:2}:${b:10:2}" +%s
}

article_path() { echo "$FOLDER/build-$1.md"; }

# The latest build tag HEAD contains, by build number.
last_build_tag() {
    git tag --merged HEAD --list "${TAG_PREFIX}*" | sed "s|^$TAG_PREFIX||" | sort -n | tail -1 | sed "s|^|$TAG_PREFIX|"
}

# One line per counted commit in a range, oldest first: kind (feat, fix,
# other or untyped), a tab, then the line to show (the subject for untyped).
classify() {
    git log --reverse --format='%H%x09%P%x09%s' "$@" | awk -F'\t' -v OFS='\t' \
        -v history="$HISTORY" -v release="$RELEASE_SUBJECT" '
        function capital(t) { return toupper(substr(t, 1, 1)) substr(t, 2) }
        BEGIN {
            while ((getline line < history) > 0) {
                split(line, f, "\t")
                if (f[1] != "") { kind[f[1]] = f[2]; text[f[1]] = f[3] }
            }
        }
        {
            sha = $1; subject = $3
            if (index(subject, release) == 1) next
            if (sha in kind) {
                k = kind[sha]
                if (k == "release") next
                if (k == "feat" || k == "fix") print k, text[sha]
                else print "other", ""
                next
            }
            if (split($2, parents, " ") > 1) next
            if (subject ~ /^[a-z]+(\([^)]*\))?!?: /) {
                type = subject; sub(/[^a-z].*$/, "", type)
                line = subject; sub(/^[a-z]+(\([^)]*\))?!?: /, "", line)
                if (type == "feat" || type == "fix") print type, capital(line)
                else print "other", ""
            } else {
                print "untyped", subject
            }
        }'
}

# The body of an article, from the classified commits on stdin: the lists,
# each line once, in the order the commits came.
notes_body() {
    local rows features fixes maintenance
    rows=$(cat)
    features=$(printf '%s\n' "$rows" | awk -F'\t' '$1 == "feat" && $2 != "" && !seen[$2]++ { print "- " $2 }')
    fixes=$(printf '%s\n' "$rows" | awk -F'\t' '$1 == "fix" && $2 != "" && !seen[$2]++ { print "- " $2 }')
    maintenance=$(printf '%s\n' "$rows" | awk -F'\t' '$1 == "other" || $1 == "untyped" { n++ } END { print n + 0 }')
    if [ -n "$features" ]; then printf '\n## New features\n\n%s\n' "$features"; fi
    if [ -n "$fixes" ]; then printf '\n## Fixes\n\n%s\n' "$fixes"; fi
    if [ "$maintenance" -gt 0 ]; then printf '\n## Other changes\n\n- %s\n' "$MAINTENANCE"; fi
}

warn_untyped() {
    local untyped
    untyped=$(printf '%s\n' "$1" | awk -F'\t' '$1 == "untyped" { print "      " $2 }')
    if [ -n "$untyped" ]; then
        echo "!!  These commits have no Conventional Commit type, so they count as maintenance:" >&2
        echo "$untyped" >&2
    fi
}

# Writes one build's article. The range is git log's: "<from>..<to>", or
# "<to>" alone for the first build.
write_article() {
    local build="$1" version="$2" date="$3" range="$4" same_as="$5" rows body
    rows=$(classify "$range")
    warn_untyped "$rows"
    body=$(printf '%s\n' "$rows" | notes_body)
    mkdir -p "$FOLDER"
    {
        echo "# Build $build"
        echo
        echo "Version $version, uploaded to TestFlight on $date."
        if [ -n "$body" ]; then
            printf '%s\n' "$body"
        else
            printf '\n## Other changes\n\n- The same as build %s\n' "$same_as"
        fi
    } > "$(article_path "$build")"
}

# Rewrites the list under the Release notes heading of the index from the
# articles there are, newest build first.
write_index() {
    local entries="" file build version date tmp
    grep -qx "$SECTION_HEADING" "$INDEX" || die "$INDEX has no \"$SECTION_HEADING\" heading"
    for file in "$FOLDER"/build-*.md; do
        [ -f "$file" ] || continue
        build=$(basename "$file" .md); build=${build#build-}
        version=$(sed -n '3s/^Version \(.*\), uploaded to TestFlight on .*\.$/\1/p' "$file")
        date=$(sed -n '3s/^Version .*, uploaded to TestFlight on \(.*\)\.$/\1/p' "$file")
        # shellcheck disable=SC2059
        entries="$entries$build	- [Build $build](release-notes/build-$build.md)$INDEX_SEPARATOR$(printf "$INDEX_DESCRIPTION" "$version" "$date")$INDEX_END
"
    done
    entries=$(printf '%s' "$entries" | sort -t '	' -k1,1nr | cut -f2-)
    tmp=$(mktemp)
    ENTRIES="$entries" awk -v heading="$SECTION_HEADING" '
        state == 0 && $0 == heading {
            print
            if (ENVIRON["ENTRIES"] != "") { print ""; print ENVIRON["ENTRIES"] }
            state = 1; next
        }
        state == 1 && /^## / { print ""; state = 2 }
        state == 1 { next }
        { print }
    ' "$INDEX" > "$tmp"
    cat "$tmp" > "$INDEX"
    rm -f "$tmp"
}

# Pushes HEAD to the branch checked out, rebasing once if it moved.
push_head() {
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD)
    [ "$branch" != "HEAD" ] || return 1
    git push -q origin "HEAD:refs/heads/$branch" 2>/dev/null \
        || { git pull -q --rebase --autostash origin "$branch" && git push -q origin "HEAD:refs/heads/$branch"; }
}

preview() {
    local tag range rows
    tag=$(last_build_tag)
    if [ -n "$tag" ]; then range="$tag..HEAD"; else range="HEAD"; fi
    rows=$(classify "$range")
    echo "==> Release notes for the next build (${tag:-no earlier build}..HEAD):"
    warn_untyped "$rows"
    if [ -z "$rows" ]; then echo "    Nothing has been committed since $tag."; return 0; fi
    printf '%s\n' "$rows" | notes_body | sed 's/^/    /'
}

stamp() {
    local build="$1" version="$2" tag range
    [ ! -f "$(article_path "$build")" ] || die "$(article_path "$build") exists already"
    tag=$(last_build_tag)
    if [ -n "$tag" ]; then range="$tag..HEAD"; else range="HEAD"; fi
    [ -n "$(classify "$range")" ] || die "Nothing has been committed since $tag, so build $build would carry no release notes."
    write_article "$build" "$version" "$(library_date)" "$range" ""
    write_index
    echo "==> Release notes for build $build written to $(article_path "$build")"
}

unstamp() {
    rm -f "$(article_path "$1")"
    write_index
}

publish() {
    local build="$1" article built
    article=$(article_path "$build")
    [ -f "$article" ] || die "$article does not exist; nothing to publish"
    built=$(git rev-parse HEAD)
    git tag "$TAG_PREFIX$build" "$built"
    git add -- "$article" "$INDEX"
    if ! git commit -q -m "$RELEASE_SUBJECT: Add the release notes for build $build" -- "$article" "$INDEX"; then
        echo "!!  Could not commit the release notes for build $build. Commit $article and" >&2
        echo "    $INDEX by hand, and push them with the tag $TAG_PREFIX$build." >&2
        return 0
    fi
    if push_head && git push -q origin "refs/tags/$TAG_PREFIX$build"; then
        echo "==> Release notes for build $build committed, tagged and pushed"
    else
        echo "!!  The release notes for build $build are committed and tagged but not pushed." >&2
        echo "    Push the branch and the tag $TAG_PREFIX$build by hand." >&2
    fi
}

backfill() {
    local source="${1:-}" list main firsts build epoch when sha tagged prev="" count=0 version
    if [ -z "$source" ]; then
        echo "==> Fetching the uploaded builds from App Store Connect"
        list=$(Scripts/asc-builds.sh) || die "Could not read the builds from App Store Connect."
    elif [ "$source" = "-" ]; then
        list=$(cat)
    else
        list=$(cat "$source")
    fi

    main=$(git rev-parse -q --verify origin/main || git rev-parse -q --verify main || git rev-parse HEAD)
    firsts=$(git log --first-parent --format='%H %ct' "$main")

    # Each build with the time it was built, oldest first.
    list=$(printf '%s\n' "$list" | while read -r build epoch; do
        [ -n "$build" ] || continue
        when=$(build_epoch "$build")
        if [ -z "${when:-$epoch}" ]; then
            echo "!!  Build $build has no upload time and its number is not a time; left out." >&2
            continue
        fi
        echo "${when:-$epoch} ${epoch:-$when} $build"
    done | sort -n -k1,1)
    if [ -z "$list" ]; then
        echo "==> No earlier builds."
        return 0
    fi

    while read -r when epoch build; do
        tagged=""
        if sha=$(git rev-parse -q --verify "refs/tags/$TAG_PREFIX$build^{commit}"); then
            :
        else
            tagged=yes
            sha=$(printf '%s\n' "$firsts" | awk -v t="$when" '$2 <= t { print $1; exit }')
            if [ -z "$sha" ]; then
                echo "!!  Build $build predates every commit on main; left out." >&2
                continue
            fi
            git tag "$TAG_PREFIX$build" "$sha"
        fi
        if [ -n "$tagged" ] || [ ! -f "$(article_path "$build")" ]; then
            version=$(git show "$sha:project.yml" 2>/dev/null | sed -n 's/^ *MARKETING_VERSION: *//p' | head -1 | tr -d "\"'")
            if [ -n "$prev" ]; then
                write_article "$build" "${version:-unknown}" "$(library_date "$epoch")" "$TAG_PREFIX$prev..$sha" "$prev"
            else
                write_article "$build" "${version:-unknown}" "$(library_date "$epoch")" "$sha" ""
            fi
            count=$((count + 1))
        fi
        prev="$build"
    done <<EOF
$list
EOF

    write_index
    echo "==> Release notes written for $count earlier builds"
    [ "$count" -gt 0 ] || return 0
    git add -- "$FOLDER" "$INDEX"
    git commit -q -m "$RELEASE_SUBJECT: Add the release notes for earlier builds" -- "$FOLDER" "$INDEX"
    if push_head && git push -q origin "refs/tags/${TAG_PREFIX}*:refs/tags/${TAG_PREFIX}*"; then
        echo "==> Release notes for earlier builds committed and pushed, with their tags"
    else
        echo "!!  The release notes for earlier builds are committed and tagged but not pushed." >&2
        echo "    Push the branch and the ${TAG_PREFIX}* tags by hand." >&2
    fi
}

case "${1:-}" in
    preview) preview ;;
    stamp)
        [ $# -eq 3 ] || die "usage: $0 stamp <build> <version>"
        stamp "$2" "$3"
        ;;
    unstamp)
        [ $# -eq 2 ] || die "usage: $0 unstamp <build>"
        unstamp "$2"
        ;;
    publish)
        [ $# -eq 2 ] || die "usage: $0 publish <build>"
        publish "$2"
        ;;
    has-builds) git tag -l "${TAG_PREFIX}*" | grep -q . ;;
    backfill) backfill "${2:-}" ;;
    *) die "usage: $0 preview | stamp <build> <version> | unstamp <build> | publish <build> | has-builds | backfill [<file>|-]" ;;
esac
