# MVP validation — 19 November 2026

Historical checkpoint of the original MVP, recorded on **19 November 2026**.
These results apply to that version. Later records cover
[AI integration v0.2.0](AI_VALIDATION.md) and
[v0.3.0, remote CI and the release demonstration](REVISION_2026_11_20.md).

## Environment inspected

| Component | Observed version / configuration |
| --- | --- |
| Host | Windows 11 Pro, x64, OS build 10.0.26300 |
| Git | 2.55.0.windows.5 |
| Flutter | 3.50.0, portable sibling SDK |
| Dart | 3.14.0, bundled with Flutter |
| Java | Microsoft OpenJDK 21.0.13.1 |
| Android platform | API 36 |
| Android build-tools | 36.0.0 |
| Android emulator | 37.3.10 |
| Android NDK | 28.2.13676358, installed during the verified debug build |
| Virtual-device configuration | `NextStep_API36`, `pixel_6`, Google APIs x86_64 API 36 |

Tools and caches are isolated under `../.nextstep-tools`; `tool/env.ps1` configures
only its PowerShell process and descendants.

## Executed local checks

Run from the repository root after `. .\tool\env.ps1`:

| Command | Result | Evidence scope |
| --- | --- | --- |
| `dart format --output=none --set-exit-if-changed lib test integration_test tool/visual_review_test.dart` | Passed; 15 files, 0 changes | Includes both Android integration targets and the development render script. |
| `flutter analyze` | Passed; no issues found | Static analysis of the project and tests. |
| `flutter test --reporter expanded` | Passed; 35/35 tests | 14 repository tests, 5 controller tests, and 16 widget tests on Windows. |

This suite includes the [second QA round](QA_ROUND_2.md) and committed-write
refresh recovery. Repository tests close and reopen real SQLite files. Android
plugin and process-restart checks are recorded separately below.

### What the 35 host tests cover

- Goal/task CRUD, validation, ordering, preferences and time-compatible
  suggestions; deletion confirmation and protection of active work.
- Running/paused persistence, deterministic timing, repeated commands,
  competing starts, retained history and atomic completion with rollback.
- Ordered note writes, immediate pause, duplicate-command prevention, queued
  writes after controller disposal, failed drafts and retry across navigation.
- Committed writes followed by failed refreshes: no duplicate insert, blocked
  mutations, read-only recovery and retained note drafts.
- Full planning/session journey, time presets, alternate-task selection and
  onboarding; PT/EN layouts at 320px, 2x text and simulated keyboard insets.

A separate render scenario passed; seven PNGs were inspected at 390 × 844 logical
pixels with Roboto and Material icons. These are widget renders, not Android
screenshots. Reproduction and findings are in [QA_ROUND_2.md](QA_ROUND_2.md).

## Android results and remaining checks

| Check | Status |
| --- | --- |
| `flutter build apk --debug` | Passed; normal app copied to `dist/NextStep-debug.apk` before integration builds. |
| Normal Android application install and launch | Passed: `adb install -r` returned Success; `am start -W` returned Status ok; process and top resumed activity confirmed; `nextstep.db` exists. |
| Interactive visual inspection | Not performed at this checkpoint: permission to access the emulator window was denied. |
| Development widget render review | Seven final images inspected after typography, hierarchy, spacing, and palette refinements; not a manual device test. |
| `integration_test/session_flow_test.dart` on Android | Passed, 1/1, in the isolated integration package. |
| `integration_test/process_restart_test.dart` across two Android processes | Both seed and verify passed, 1/1 each, with an explicit force-stop between executions and retained SQLite data. |
| Physical Android device / profile-mode performance | Not performed. |

The normal APK was rebuilt with `-t lib/main.dart`, checked to have the
application ID `dev.tyago.nextstep`, installed, and left running on the emulator.
The temporary `dev.tyago.nextstep.integration` package was removed after all
integration stages passed. The delivered file is `dist/NextStep-debug.apk`
(167,738,991 bytes); its SHA-256 is stored beside it in
`dist/NextStep-debug.apk.sha256`. No test fixture was inserted into the normal
application database.

