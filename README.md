# NextStep

A small offline Flutter app for turning a study goal into a concrete next action,
starting a session, and preserving the context needed after an interruption.
Created as a new personal project for Tyago, with implementation and review
assistance from OpenAI Codex. No code from classmates' projects is reused.

## Scope

Android first. Local SQLite storage, no account, backend, advertising, or AI
inside the app. Today suggests an unfinished task that fits the available time;
Plan manages goals and ordered tasks; Session keeps a timer and next-step note;
Progress displays the actual completed sessions. Portuguese and English.

## Development status

Implementation and local environment preparation are in progress. Test and build
results will be recorded after the commands actually execute. This repository
does not claim production use, real users, store publication, or validated iOS/web
support.

## Local tool isolation

The Windows setup uses portable SDKs in `../.nextstep-tools`. From this directory,
load `. ./tool/env.ps1` in PowerShell to set paths only in that terminal. It does
not modify the machine PATH, other projects, or global Git settings.

## Architecture decisions

- Flutter and Riverpod, with no generated state-management code.
- Immutable domain models and a SQLite repository with atomic transactions.
- `sqflite` replaces the proposed Drift for this first small version. This keeps
  SQLite transactions and schema versions while avoiding a code-generation
  pipeline. FFI uses the same SQL repository for real-file host tests.
- At most one unfinished session. Double commands are guarded in both UI and
  storage. Completion updates the session and task in one transaction.
- A running session counts time across closing the app, using saved UTC
  timestamps. Pausing freezes time. Background execution is not required.
- History keeps title snapshots when a plan changes. Active work cannot be
  deleted; other deletes require confirmation in the UI.

## Limits

Device clock changes can affect a running interval; negative intervals are
clamped to zero. Local data is not encrypted or synchronized. A release for an
app store, cloud backup, home-screen widgets, and export/import are outside this
MVP.

## Official setup references

- [Flutter installation](https://docs.flutter.dev/install/manual)
- [Android tools](https://developer.android.com/studio#command-line-tools-only)
- [Microsoft OpenJDK](https://learn.microsoft.com/en-us/java/openjdk/download)
- [SQLite plugin](https://pub.dev/packages/sqflite)
