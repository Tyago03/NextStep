# Architecture

NextStep is an Android-first Flutter application with local SQLite storage and
no user account. The available workflow is plan → start → pause → resume →
finish for now or complete the task. Optional Firebase/Gemini generation is
prepared but inactive in the distributed APK; see [AI_SETUP.md](AI_SETUP.md).

## Boundaries

| Location | Responsibility |
| --- | --- |
| `lib/ui/` and `lib/app.dart` | Screens, localized strings, forms and navigation. |
| `lib/application/` | Immutable snapshots, serialized writes, duplicate-command protection and recoverable errors. |
| `lib/domain/` | Models, time calculations, task suggestions and structured proposals. |
| `lib/data/` | SQLite transactions, migrations and the optional Firebase adapter. |

Riverpod connects the UI to the application controller. `sqflite` provides native
Android storage; `sqflite_common_ffi` runs the same repository against SQLite in
host tests. Explicit SQL keeps this small schema inspectable, with direct tests
for mappings, constraints and transactions.

## Persistent records and migrations

Schema **3** stores goals, tasks, sessions, preferences, one proposal draft and
import identifiers. Sessions retain title snapshots, timestamps, accumulated
milliseconds and a next-step note. Foreign keys are enabled. Deleting a task
preserves historical snapshots; deleting a task or goal with an active session
is rejected.

The v1→v2 migration adds structured tasks, drafts and import tracking. The v2→v3
migration rebuilds only `sessions` transactionally, adding `ended` and `ended_at`.
It preserves IDs, references, notes, elapsed time, indexes and the autoincrement
sequence. Both migrations run when opening v1 data; failure rolls back instead
of resetting the database.

## Session rules

| Action | Persistent result |
| --- | --- |
| Start a pending task | New running session, zero elapsed time, previous ended-session note copied exactly, including an empty note. |
| Pause | Add the running interval, save the note and clear `runningSince`. |
| Resume | Keep elapsed time and note; set a new `runningSince`. |
| Finish for now | Save time and note, set `ended`/`endedAt`, release the active slot; keep the task pending. |
| Complete task | Save time and note, set `completed` and both end timestamps; mark the task complete in the same transaction. |

A unique `active_slot=1` and status constraints allow only one running or paused
session. Finished sessions use a null slot and cannot be edited or resumed.
Repeated start/resume/end/completion commands do not duplicate time or records.
Completed tasks cannot start again; a new study action needs a new task.

Time is calculated from persisted timestamps:

```text
running = accumulated + max(0, nowUtc - runningSinceUtc)
paused / ended / completed = accumulated
```

The display timer does not store elapsed seconds. Running time continues across
app closure; pausing stops it. Device clock changes can affect an interval.
Progress sums finished intervals once, excludes active/paused sessions, and
records whether each session ended with its task pending or complete.

## Writes and recovery

Notes save in order. Pause/end/completion wait for queued edits and commit the
current note with the transition. Failed drafts remain visible with a retry.
Only acknowledged writes are durable; a forced termination can interrupt an
edit still marked as saving.

If a write succeeds but refreshing the snapshot fails, retry reads existing
data instead of repeating the mutation. Concurrent commands are rejected while
an operation is pending. Startup errors expose a retry without deleting data.

## Suggestions, privacy and testing

Suggestions use goal/task priority, ID order and available minutes. Scheduled
dates are advisory. HTTP(S) reference links open externally only when selected.
Manual planning and sessions do not call Firebase or require network access.

There is no login, synchronization, export/import or app-level database
encryption. Android backup is disabled. Uninstalling or clearing data can remove
the local database. Optional AI proposals remain drafts until confirmed;
transactional imports retain an ID to prevent duplicate tasks after retries.

Android integration uses `dev.tyago.nextstep.integration`, separate from the
normal `dev.tyago.nextstep` package. All four stages use `--no-uninstall`; a
force-stop between the restart phases checks persisted state without clearing
it. Host tests also cover narrow screens and enlarged PT/EN text; they do not
replace physical-device or accessibility testing. See [validation](VALIDATION.md)
and the [reported physical-device acceptance](DEVICE_TEST.md), whose device/APK
identification and individual test evidence remain unrecorded.
