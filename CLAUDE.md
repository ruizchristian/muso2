# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Freshly generated Flutter app (`flutter create`, project name `music`, package `com.example.music`). `lib/main.dart` is still the default counter template and `test/widget_test.dart` is the matching smoke test — there is no app-specific architecture yet. No third-party dependencies beyond `cupertino_icons`; lints come from `flutter_lints` via `analysis_options.yaml`.

## Environment

- Flutter SDK (stable 3.47.x, Dart 3.13) lives at `C:\src\flutter` and is on the user PATH. In a shell that predates the install, prepend it: `$env:Path += ';C:\src\flutter\bin'`.
- Android SDK: `%LOCALAPPDATA%\Android\Sdk`. Available AVD: `Pixel_10a` (usually already running as `emulator-5554` — launching it again fails with "multiple emulators with the same AVD").
- Windows desktop builds are not available (Visual Studio C++ workload not installed). Android and web (Chrome/Edge) work.

## Commands

```
flutter pub get                          # install dependencies
flutter analyze                          # lint / static analysis
flutter test                             # all tests
flutter test test/widget_test.dart       # single file
flutter test --plain-name "Counter increments smoke test"   # single test by name
flutter run -d emulator-5554             # run on Android emulator (interactive; hot reload with r/R)
flutter run -d chrome                    # run on web
flutter build apk --debug --target-platform android-x64      # fast debug APK for the emulator
```

`flutter run` is interactive and long-running — don't run it from a tool call. To launch on the emulator non-interactively, build the APK above and then:

```
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
adb -s emulator-5554 shell am start -n com.example.music/.MainActivity
```

(`adb` is at `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.)

If a Gradle build fails with missing files under `build\app\intermediates\...` (e.g. during `stripDebugDebugSymbols`), run `flutter clean` and rebuild — it's leftover state from an interrupted build.
