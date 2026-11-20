# NextStep

A small Flutter app that stores study plans on the device and preserves context
after an interruption. Optional online AI proposes detailed plans for review.

**Version 0.2.0:** Gemini/Firebase integration is prepared, but the developer
account is deliberately not activated yet. The delivered unconfigured build
does not generate live AI plans or substitute fake answers. Manual planning
works normally. See [AI setup](docs/AI_SETUP.md) and [AI validation](docs/AI_VALIDATION.md).

The [editable project briefing](NextStep_Briefing_Atualizado.md) records the
current scope and explains how to review future changes supplied by Tyago.

Example: create **Understand DNS**, add **Look up a domain and record the answer**
with a 15-minute estimate, start a session, then pause with the note
**Next: compare A and AAAA records**. Reopen the app to resume that same session.

## What is implemented

| Screen | Behavior |
| --- | --- |
| Today | Choose quick or custom minutes, see an unfinished task that fits, choose another task, or return to the current session. |
| Plan | Create, edit, and delete goals and tasks; new items append automatically, with priority order and reference links under More options. |
| Session | Start, pause, resume, and complete a task and its session; save a next-step note. |
| Progress | See completed sessions, their actual recorded time, title snapshots, and notes. |
| AI planning | Describe a topic and routine, review a dated proposal with steps and completion checks, then explicitly confirm before any tasks are created. |

The interface supports Portuguese and English, empty plans, narrow screens, and
enlarged text. Data is stored in SQLite on the device. There is no account,
cloud plan storage, advertising, or subscription. Optional AI generation sends
the supplied topic and study preferences to Google after the user requests it;
the free tier may use that content to improve Google services. Reference links
open the device's external browser only when selected.

**Time policy:** a running session continues counting when the app is closed.
Pause explicitly to stop the clock. Reopening a paused session keeps its elapsed
time unchanged. **Complete task and session** finishes both in one transaction.
At most one session can remain unfinished.

## Earlier QA checkpoint

On **19 November 2026**, formatting and static analysis passed on Windows, and
all **35 repository, controller, and widget tests passed**. These include real
SQLite file reopening, the complete UI flow, queued note writes, failed saves,
duplicate-save prevention after a failed refresh, and 320-pixel layouts with 2x
text scaling and simulated keyboard insets.

The Android debug build passed; the normal application APK is preserved at
`dist/NextStep-debug.apk`. The Android core-flow test passed (1/1), and both
process-restart phases passed after an explicit force-stop between executions.
APK metadata and installed-package checks confirmed the separate
`dev.tyago.nextstep.integration` test sandbox. The verified runner preserves its
data between phases using `--no-uninstall`.
The normal APK was installed and launched on the emulator, and its local database
was verified. Desktop visual inspection remains blocked by Computer Use's
emulator permission; automated Android UI tests are recorded separately.
Seven development widget renders were visually reviewed after the UI polish.
These are rendered app widgets with test fixtures, not emulator screenshots or
human usability testing. See [the second QA round](docs/QA_ROUND_2.md).

See [the validation record](docs/VALIDATION.md) for commands, scope, and outstanding
checks. The GitHub Actions workflow is configured but has not run. Versioning is
local Git; no remote repository or public release is claimed.

The newer AI implementation and its additional tests are documented in
[AI_VALIDATION.md](docs/AI_VALIDATION.md). The counts above describe the earlier
QA checkpoint, not the current suite.

## Run on the prepared Windows machine

Open PowerShell in the `NextStep` directory:

```powershell
. .\tool\env.ps1
flutter --version
flutter devices
.\tool\run-android.ps1
```

The runner connects to `emulator-5554`, starting the `NextStep_API36` virtual
device if necessary, then invokes `flutter run`. To use an already configured
physical Android device instead:

```powershell
.\tool\run-android.ps1 -Device 'DEVICE_ID_FROM_FLUTTER_DEVICES'
```

USB debugging and the device's authorization prompt must be handled on the
device. Stop a Flutter run with `q` in its terminal.

## Reproduce the portable Windows setup

Use Windows x64, Git, PowerShell, and a directory with no spaces or special
characters. Commands below start in the root of a local copy of this repository.
Keep the application and its tools as siblings:

```text
workspace/
  NextStep/
  .nextstep-tools/
```

If the sibling Flutter SDK does not already exist, obtain the pinned release
from its official repository:

```powershell
New-Item -ItemType Directory -Path ..\.nextstep-tools -Force
git -c core.longpaths=true clone --depth 1 --branch 3.50.0 https://github.com/flutter/flutter.git ../.nextstep-tools/flutter
.\tool\install-android-tools.ps1
. .\tool\env.ps1
flutter --version
```

The installation script downloads portable Microsoft OpenJDK and Android
command-line tools from official sources and checks their SHA-256 hashes.
It does not accept Android SDK licenses. Review and accept those yourself before
installing the platform and emulator image:

