# Optional Firebase/Gemini integration

## Current availability

**Live AI is not activated or validated.** The release APK supports manual
planning and local sessions without Firebase configuration, credentials or
network access. Its AI entry shows an unavailable notice before collecting a
request. No fixture response is used in the normal app.

The prepared adapter selects `gemini-3.5-flash-lite` through the Gemini Developer
API via Firebase AI Logic. Model availability, quotas, pricing and eligibility
must be checked before activation; this project does not promise permanent or
unlimited free use. [Firebase pricing](https://firebase.google.com/docs/ai-logic/pricing)
describes the distinction between the SDK and provider usage costs.

## Data and confirmation

When enabled, generation sends the entered topic and study preferences to Google,
plus connection/App Check data. It does not attach existing tasks, notes or
session history. Generated proposals are stored locally as drafts; only explicit
confirmation imports goals/tasks, in a transaction protected against duplication.
Existing drafts remain reviewable and importable offline.

Under applicable unpaid-service terms, Google may use submitted content and
responses to improve its services. Avoid sensitive information; review the
[Gemini API terms](https://aistudio.google.com/docs/terms) before activation.
Local plan storage does not mean local inference.

No student login, anonymous authentication, cloud database or synchronization
is implemented. Firebase Authentication is a transitive SDK dependency, not an
app sign-in flow. Deleting app data can remove the local plan and drafts; backup
and export are not available.

## Configuration for a later activation

These external steps are **pending** and are not part of the current release:

1. Create a dedicated Firebase project, review provider terms/quotas and retain
   the intended no-billing setup if eligible. Do not enable paid services implicitly.
2. Register Android package `dev.tyago.nextstep` and configure Firebase AI Logic
   with the Gemini Developer API.
3. Register App Check and the appropriate signing identity. Keep enforcement
   enabled. Debug builds use the debug provider; release builds use Play Integrity.
   Release/sideload attestation must be validated before offering live AI.
4. Download the Android configuration and convert it locally:

```powershell
.\tool\configure-firebase.ps1 -GoogleServicesJson 'path/to/google-services.json'
```

The script validates the package and writes ignored `config/firebase.local.json`
without changing the remote project or replacing existing configuration.
`config/firebase.example.json` documents the expected fields. Never embed a
Gemini secret, service-account key or App Check debug token in the app or Git.

Build or run with standard commands after configuration:

```sh
flutter run --dart-define-from-file=config/firebase.local.json
flutter build apk --release --dart-define-from-file=config/firebase.local.json
```

A release build also requires the existing private signing configuration;
see [distribution](DISTRIBUTION.md). Without the define file, AI stays unavailable.
Firebase/App Check initializes only when generation is requested. Configuration
alone does not prove network access, quota, attestation or provider availability.

## Required checks before enabling generation

Use synthetic topics to check real Portuguese/English responses, progression,
completion checks, time limits, quota and network failures, recovery, and explicit
confirmation before imports. Fixture tests validate local behavior, not provider
quality. Keep the privacy notice accurate for the selected provider and plan.

Official configuration references:
[Flutter setup](https://firebase.google.com/docs/ai-logic/get-started?platform=flutter),
[App Check](https://firebase.google.com/docs/ai-logic/app-check).
Historical fixture results remain in [AI_VALIDATION.md](AI_VALIDATION.md).
