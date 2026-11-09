#!/bin/bash
# gen-copy.sh [--check]: regenerate Core/Sources/AppText/Copy.generated.swift
# from Copy/copy.tsv.
#
# Copy/copy.tsv holds every string the user reads: the key, the text with its
# named placeholders, the placeholder types, where it shows and any note a
# reviewer needs. The generated Swift is committed alongside it, so a checkout
# builds without running anything. Edit a row, run this, commit both.
# `--check` regenerates into a scratch copy and fails when the committed file
# differs.
set -euo pipefail

CHECK=0
if [ "$#" -gt 0 ]; then
    if [ "$1" = "--check" ] && [ "$#" -eq 1 ]; then CHECK=1; else
        echo "!!  usage: gen-copy.sh [--check]" >&2; exit 2
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TABLE="$ROOT/Copy/copy.tsv"
OUTPUT="$ROOT/Core/Sources/AppText/Copy.generated.swift"

if [ "$CHECK" -eq 1 ]; then
    SCRATCH="$(mktemp -d)"
    trap 'rm -rf "$SCRATCH"' EXIT
    swift "$SCRIPT_DIR/gen-copy.swift" "$TABLE" "$SCRATCH/Copy.generated.swift" >/dev/null
    if ! diff -u "$OUTPUT" "$SCRATCH/Copy.generated.swift"; then
        echo "!!  Copy.generated.swift is stale. Run Scripts/gen-copy.sh and commit both files." >&2
        exit 1
    fi
    echo "==> copy table and generated Swift agree"
    exit 0
fi
swift "$SCRIPT_DIR/gen-copy.swift" "$TABLE" "$OUTPUT"
