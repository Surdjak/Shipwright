#!/usr/bin/env bash
# Applies the Android port changes to the libultraship, ZAPDTR and OTRExporter submodules.
# Safe to run more than once: already-applied patches are skipped.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
git submodule update --init libultraship ZAPDTR OTRExporter
for sub in libultraship ZAPDTR OTRExporter; do
    patch="$ROOT/android-ap/patches/$sub.patch"
    if git -C "$sub" apply --reverse --check --ignore-whitespace "$patch" 2>/dev/null; then
        echo "[$sub] already patched"
    else
        git -C "$sub" apply --ignore-whitespace "$patch"
        echo "[$sub] patched"
    fi
done
