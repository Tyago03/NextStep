# NextStep

## Problem

Starting a study session is easier when the next action is clear. NextStep turns
goals into small tasks and keeps the next-step note available after an interruption.
Version **0.3.0** runs on Android and stores plans and sessions locally, without an account.

## Delivered features

- Create, edit and organize goals and tasks with time estimates and optional reference links.
- Choose available minutes and find an unfinished task that fits.
- **Pause/resume** the same session, **finish for now** while keeping the task pending,
  or explicitly **complete the task**.
- Start another session with a fresh timer and the previous next-step note.
- Review recorded time, notes, finished sessions and completed tasks in Progress.
- Use Portuguese or English, with local SQLite persistence and automatic note saving.

A running session keeps counting when the app closes; pause to stop its clock.
Optional **Firebase/Gemini** planning is prepared but not activated or validated
against the live service. Unconfigured builds explain this before the request
form. Saved proposals remain reviewable offline and require confirmation before import.
[AI setup](docs/AI_SETUP.md).

## Real screenshots/demo

Actual signed-release captures from an Android API 36 emulator, using example study data:

<p>
  <img src="docs/images/nextstep-0.3-plan.png" width="220" alt="Plan with two DNS tasks">
  <img src="docs/images/nextstep-0.3-new-session.png" width="220" alt="New session with its previous note">
  <img src="docs/images/nextstep-0.3-progress.png" width="220" alt="Three finished sessions and one completed task">
</p>

[Download the 2:30 demo](https://github.com/Tyago03/NextStep/releases/download/v0.3.0/NextStep-0.3.0-demo.mp4)
with English captions and identified cuts. GitHub sign-in and access to the
private repository are required. [Presentation details](docs/PORTFOLIO.md).

## APK installation

[Download the signed APK](https://github.com/Tyago03/NextStep/releases/download/v0.3.0/NextStep-0.3.0-release.apk)
(52.6 MiB) from [Release v0.3.0](https://github.com/Tyago03/NextStep/releases/tag/v0.3.0).
The release requires access to the private repository; it is not publicly accessible.
The APK was installed and demonstrated on the emulator. Physical-device validation is pending.

Open the downloaded APK on **Android 7.0/API 24 or later** and approve
installation for the app opening the file. Its release certificate differs from
debug builds: use a separate device/emulator to preserve existing debug data.
ARM64, ARMv7 and x86_64 libraries are included. Check the
[SHA-256 file](https://github.com/Tyago03/NextStep/releases/download/v0.3.0/NextStep-0.3.0-release.apk.sha256)
and [verification record](https://github.com/Tyago03/NextStep/releases/download/v0.3.0/VERIFICATION.json).
See [distribution details](docs/DISTRIBUTION.md) and record phone results in
[the device checklist](docs/DEVICE_TEST.md). There is no Play Store listing.

## Run from source

Prerequisites: **Flutter 3.50.0/Dart 3.14**, JDK 21, Android SDK 36 and an authorized
Android device or running emulator. Add Flutter to your terminal's `PATH`.
Manual planning requires no Firebase configuration.
Repository access is currently required to clone:

```sh
git clone https://github.com/Tyago03/NextStep.git
cd NextStep
flutter pub get --enforce-lockfile
flutter devices
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with the Android ID listed above. To build a local debug APK:

```sh
flutter build apk --debug -t lib/main.dart
```

## Tests/limits

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --reporter expanded
```

The verified 0.3.0 checkpoint passed **92 host tests**, including schema migration
coverage, and **four Android integration stages**, including process restart.
[Validation record](docs/VALIDATION.md).
Emulator demonstration does not establish physical-device, TalkBack or real-user validation.
Live Gemini, iOS, web and Windows desktop are unvalidated. There is no backup,
export or synchronization; uninstalling/clearing data can erase records. An edit
still marked as saving may be lost if the process is forcibly stopped.

## Author

Author and maintainer: Tyago Vitorino Ferreira
