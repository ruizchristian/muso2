# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Muso: an offline player for the audio files on the device, ported from the React Native/Expo app in `C:\Dev\my-music`. Flutter project name `music`, Android package `com.example.music`. Android is the target; iOS is configured but untested.

## Architecture (`lib/`)

- `core/`: pure helpers (formatting, alphabet index, colour shades, text comparison).
- `media/`: `Track`, filename parsing ("Artist - Album - Title"), grouping, user overrides, sorting, `media_backend` (`photo_manager` scan, permission, delete).
- `storage/`: versioned JSON in `shared_preferences` (`SharedPreferencesAsync`), with the same keys the RN app used (`my-music:library:v1`, …).
- `player/`: `PlayerEngine.instance` (queue, shuffle, repeat, persistence) talks to an `AudioOutput` interface. `JustAudioOutput` implements it with `just_audio` and `audio_service`, which provide the lock-screen controls (including ±10 s) and pause on headphone or Bluetooth disconnect. Tests use a fake output.
- `state/`: `provider` ChangeNotifiers: `ThemeController`, `LibraryController`, `UpdateController`.
- `update/`: in-app updates. `GitHubUpdateSource` reads `releases/latest` from the public repo `ruizchristian/muso2`, then downloads and SHA-256-checks the `Muso-<version>-<build>.apk` asset. `AndroidUpdatePlatform` uses the `muso/updates` method channel in `MainActivity.kt` to read the versionCode and open the installer through a FileProvider (`res/xml/update_paths.xml`). It is disabled in debug builds.
- `ui/` and `screens/`: widgets and screens. Navigation is a custom `TabsShell` plus named routes in `routes.dart`. `MiniPlayerOverlay` and `UpdateBanner` sit above the navigator, in `MaterialApp.builder`.

## Environment

- Flutter SDK 3.47.x (Dart 3.13) at `C:\src\flutter`, on the user PATH. In an older shell: `$env:Path += ';C:\src\flutter\bin'`.
- Android SDK: `%LOCALAPPDATA%\Android\Sdk`. AVD `Pixel_10a` runs as `emulator-5554`. Its GPU mode must stay `host`; software rendering crashed the emulator.
- `gh` is at `C:\Program Files\GitHub CLI`. Windows desktop builds are not set up.
- `permission_handler` is pinned to 12.x. Version 13 needs compileSdk 37, which AGP cannot resolve here.

## Commands

```
flutter pub get
flutter analyze
flutter test                                   # unit tests: logic, engine, updater
dart format lib test --line-length 100
.\scripts\build-apk.ps1                        # checks + signed release APK into dist\
.\scripts\release.ps1                          # GitHub release; CI attaches the APK; phones update in-app
```

`flutter run` is interactive, so don't run it from a tool call. Instead, build an APK and run `adb -s emulator-5554 install -r <apk>`.

## Signing and releases

- Release builds are signed with `android/app/upload-keystore.jks` using `android/key.properties`. Both are gitignored, and CI restores them from the secrets `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`. Never commit or print them. If the key is lost, no future APK can update an existing install.
- The build number (versionCode) is the UTC time as `yyMMddHH`, in both the script and CI. The updater offers a release only when its build number is higher than the installed one.
- CI (`.github/workflows/android.yml`) runs analyze and test on every push and PR. It builds the APK on pushes to main, and attaches it to a release when the release is published.
- If Gradle fails with missing files under `build\app\intermediates\...`, run `flutter clean` and rebuild.
