# Architecture

NextStep is a small Android-first Flutter application. Its central workflow is
**plan a concrete task -> start -> pause with context -> reopen -> resume ->
complete -> inspect history**. It has no backend or account boundary.

## Code boundaries

| Location | Responsibility |
| --- | --- |
| `lib/main.dart` | Open the local store; show a recoverable startup error without resetting data. |
| `lib/app.dart` | App theme, Portuguese/English locale, Riverpod scope, and four-screen navigation. |
| `lib/ui/` | Screens, form validation, confirmations, timer display, and centralized UI strings. |
| `lib/application/app_controller.dart` | Load snapshots, serialize writes, prevent duplicate commands, retain failed note drafts, and surface errors. |
| `lib/domain/models.dart` | Immutable goals, tasks, sessions, snapshot selection rules, and elapsed-time calculation. |
| `lib/data/nextstep_repository.dart` | SQLite schema, validation, transactions, CRUD, state transitions, and persistence. |

The controller publishes an immutable snapshot after a successful write/read.
On a storage failure, it retains the last usable snapshot and reports a localized
error. Form fields remain available for correction or retry. The UI does not
optimistically show an uncommitted database mutation as complete.

Riverpod is used without generated provider code. The official `material_ui`
package supplies Material components and localization delegates; it replaces the
deprecated `package:flutter/material.dart` import in the pinned Flutter release.

## SQLite instead of Drift for this MVP

The briefing proposed Drift/SQLite. This implementation keeps SQLite but uses
`sqflite` with explicit SQL and mapping code. The small schema needs transactions,
constraints, and versioning; it does not yet need generated query APIs or reactive
joins. Avoiding a generator reduces setup and keeps the complete state transition
visible in one repository method. The tradeoff is that SQL and row mappings need
direct tests instead of generated type checking.

`sqflite_common_ffi` is a development dependency used to execute the same
repository against real SQLite files on the Windows test host. The Android app
uses the native `sqflite` plugin. Schema version is currently **1**; future schema
changes must add a migration and migration tests rather than delete user data.

Android integration targets use a separate, verified application sandbox:
`dev.tyago.nextstep.integration`, while the normal app remains
`dev.tyago.nextstep`. Separate package IDs are needed to protect ordinary app data
from test deployment; a uniquely named test database alone does not provide that
protection. The build's package selection was verified against generated APK
metadata and Android's installed-package list.

Every Flutter integration invocation also passes `--no-uninstall`. This preserves
the integration sandbox between the restart test's seed and verify phases. The
runner targets `dev.tyago.nextstep.integration` for a force-stop between those
phases; it does not clear app data. `tool/verify-android.ps1` implements the
sequence, while `tool/run-android.ps1` continues to launch the normal application.
The complete integration sequence passed on the emulator, as recorded in
[VALIDATION.md](VALIDATION.md).

## Persistent records

| Table | Main stored fields / constraints |
| --- | --- |
| `goals` | Title (1-120 characters), position (0-999). |
| `tasks` | Goal reference, title, estimate (1-240 minutes), position, optional HTTP(S) URL, completed flag. |
| `sessions` | Optional task reference, goal/task title snapshots, status, UTC timestamps, accumulated milliseconds, next-step note (up to 2,000 characters), active slot. |
| `preferences` | One row containing available minutes (default 25) and language (`pt` by default, or `en`). |

Foreign keys are enabled on every connection. A session's title snapshots are
recorded when it starts, so later plan edits do not rewrite history. Deleting a
goal cascades to its tasks; deleting a task sets historical session references to
null. Session snapshots and recorded time remain intact. Repository transactions
reject deletion of the task or goal associated with an unfinished session.

The `sessions.active_slot` column is unique: running and paused sessions use the
value `1`; completed sessions use null. A database check ties that slot to the
status and timestamp fields. This prevents multiple unfinished sessions even if
a caller bypasses the UI's disabled buttons.

## Session transitions

| Action | Result |
| --- | --- |
| Start an unfinished task | Create one running session with zero accumulated time and `runningSince = now`. |
| Start the same already-active task again | No-op; do not create a duplicate session. |
| Start a different task while one is active | Reject with an active-session error. |
| Pause | Add the current running interval to accumulated time; clear `runningSince`; store the current note atomically. |
| Resume | Preserve accumulated time and note; set `runningSince = now`. |
| Complete task and session | Consolidate time, save the note, mark the session and task completed, and free the active slot in one transaction. |

Repeated resume or completion does not add duplicate time or history. Repeated
pause keeps elapsed time fixed and may save a newer note. Completed sessions are
not editable through note/state commands. A completed task cannot start another
session; a new study action should be represented by a new task.

## Timer and restart policy

The persisted source of truth is accumulated milliseconds plus a UTC timestamp
for the current running interval:

```text
running elapsed = accumulated + max(0, nowUtc - runningSinceUtc)
paused/completed elapsed = accumulated
```

A one-second UI timer only refreshes the display. It does not increment stored
time and is not required to run in the background. A running session continues
counting across app closure; an explicitly paused session does not. The session
screen explains this policy.

The repository and app clock are injectable for deterministic tests. Changes to
the device wall clock can affect a running interval; backward intervals are
clamped to zero. The app does not claim a monotonic timer across process death,
automatic interruption detection, or background-service execution.

## Note writes and failure behavior

Every note edit is queued in order. The controller retains the latest draft until
a database snapshot acknowledges it. Leaving and returning to a tab does not
discard a pending or failed draft. Successful unrelated actions do not falsely
mark that draft as saved.

Pause and completion wait for queued writes, then commit the current field value
with the transition. The explicit Save note action retries a write. Mutating
buttons are disabled while a command is in progress, and the controller rejects
a second concurrent command. Note writes capture the repository before entering
the queue, allowing already queued work to finish if the provider scope is
disposed while the database remains open.

These guarantees apply to acknowledged storage operations. An operating-system
kill can interrupt a write that is still marked as saving. There is no promise
that an unacknowledged final keystroke survives forced termination.

## Suggestion and progress rules

Today prioritizes the unfinished session. Otherwise, it considers goals by
ascending position, then tasks by ascending position; IDs break ties. It suggests
the first incomplete task whose estimate fits the available minutes. If none
fits, it says so instead of silently recommending a longer task.

Progress totals only completed sessions. It displays recorded durations,
completion dates, snapshots, and notes. It does not estimate learning outcomes,
invent usage counts, or present an active session's time as completed work.

## Local data and scope limits

The default file is `nextstep.db` in the platform database directory. There is no
cloud synchronization, application-level database encryption, or export/import
flow. The Android manifest sets `allowBackup="false"`; the app does not implement
cloud backup. Clearing app data or uninstalling can remove the local records.

HTTP(S) links are validated and launched in an external browser on request. No
remote content is fetched to generate tasks or suggestions. There is no embedded
AI, advertisement SDK, or sign-in flow.

The UI has Portuguese and English strings, scrollable forms and screens, and
larger-text navigation that uses two rows rather than compressing four labels.
Host tests exercise empty and populated 320-pixel layouts with 2x text scaling;
that is a concrete layout check, not a claim of a full accessibility audit.

The application was created for this project with Codex implementation and
review assistance. No academic application code was imported. Packaging,
on-device evidence, and outstanding validation are tracked separately in
[VALIDATION.md](VALIDATION.md).
