# NextStep

NextStep helps with a personal problem: starting a study session and remembering
where to continue after an interruption. Turn a goal into small tasks, choose
one that fits the time available, and save a concrete next step. Plans, notes
and session history stay on the Android device, without an account.

**Version 0.3.0:** pause an open session, **finish for now** while keeping its task
pending, or explicitly **complete the task**. Starting that task again creates a
new session with the previous next-step note and a fresh timer. History separates
finished sessions from completed tasks.

Tyago defined the personal problem, product scope and review priorities. Codex
assisted with implementation, tests, documentation and code review. This is a
small working project, not a claim of production users or measured study gains.

The [presentation guide](docs/PORTFOLIO.md) explains the Android demo, authorship
and distribution limits. The [revision checkpoint](docs/REVISION_2026_11_20.md)
records executed validation. Installation details follow below.

Real captures of the signed **0.3.0** release on an Android API 36 emulator,
using synthetic DNS study data:

<p>
  <img src="docs/images/nextstep-0.3-plan.png" width="220" alt="Manual plan with two pending DNS tasks">
  <img src="docs/images/nextstep-0.3-new-session.png" width="220" alt="New session with the previous next-step note and a fresh timer">
  <img src="docs/images/nextstep-0.3-progress.png" width="220" alt="Progress showing three finished sessions and one completed task">
</p>

The release APK was built, signature-checked and installed separately from the
existing debug app. Its measured size is **55,127,375 bytes** (52.6 MiB). The APK
and recorded demo are local artifacts; they have not been published for download.

Optional Gemini/Firebase integration is prepared but **not activated or tested
against the live provider**. Unconfigured builds explain this before showing a
request form. Saved proposals remain reviewable offline; tasks are imported
only after confirmation. See [AI setup](docs/AI_SETUP.md).

The [editable project briefing](NextStep_Briefing_Atualizado.md) records the
current scope and explains how to review future changes supplied by Tyago.

The project repository is **private**: [Tyago03/NextStep](https://github.com/Tyago03/NextStep).
The existing development branch is `codex/mvp`. Local SDKs, caches, databases,
Firebase configuration and APK outputs are excluded from Git.

Example: create **Understand DNS**, add **Look up a domain and record the answer**
with a 15-minute estimate, start a session, then pause with the note
**Next: compare A and AAAA records**. Reopen the app to resume that same session.

## What is implemented

| Screen | Behavior |
| --- | --- |
| Today | Choose quick or custom minutes, see an unfinished task that fits, choose another task, or return to the current session. |
| Plan | Create, edit, and delete goals and tasks; new items append automatically, with priority order and reference links under More options. |
| Session | Start, pause, resume, finish for now, or complete the task; save and recover the next-step note. |
| Progress | See finished sessions, their recorded time, title snapshots, notes and whether the task was completed at that session's end. |
| AI planning | Describe a topic and routine, review a dated proposal with steps and completion checks, then explicitly confirm before any tasks are created. |

The interface supports Portuguese and English, empty plans, narrow screens, and
enlarged text. Data is stored in SQLite on the device. There is no account,
cloud plan storage, advertising, or subscription. Optional AI generation sends
the supplied topic and study preferences to Google after the user requests it;
the free tier may use that content to improve Google services. Reference links
open the device's external browser only when selected.

**Time policy:** a running session continues counting when the app is closed.
Pause explicitly to stop the clock. Reopening a paused session keeps its elapsed
time unchanged. **Finish for now** closes the session and keeps the task pending;
**Complete task** finishes both in one transaction. At most one session can be
running or paused. Starting another session never adds its predecessor's time
again; each historical interval is counted once.

## Validation and design decisions

The initial remote Android run could not boot its emulator because the runner
ran out of disk space. A correction limited to the disposable GitHub runner
freed unused SDKs and set a bounded AVD data partition. Both jobs and all four
Android stages passed at commit `cfb4d977` in
[run 44851876321](https://github.com/Tyago03/NextStep/actions/runs/44851876321).
The **0.3.0 code and test checkpoint** is `cd62f281`: both jobs passed in
[run 44862109558](https://github.com/Tyago03/NextStep/actions/runs/44862109558),
with **92 host tests and all four Android stages**, including process restart.
The [revision record](docs/REVISION_2026_11_20.md) includes migration coverage,
subsequent test fixes and signed-release evidence. The documentation commit
following that checkpoint changes no application or test code.

SQLite transactions keep final time, note and session state consistent. Schema
migrations preserve old records; a persistent proposal ID prevents duplicate AI
imports. Riverpod separates screen state from storage. `sqflite` was chosen over
Drift to keep this small app free of a database code-generation pipeline.

Earlier records remain available: [original validation](docs/VALIDATION.md),
[UI review](docs/QA_ROUND_2.md) and [AI preparation](docs/AI_VALIDATION.md).
Automated tests and an emulator demonstration do not replace physical-device,
TalkBack or real-user validation. There is no store publication or public demo
link until Tyago explicitly approves sharing.

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

To prepare a signed release APK locally:

```powershell
.\tool\prepare-signing.ps1
.\tool\build-distribution.ps1
```

The signing script creates a dedicated key only when neither signing file exists.
Keep `../.nextstep-tools/signing/nextstep-release.jks` and `android/key.properties`
private and back them up together for future updates. Both stay outside Git.
Release builds do not fall back to a debug certificate. The builder verifies the
signature, records SHA-256 and places the APK in `dist`. Nothing is uploaded.
Use a separate emulator for release testing: its certificate differs from the
existing debug installation, whose data must not be cleared to replace it.

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
  new task for another study action. A task left pending by Finish for now can
  start a new session. Discarding sessions and deleting history are not implemented.
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
