#!/usr/bin/env bash
# Applies the Android port changes to the libultraship, ZAPDTR and OTRExporter submodules.
# Safe to run more than once: a stamp file records which patch version was applied.
# Use --reset to restore the submodules to their pinned commits first.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
git submodule update --init libultraship ZAPDTR OTRExporter
for sub in libultraship ZAPDTR OTRExporter; do
    patch="$ROOT/android-ap/patches/$sub.patch"
    stamp="$ROOT/$sub/.android-ap-patched"
    sum="$(sha256sum "$patch" | cut -d' ' -f1)"
    if [ "${1:-}" = "--reset" ] || { [ -f "$stamp" ] && [ "$(cat "$stamp")" != "$sum" ]; }; then
        git -C "$sub" reset -q --hard
        git -C "$sub" clean -qfd
        rm -f "$stamp"
    fi
    if [ -f "$stamp" ]; then
        echo "[$sub] already patched"
        continue
    fi
    git -C "$sub" apply --ignore-whitespace "$patch"
    echo "$sum" > "$stamp"
    echo "[$sub] patched"
done
