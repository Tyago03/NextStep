# Distribution preparation — 0.3.0

**Status: local candidate only. No GitHub Release or public download exists.**
Physical-device validation and Tyago's distribution approval are pending.
This documentation round adds no application features and keeps version 0.3.0+3.

## Candidate identity

| Field | Verified value |
| --- | --- |
| APK | `dist/NextStep-0.3.0-release.apk` |
| Version / code | 0.3.0 / 3 |
| Production source commit | `7592ce3507f5185f2470e5c0b7831cfe457ad484` |
| Application ID | `dev.tyago.nextstep` (normal app) |
| Android | Minimum API 24 / Android 7.0; target API 36 |
| Native ABIs | `arm64-v8a`, `armeabi-v7a`, `x86_64` |
| Debuggable | Absent in the signed APK manifest |
| Size | 55,127,375 bytes (52.6 MiB) |
| APK SHA-256 | `fb96a8c3cd1e56b6a9ca53fae3022c361f7c41206d017f5491582870ee3a9350` |
| Signing certificate SHA-256 | `f2e123799b98c04ae5aa674f3be54372db5a1f5e5cb2177a39c4df78a9ac452c` |

The APK was built from the production commit above and used in the recorded
emulator demonstration. Later test/documentation commits leave its application
source unchanged. ARM32 and ARM64 libraries are present; this does not establish
compatibility with every phone. Fill in [DEVICE_TEST.md](DEVICE_TEST.md) using
this exact file and hash before approving distribution.

`apksigner verify --verbose --print-certs` verifies the APK's v2 signature and its
own RSA-3072 certificate, `CN=NextStep, OU=Mobile, O=NextStep, C=BR`.
`aapt dump badging` and `aapt dump xmltree` verify package, SDKs, ABIs and flags.
Do not substitute an integration or debug APK.

## Prepared release files

The ignored `dist/release-preparation/` folder contains the candidate APK, its
SHA-256 file, release notes, verification record and third-party notices. The
proposed release name is **NextStep 0.3.0**; preparing those files creates no tag
or GitHub Release. The verification record identifies the current documentation
commit, clean-checkout result and corresponding Actions run once completed.

Video: `dist/demo/NextStep-0.3.0-demo.mp4`, 2:30, English captions, no audio.
SHA-256: `e6794fa06bf9c683cdfc6bce37a80fc97a6abca219280a2a6301f5198325f71b`.
Screenshots in `docs/images/` show the same release with synthetic study data.
Neither APK nor video is a published download. See [presentation](PORTFOLIO.md).

## Installation and signing

Transfer the verified APK to a compatible Android phone and open it. If prompted,
allow installation for the file-opening app. An existing debug installation has
a different certificate; do not uninstall it just to install this candidate if
its local data matters. Test on another device/profile or retain that installation.
Future updates require the same release key and an appropriate version code.

The existing keystore remains outside the repository. `android/key.properties`,
passwords, private Firebase configuration and databases are ignored by Git.
Preserve the matching signing files privately; do not regenerate the key for an
update. `tool/prepare-signing.ps1` preserves existing signing material.

The prepared Windows environment can rebuild with `tool/build-distribution.ps1`.
A rebuild writes new output and must have its own hash and verification; do not
assume it is byte-identical to this candidate. Standard source execution and debug
builds need no release key or Firebase configuration; see the [README](../README.md).
The local release rebuild on 21 November 2026 produced the same SHA-256 as this
candidate. That observation is limited to this build environment.

## Before any publication

Keep the repository private and the Release unpublished until device results and
explicit approval arrive. Review the final files and repository history again
if they change. Automated secret checks reduce risk but cannot certify that a
repository contains no sensitive data.
Removed work notes and local-machine paths remain in older commits. The history
was inspected and preserved; removing a file from the current tree does not
remove its earlier versions. Review that history before any future public access.

Third-party notices embedded in the APK are preserved. No license for the
project's own source has been selected; do not imply a new open-source license
or remove dependency notices. Live Firebase/Gemini remains inactive, and no
backup, login or synchronization is included.
