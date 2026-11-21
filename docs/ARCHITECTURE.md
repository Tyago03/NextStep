# Architecture

NextStep is a small Android-first Flutter application. Its central workflow is
**plan a concrete task -> start -> pause with context -> reopen -> resume ->
end the session or complete the task -> inspect history**. Plans stay in local
SQLite without user login. Ending a session records the attempt and leaves its
task pending; completing a task also records the session and marks the task done.
Optional online generation uses Firebase AI Logic and has no direct write access
to tasks. Developer-account activation is deferred; see [AI_SETUP.md](AI_SETUP.md).

## Code boundaries

| Location | Responsibility |
| --- | --- |
| `lib/main.dart` | Open the local store; show a recoverable startup error without resetting data. |
| `lib/app.dart` | App theme, Portuguese/English locale, Riverpod scope, and four-screen navigation. |
| `lib/ui/` | Screens, form validation, confirmations, timer display, and centralized UI strings. |
| `lib/application/app_controller.dart` | Load snapshots, serialize writes, prevent duplicate commands, retain failed note drafts, and surface errors. |
| `lib/domain/models.dart` | Immutable goals, tasks, sessions, snapshot selection rules, and elapsed-time calculation. |
| `lib/data/nextstep_repository.dart` | SQLite schema, validation, transactions, CRUD, state transitions, and persistence. |
| `lib/domain/study_plan.dart` | Bounded structured proposals and deterministic study-date calculation. |
| `lib/application/ai_plan_controller.dart` | Separate persistent drafts and explicit confirmation/import. |
| `lib/data/firebase_study_plan_generator.dart` | Lazy Firebase/App Check initialization, structured Gemini request, validation, and translated failure codes. |

The controller publishes an immutable snapshot after a successful write/read.
On a storage failure, it retains the last usable snapshot and reports a localized
error. Form fields remain available for correction or retry. The UI does not
optimistically show an uncommitted database mutation as complete.

A successful mutation followed by a failed snapshot read is treated separately:
the saved form closes, a persistent refresh warning appears, and new mutations
are blocked until a read succeeds. Retrying the warning reads existing data;
it never repeats the completed insert. A modal already open during a refresh
failure offers the same read retry while retaining its fields.

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
uses the native `sqflite` plugin. Schema version is currently **3**; future schema
changes must add a migration and migration tests rather than delete user data.

The v1-to-v2 migration adds goal descriptions, structured task guidance and
scheduled dates, a single proposal draft, and durable import IDs. It preserves
the original tables, sessions, notes and preferences. Importing a proposal inserts
one goal and all its tasks atomically, records its ID, and deletes only its own
draft. A retry cannot duplicate a committed plan, including after a process restart.
The provider is never called when merely loading an existing draft.

The v2-to-v3 migration rebuilds only the sessions table inside the upgrade
transaction to extend its status constraints. It adds `ended` and `ended_at`,
copies old completed timestamps into `ended_at`, and preserves IDs, references,
elapsed time, notes, active sessions, the task index and the session ID sequence.
Goals, tasks, preferences, AI drafts and import IDs remain unchanged. Opening a
v1 database applies both migrations in order; no reset or data deletion is used.

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
[AI_VALIDATION.md](AI_VALIDATION.md).

## Persistent records

| Table | Main stored fields / constraints |
| --- | --- |
| `goals` | Title (1-120 characters), position (0-999), optional plan description. |
| `tasks` | Goal reference, title, estimate (1-240 minutes), position, optional HTTP(S) URL, completed flag; optional topic, study date, steps and completion check. |
| `sessions` | Optional task reference, goal/task title snapshots, status (`running`, `paused`, `ended`, `completed`), UTC start/end/completion timestamps, accumulated milliseconds, next-step note (up to 2,000 characters), active slot. |
| `preferences` | One row containing available minutes (default 25) and language (`pt` by default, or `en`). |
| `plan_draft` | One validated proposal payload, separate from active goals/tasks. |
| `plan_imports` | Unique proposal ID and import timestamp, retained to prevent duplicate imports. |

Foreign keys are enabled on every connection. A session's title snapshots are
recorded when it starts, so later plan edits do not rewrite history. Deleting a
goal cascades to its tasks; deleting a task sets historical session references to
null. Session snapshots and recorded time remain intact. Repository transactions
reject deletion of the task or goal associated with an unfinished session.

