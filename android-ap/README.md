# Archipelago-SoH for Android (work in progress)

This branch combines the Archipelago client for Ship of Harkinian
(aMannus/Shipwright, `archipelago` branch, SoH 9.2.3) with the Android port
from Waterdish/Shipwright-Android (SoH 9.0.2).

Status: **work in progress — does not build an APK yet.**

## Layout
- `soh/` — Android-specific game code changes (ROM picker, entry point, touch camera, 32-bit fixes).
- `android-ap/patches/` — Android changes for the `libultraship`, `ZAPDTR` and `OTRExporter`
  submodules, kept as patches so the submodules can stay pinned to their upstream commits.
- `android-ap/apply-patches.sh` — applies those patches (safe to run more than once).

## Remaining work
1. CMake: Android shared-library target; fetch SDL2_net, ogg, vorbis, opus, opusfile and OpenSSL.
2. Android app project: `.o2r` asset names, INTERNET permission, CA bundle, separate app id / `SOH-AP` folder.
3. Generate `soh.o2r` from this tree and stage the APK assets.
4. GitHub Actions workflow that builds the APK.
