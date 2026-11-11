# Archipelago-SoH for Android

This branch combines:
- the **Archipelago client for Ship of Harkinian** (aMannus/Shipwright, `archipelago` branch, SoH 9.2.3), and
- the **Android port** by Waterdish (Waterdish/Shipwright-Android, SoH 9.0.2).

It installs as a separate app (**SoH Archipelago**, `com.dishii.soh.ap`) with its own data folder
(`/storage/emulated/0/SOH-AP`), so it can sit next to the regular SoH Android app without touching
its files or saves.

## Getting the APK (no local toolchain needed)

The workflow `.github/workflows/android-ap.yml` builds the APK on GitHub Actions on every push to
`android-ap`, or manually via **Actions → android-ap → Run workflow**.

1. On your fork, open the **Actions** tab and enable workflows if GitHub asks (they are off by default on forks).
2. Wait for the `android-ap` run to finish (expect 30–60 minutes the first time).
3. Download the `soh-archipelago-android` artifact. It contains a debug-signed, arm64-v8a release APK.
4. If the run fails, the build logs are pushed to the `android-ap-ci-logs` branch of the same repo.
   Start with `errors-summary.txt`; `ninja-keep-going.log` lists every failing file in one go.

## Using it

1. Install the APK and allow "All files access" when asked.
2. Pick your OoT ROM when prompted. The ROM is extracted on the device, as in the regular Android port.
3. Generate your seed on PC or archipelago.gg as usual, with the `oot_soh.apworld` that matches this
   client (1.4.x).
4. In the quest selection menu, choose **Archipelago** and enter the server address, slot name and password.
   The on-screen keyboard appears for text fields.
5. The Archipelago console is in the menu (Back/Select button): **Network → Archipelago**.

## Building locally

Requirements: Linux, macOS or WSL (OpenSSL is cross-compiled with perl + make), Android SDK with
NDK `26.0.10792818` and CMake `3.31.5`, JDK 17, and the desktop dependencies needed to build
`soh.o2r` (see `.github/workflows/apt-deps.txt`).

```sh
git submodule update --init
./android-ap/apply-patches.sh                        # Android changes for the submodules
cmake -H. -Bbuild-host -GNinja                       # desktop host build, only to make soh.o2r
cmake --build build-host --target GenerateSohOtr
./android-ap/stage-assets.sh soh.o2r                 # soh.o2r, extractor files, CA bundle -> APK assets
cd Android && ./gradlew assembleRelease              # APK in Android/app/build/outputs/apk/release
```

## What changed, and where

- `soh/`: Android code paths re-applied from the Android port. These cover the JNI ROM picker
  in the extractor, the `SDL_main` entry with the Java setup handshake, touch camera input,
  a 32-bit `AudioContext` fix and explicit pointer casts for clang.
- `soh/CMake/AndroidDependencies.cmake` provides what the NDK lacks: ogg, vorbis, opus and opusfile
  (custom audio), plus SDL2_net and a static OpenSSL 3.0 built per ABI (networking for
  Archipelago, Anchor and Crowd Control).
- `soh/CMakeLists.txt` builds the game as `libsoh.so` on Android, with Android compile flags and libraries.
- `android-ap/patches/` holds the Android changes for `libultraship`, `ZAPDTR` and `OTRExporter`.
  They are kept as patches so the submodules stay pinned upstream. Apply them with
  `android-ap/apply-patches.sh`, which is safe to re-run; `--reset` restores the submodules.
  - libultraship: Waterdish's Android layer (touch/virtual gamepad JNI, phone gyro, Android menu
    handling, UI scale, storage paths), ported to the restructured `src/ship` and `include/` layout.
    Its custom ImGui SDL2 backend is rebuilt for ImGui 1.91.9b. SDL is pinned to 2.32.8 on Android
    to match the bundled SDL Java glue.
  - ZAPDTR / OTRExporter: in-app extraction build tweaks.
- `Android/`: the app project, with the app id and data folder changed, `.otr` → `.o2r`,
  the INTERNET permission added, and the CA bundle installed for `wss://` servers.

## Verification status

- Development sandbox (no Android NDK): the desktop build configures, every touched file compiles,
  Android-only code passes a syntax check with `__ANDROID__` defined, and the Android dependency chain
  (SDL_net, ogg/vorbis/opus/opusfile, OpenSSL 3.0) builds and links in a host test project.
- GitHub Actions, NDK 26: all 817 native compile steps succeed (after adding a missing `<sstream>`
  include in `SohMenuRandomizer.cpp`).
- Not verified yet: running on a device.

## Known limitations / things to watch

- Android may suspend the app in the background, which can drop the Archipelago connection.
  This has not been tested on a device yet. If items stop arriving, check the Archipelago console
  and reconnect from there.
- Release builds are arm64-v8a only and use the debug signing key, as in the original Android port.
  Debug builds cover all four ABIs.
- The data folder is hardcoded to `/storage/emulated/0/SOH-AP`. It is set in two places, which must
  match: `MainActivity.DATA_FOLDER` and libultraship's `Context.cpp` (via the patch).