The `sessions.active_slot` column is unique: running and paused sessions use the
value `1`; ended and completed sessions use null. A database check ties that slot
to the status and timestamp fields. This prevents multiple active sessions even
if a caller bypasses the UI's disabled buttons. `StudySession.isActive` selects
running/paused; `isFinished` selects ended/completed. `endedAt` records either
terminal outcome; `completedAt` is populated only when the task is completed,
and then equals `endedAt`.

## Session transitions

| Action | Result |
| --- | --- |
| Start an unfinished task | Create one running session with zero accumulated time and `runningSince = now`; copy the note from its most recent ended session, if any. |
| Start the same already-active task again | No-op; do not create a duplicate session. |
| Start a different task while one is active | Reject with an active-session error. |
| Pause | Add the current running interval to accumulated time; clear `runningSince`; store the current note atomically. |
| Resume | Preserve accumulated time and note; set `runningSince = now`. |
| End session (`endSession`) | Consolidate time, save the note, set `ended`/`endedAt` and free the active slot atomically; keep the task pending. |
| Complete task and session | Consolidate time, save the note, set `completed` and both final timestamps, mark the task completed, and free the active slot in one transaction. |

Repeated resume, end or completion does not add duplicate time or history.
Repeated pause keeps elapsed time fixed and may save a newer note. Ended and
completed sessions cannot be resumed or edited; trying to complete an ended
session is rejected. Repeating end on either terminal outcome is a no-op.

An ended session remains immutable history. Returning to its pending task creates
a new session, with a new ID and zero elapsed time. The previous ended note is
copied exactly, including an intentionally empty note, without changing the old
record. A completed task cannot start another session; a new study action should
be represented by a new task.

## Timer and restart policy

The persisted source of truth is accumulated milliseconds plus a UTC timestamp
for the current running interval:

```text
running elapsed = accumulated + max(0, nowUtc - runningSinceUtc)
paused/ended/completed elapsed = accumulated
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

Pause, end and completion wait for queued writes, then commit the current field
value with the transition. A retry action appears only for an unsaved note when no
save is pending. Mutating
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

Available-time presets apply immediately. A custom minute field remains
available. These controls are hidden when a session is active or there is no
unfinished task. New goals/tasks append after existing positions by default;
priority order and reference links are available under More options. Numeric
positions remain limited to 999, with IDs keeping appended items ordered on ties.

Progress totals finished sessions (`ended` and `completed`). It displays recorded
durations, end dates, snapshots, notes and each session's outcome. An ended
session contributes its studied time without implying that its task was
completed. Active and paused time is excluded from these totals. Progress does
not estimate learning outcomes or invent usage counts.

## Local data and scope limits

The default file is `nextstep.db` in the platform database directory. There is no
cloud synchronization, application-level database encryption, or export/import
flow. The Android manifest sets `allowBackup="false"`; the app does not implement
cloud backup. Clearing app data or uninstalling can remove the local records.

HTTP(S) links are validated and launched in an external browser on request. No
remote content is fetched for ordinary manual suggestions. Explicit AI generation
sends the supplied topic and routine to Gemini through Firebase AI Logic, with
App Check. No existing plans or session history are included. There is no
advertisement SDK or sign-in flow. All tests use explicit fixtures instead of
live AI responses until the developer project is activated.

AI availability is checked locally before showing the request form. Without
configuration, the screen explains that generation is unavailable and offers a
return to the manual plan; it does not collect an unusable request. This check
does not promise network access, quota or service availability. An existing
saved proposal remains reviewable and explicitly importable offline even when
generation is unavailable. There is no synthetic fallback in the normal app.

The UI has Portuguese and English strings, scrollable forms and screens, and
larger-text navigation that uses two rows rather than compressing four labels.
Host tests exercise empty and populated 320-pixel layouts with 2x text scaling;
that is a concrete layout check, not a claim of a full accessibility audit.

The application was created for this project with Codex implementation and
review assistance. No academic application code was imported. Packaging,
on-device evidence, and outstanding validation are tracked separately in
[VALIDATION.md](VALIDATION.md).