`flutter doctor -v` confirms the Android toolchain, accepted licenses, Java,
network access, and the running Android 16/API 36 emulator. It still reports a
missing Chrome executable; web is outside the validated target. Windows
Hypervisor Platform acceleration was checked as usable without changing host
virtualization settings.

### Setup failures and resolutions

- The initial SDK request failed DNS resolution. Dependency downloads and
  Flutter's localhost test runner required network access; Windows security
  settings were not disabled.
- The Flutter release-index URL returned `NoSuchKey`. The official Flutter Git
  repository supplied the verified 3.50.0 release instead.
- Flutter's first checkout exceeded Windows Git path limits. Enabling
  `core.longpaths` only in the newly downloaded SDK repository and restoring that
  checkout resolved it; no existing repository was reconfigured.
- `avdmanager` emitted a `devices.xml` warning but created the dedicated device.
  Successful emulator boot was separately verified using `sys.boot_completed=1`.
- Permission to access the emulator window was denied; interactive visual
  inspection was not performed at this checkpoint.
- The first process-restart verification could not find its seed database.
  Flutter's default test deployment uninstalled the seed app before installing
  the verification target. The revised procedure requests a separate
  `.integration` application ID and includes `--no-uninstall` on every invocation.
  The first package-selection rule was insufficient because Flutter supplied a
  generated test listener as its build target. The corrected rule was verified
  against APK metadata and Android's installed-package list. The full runner
  then passed all three stages with the isolated package.
- Repeated Android deployments encountered a Dart Development Service connection
  failure. Restarting only the dedicated emulator, without wiping its data,
  restored the connection. Keep DDS enabled: `--no-dds` failed because Flutter's
  integration runner needs its custom event stream. The final successful run
  used the standard DDS configuration.

### Core Android integration command

With the configured emulator running:

```powershell
. .\tool\env.ps1
flutter test integration_test/session_flow_test.dart -d emulator-5554 --no-uninstall --reporter expanded
```

This test uses native Android SQLite in a uniquely named test database. It
exercises the UI flow and closes/reopens the database within the test process.
The verified integration application ID is `dev.tyago.nextstep.integration`,
separate from the normal `dev.tyago.nextstep`. The database is removed during test cleanup. This core-flow
test does not itself force-stop Android.

### Separate Android process-restart check

The following procedure **passed on the Android 16 emulator**. Run all three commands against the same emulator without clearing
application data or uninstalling between phases. `--no-uninstall` is required on
both Flutter invocations:

```powershell
flutter test integration_test/process_restart_test.dart -d emulator-5554 --no-uninstall --dart-define=NEXTSTEP_RESTART_PHASE=seed --reporter expanded
adb -s emulator-5554 shell am force-stop dev.tyago.nextstep.integration
flutter test integration_test/process_restart_test.dart -d emulator-5554 --no-uninstall --dart-define=NEXTSTEP_RESTART_PHASE=verify --reporter expanded
```

Alternatively, `tool/verify-android.ps1` runs the core-flow command followed by
these seed/force-stop/verify steps, stopping on the first failure and writing
logs under the ignored `local-validation/` directory. Its default device is
`emulator-5554`; pass `-Device DEVICE_ID` for another connected Android target.

The seed phase writes a paused session and note to the dedicated
`nextstep_process_restart_test.db`. The verify phase requires that file to still
exist, confirms that a two-hour paused interval adds no elapsed time, resumes
through the UI, completes the task/session, and checks the saved history. It uses
an injected clock for exact expected durations; this is test data, not a product
usage metric. Successful verification removes only that named test database.
Failure retains it for inspection. The integration application's separate sandbox
and the normal application's distinct ID were verified from the APK and device.

## CI and repository state

`.github/workflows/flutter.yml` configures formatting, analysis, host tests, a
debug APK build and Android integration. **GitHub Actions had not run at this
checkpoint**; versioning was local Git. Later remote results and release signing
are recorded in [REVISION_2026_11_20.md](REVISION_2026_11_20.md).

No remote push, store listing, production rollout or external human review was
part of this checkpoint.

## Other platforms and limitations

No web build, iOS run or Windows desktop application was validated. The
host is Windows, but `flutter test` runs the test harness rather than a packaged
Windows app. Release signing, physical-device performance measurements,
battery/background-service tests, export/import, or backup/restore validation
were not performed at this checkpoint.
