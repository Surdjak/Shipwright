#!/usr/bin/env bash
# Stages everything the APK bundles into Android/app/src/main/assets:
#   soh.o2r              - SoH's own assets (incl. Archipelago item models), built from THIS tree
#   assets/              - extractor configs + xmls, used to extract oot.o2r from the user's ROM on device
#   networking/cacert.pem- CA bundle for secure (wss://) Archipelago connections
#   gamecontrollerdb.txt - SDL controller mappings
#
# Usage: android-ap/stage-assets.sh path/to/soh.o2r
# Build soh.o2r on a desktop host with:  cmake -B build-host -GNinja && cmake --build build-host --target GenerateSohOtr
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
O2R="${1:?usage: $0 path/to/soh.o2r}"
DEST="$ROOT/Android/app/src/main/assets"

rm -rf "$DEST/assets" "$DEST/networking"
mkdir -p "$DEST/assets/xml" "$DEST/networking"

cp "$O2R" "$DEST/soh.o2r"
cp -r "$ROOT/soh/assets/extractor/." "$DEST/assets/"
cp -r "$ROOT/soh/assets/xml/." "$DEST/assets/xml/"

curl -sSfL https://curl.se/ca/cacert.pem -o "$DEST/networking/cacert.pem"
curl -sSfL https://raw.githubusercontent.com/mdqinc/SDL_GameControllerDB/master/gamecontrollerdb.txt \
    -o "$DEST/gamecontrollerdb.txt"

echo "Staged APK assets in $DEST:"
du -sh "$DEST"/* | sed 's|'"$DEST"'/||'