```powershell
$sdkManager = Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin\sdkmanager.bat'
& $sdkManager --licenses
& $sdkManager 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' 'emulator' 'system-images;android-36;google_apis;x86_64'
flutter pub get --enforce-lockfile
flutter doctor -v
emulator -accel-check
```

If hardware virtualization or the Windows hypervisor is unavailable, resolve that
Windows prerequisite or use a physical Android device. The project scripts do
not change those system settings. Android Studio is optional for this
command-line workflow; no separate Dart SDK is needed because Flutter supplies
it.

Create the virtual device once. If a device with this name already exists, use
it rather than overwriting it. Accept the default **No** if asked to create a
custom hardware profile:

```powershell
New-Item -ItemType Directory -Path $env:ANDROID_AVD_HOME -Force
$avdManager = Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin\avdmanager.bat'
& $avdManager create avd --name NextStep_API36 --package 'system-images;android-36;google_apis;x86_64' --device pixel_6
.\tool\run-android.ps1
```

The inspected toolchain is Flutter **3.50.0**, Dart **3.14.0**, Microsoft OpenJDK
**21.0.13.1**, Android SDK platform **36**, build-tools **36.0.0**, and emulator
**37.3.10**. `sdkmanager` may serve newer emulator or system-image revisions in
the future; `pubspec.lock` pins Dart package resolution.

`tool/env.ps1` sets SDK paths and redirects Pub, Gradle, Android/AVD, and app-data
caches to `../.nextstep-tools` for that terminal and its child processes. It does
not persist a machine-wide PATH change or reconfigure other projects. Close that
terminal when finished rather than using its project-specific environment for
unrelated work. SDKs, caches, databases, build outputs, and signing material are
not committed.

## Development checks

```powershell
. .\tool\env.ps1
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --reporter expanded
.\tool\verify-android.ps1
.\tool\build-android.ps1
```

A normal debug build writes `build/app/outputs/flutter-apk/app-debug.apk`.
Integration builds can replace that build output, so use the preserved normal
APK at `dist/NextStep-debug.apk` or rebuild the normal target before installing a
user-facing copy. Android integration requires a running emulator or authorized
device; it is separate from `flutter test`.

`tool/verify-android.ps1` runs AI planning with explicit test fixtures, the core
session flow, and the seed/verify restart phases,
with an explicit force-stop between phases. Its verified integration application
ID is `dev.tyago.nextstep.integration`; the normal runner launches
`dev.tyago.nextstep`. APK metadata and installed-package checks confirmed both
IDs. Every integration command uses `--no-uninstall` to preserve test data
between invocations. Instructions and evidence are in
[AI_VALIDATION.md](docs/AI_VALIDATION.md).

## Architecture and data

Flutter's official Material UI package provides the interface. Riverpod connects
an application controller to immutable domain models and a transactional SQLite
repository. This MVP uses `sqflite` instead of the proposed Drift to avoid a code
generation pipeline while keeping SQL transactions, constraints, and schema
versioning. Host tests use the same repository through `sqflite_common_ffi`.
See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for state transitions and tradeoffs.

Notes save in order as they are edited. The interface reports saving or failure;
a retry button appears for an unsaved note. Pause and completion wait
for queued edits and commit the current note with the state transition. Deleting
an active session's task or goal is blocked. Other deletions require confirmation
and retain completed session history.

## Limits

- Only acknowledged writes are durable. A forced process termination can discard
  an edit still marked as saving.
- Changing the device clock can change a running interval; negative intervals
  are clamped to zero. No background service or reminder notification is used.
- Data is not encrypted by this app, synchronized, or exported. The Android
  manifest sets `allowBackup="false"`; the app implements no cloud backup.
  Uninstalling it or clearing its data can remove the local plan and history.
- Completed tasks cannot be reopened as new sessions in this version. Create a
  new task for another study action. There is no session cancellation or history
  deletion workflow.
- Web, iOS, and a Windows desktop application have not been validated. Running
  tests on a Windows host does not establish Windows desktop app support.
- Store signing/publication, Android home-screen widgets, export/import, real
  device performance measurements, and external human review remain future work.

## Authorship

NextStep is a new personal project for Tyago Vitorino Ferreira. OpenAI Codex
assisted with implementation, automated tests, and code review. No code from
classmates' academic applications, Ayla Mobile, or HabiTrack was imported. This
repository does not claim production users, measured productivity improvements,
store publication, or independent human review.

## Official references

- [Flutter installation](https://docs.flutter.dev/install/manual)
- [Android command-line tools](https://developer.android.com/studio#command-line-tools-only)
- [Microsoft OpenJDK](https://learn.microsoft.com/en-us/java/openjdk/download)
- [Official Flutter Material UI](https://pub.dev/packages/material_ui)
- [SQLite plugin](https://pub.dev/packages/sqflite)
