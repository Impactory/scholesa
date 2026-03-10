# Flutter Android Warning Audit And Upgrade Plan

Last reviewed: 2026-03-09
Scope: `apps/empire_flutter/app`

## Summary

The current Flutter app is buildable on both Android and macOS without app-code errors:

- `flutter analyze` -> clean
- `flutter build apk --debug` -> pass
- `flutter build macos --debug` -> pass

The remaining Android warning noise under `./gradlew ... --warning-mode all` is overwhelmingly owned by third-party plugin Gradle scripts in pub cache, not by Scholesa app sources. A normal in-range dependency refresh does not remove those warnings today.

## Verified Build Baseline

Commands verified on 2026-03-09 from `apps/empire_flutter/app`:

```bash
.fvm/flutter_sdk/bin/flutter analyze
.fvm/flutter_sdk/bin/flutter build apk --debug
.fvm/flutter_sdk/bin/flutter build macos --debug
```

Observed outcome:

- Analysis succeeds with no issues.
- Android debug APK builds successfully.
- macOS debug app builds successfully.

Local repo-owned warning reduction already in place:

- `android/gradle.properties` enables `--enable-native-access=ALL-UNNAMED` to suppress the JDK 21 restricted-native-access warning in the normal Flutter Android build path.
- macOS Runner config layering was fixed separately so CocoaPods/xcconfig handling is stable and the duplicate `-lc++` / `-lz` linker warning is suppressed.

## Current Warning Ownership

The command below was used to force Gradle to print the remaining Android warning surface:

```bash
cd apps/empire_flutter/app/android
./gradlew app:compileDebugJavaWithJavac --warning-mode all --console=plain
```

Warnings currently map to the following plugin scripts under `~/.pub-cache/hosted/pub.dev/`:

| Plugin surface | Resolved version | Latest published status | Warning class | Ownership | Recommendation |
| --- | --- | --- | --- | --- | --- |
| `audioplayers_android` | `5.2.1` | Parent package `audioplayers` is already at current 6.x latest | Groovy space-assignment syntax (`group`, `version`, `compileSdk`, `namespace`) | Upstream plugin build script | Track upstream only; no Scholesa-side fix worth carrying |
| `cloud_firestore` | `6.1.3` | Latest on pub.dev | Groovy space-assignment syntax and legacy `compileSdkVersion` / `minSdkVersion` style | Upstream FlutterFire Android script | Wait for FlutterFire upstream cleanup |
| `cloud_functions` | `6.0.7` | Latest on pub.dev | Groovy space-assignment syntax and legacy Android Gradle DSL usage | Upstream FlutterFire Android script | Wait for upstream cleanup |
| `connectivity_plus` | `7.0.0` | Latest on pub.dev | Groovy space-assignment syntax in plugin Gradle file | Upstream plugin build script | Wait for upstream cleanup |
| `file_picker` | `10.3.10` | Latest on pub.dev | Groovy space-assignment syntax in plugin Gradle file | Upstream plugin build script | Wait for upstream cleanup |
| `firebase_auth` | `6.2.0` | Latest on pub.dev | Groovy space-assignment syntax in plugin Gradle file | Upstream FlutterFire Android script | Wait for upstream cleanup |
| `firebase_core` | `4.5.0` | Latest on pub.dev | Groovy space-assignment syntax plus older DSL accessors | Upstream FlutterFire Android script | Wait for upstream cleanup |
| `firebase_storage` | `13.1.0` | Latest on pub.dev | Groovy space-assignment syntax plus older DSL accessors | Upstream FlutterFire Android script | Wait for upstream cleanup |
| `flutter_tts` | `4.2.5` | Latest on pub.dev | Groovy space-assignment syntax in plugin Gradle file | Upstream plugin build script | Wait for upstream cleanup |
| `record_android` | `1.5.1` | Parent package `record` remains in supported 6.x line; verify upstream changelog before widening | Warninging plugin is Android-side; no repo-local source issue found | Likely upstream | Only revisit during an intentional voice stack upgrade |
| `speech_to_text` | `7.3.0` | Latest on pub.dev | Groovy space-assignment syntax and `Task.project` deprecation at execution time | Upstream plugin Gradle/task wiring | Highest-value upstream watch item |

## Why A Simple Upgrade Pass Does Not Fix This

`flutter pub outdated` shows direct dependencies are already at the newest resolvable versions within the currently approved major ranges in `DEPENDENCY_BASELINE_SCHOLESA.md`.

That means:

1. A standard `flutter pub upgrade` within current majors does not materially change the warning surface.
2. Several warninging packages are already at their latest published versions.
3. Eliminating the remaining warnings requires upstream plugin maintainers to modernize their Android Gradle scripts.

## Constrained Upgrade Plan

This plan is intentionally conservative. It is designed to widen dependency ranges only when the expected benefit is greater than the regression risk.

### Phase 0: Freeze The Known-Good Baseline

Before any dependency edits:

```bash
cd apps/empire_flutter/app
.fvm/flutter_sdk/bin/flutter analyze
.fvm/flutter_sdk/bin/flutter build apk --debug
.fvm/flutter_sdk/bin/flutter build macos --debug
```

Required pass criteria:

- No analyzer errors
- Android debug build passes
- macOS debug build passes

If disk pressure interferes with builds, clear only generated artifacts:

```bash
rm -rf build android/.gradle .dart_tool
```

### Phase 1: Optional Manifest Floor Alignment

Goal: raise selected `pubspec.yaml` minimums to the already-resolved patch/minor versions, without changing majors.

Candidate set:

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_storage`
- `cloud_functions`
- `flutter_tts`

Why this is optional:

- It documents the actual tested floor more accurately.
- It does **not** remove the current Gradle deprecation warnings by itself.
- It should be done only as a lockstep FlutterFire hygiene change, not as an isolated warning-fix attempt.

### Phase 2: Voice Stack Upgrade Window

Goal: evaluate the packages most likely to affect BOS and voice runtime behavior together, not independently.

Candidate set:

- `audioplayers`
- `record`
- `speech_to_text`
- `flutter_tts`

Why this needs a dedicated window:

- Audio/session lifecycle regressions are higher risk than the Gradle warnings themselves.
- `speech_to_text` is the only currently warninging plugin that also emits the `Task.project` deprecation, so it is the most likely package to change warning shape when upstream updates land.
- The BOS voice path needs runtime QA on microphone permissions, playback start/stop, background interruptions, and repeated init/dispose cycles.

### Phase 3: FlutterFire Lockstep Refresh

Only run this phase when upstream FlutterFire publishes newer Android build-script cleanups.

Upgrade together as a set:

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_storage`
- `cloud_functions`

Do not upgrade these one by one across major lines.

## Rollout Gates

Every phase above must pass all of the following before it is kept:

1. `flutter analyze`
2. `flutter build apk --debug`
3. `flutter build macos --debug`
4. Manual voice sanity pass:
   - BOS playback starts and stops
   - TTS still speaks
   - Speech recognition still initializes and returns results
   - Recorder permission prompt and recording flow still work
5. Manual auth sanity pass:
   - Firebase app init succeeds
   - Sign-in still works
   - Firestore reads still load a dashboard

## Rollback Rules

Rollback immediately if any of the following appear:

- Generated plugin registrant mismatch on Android
- New pod-install or Xcode build failures on macOS
- Regressions in BOS audio, speech recognition, or microphone recording
- FlutterFire initialization or sign-in regressions
- New required platform configuration changes not already covered by the repo

Rollback procedure:

1. Revert the manifest and lockfile change set.
2. Run `flutter clean`.
3. Run `flutter pub get`.
4. Re-run the three baseline commands.

## Practical Recommendation

Do not make a speculative dependency edit solely to chase the remaining Android Gradle deprecation noise.

The best current posture is:

- Keep the repo-owned warning fixes already applied.
- Treat the remaining Android warning set as upstream plugin debt.
- Revisit upgrades when either:
  - a warninging plugin publishes an Android Gradle script modernization, or
  - Scholesa already needs a planned voice or FlutterFire upgrade for feature work.

## Watch List

Monitor these packages first for upstream Android Gradle cleanup releases:

1. `speech_to_text`
2. `firebase_core`
3. `firebase_auth`
4. `cloud_firestore`
5. `cloud_functions`
6. `firebase_storage`
7. `audioplayers`
8. `flutter_tts`
9. `file_picker`
10. `connectivity_plus`

When one of the above lands a build-script cleanup, rerun the warning audit command before deciding to widen Scholesa's dependency floor.

## Upstream Issue Templates

Use the template below when opening or updating upstream issues for packages that still emit Gradle 8.14 deprecation warnings.

```text
Title: Android Gradle warning cleanup for Gradle 8.14 / Gradle 10 compatibility

Environment:
- Flutter: 3.38.9
- Gradle: 8.14
- Java: 21
- AGP: Flutter-managed project in active stable toolchain

Observed behavior:
- The plugin builds successfully, but emits Gradle deprecation warnings under:
  ./gradlew app:compileDebugJavaWithJavac --warning-mode all --console=plain

Warning class:
- Groovy space-assignment syntax is deprecated and scheduled for removal in Gradle 10
- If applicable: Task.project at execution time has been deprecated and is incompatible with configuration cache

Relevant plugin version:
- <plugin version>

Relevant lines:
- <path:line>

Expected behavior:
- Plugin Android Gradle scripts should build cleanly under Gradle 8.14 warning mode and avoid APIs scheduled for removal in Gradle 10.

Notes:
- This was reproduced from a consuming Flutter app without modifying plugin source.
- App code builds and runs correctly; the issue is limited to plugin Gradle script modernization.
```

Recommended issue targets from the current Scholesa warning set:

1. FlutterFire Android build scripts:
   `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_storage`
   Use one shared issue if the same Gradle DSL patterns are still present across the FlutterFire Android package templates.
2. Voice and audio plugins:
   `speech_to_text`, `audioplayers_android`, `flutter_tts`, `record_android`
   Prioritize `speech_to_text` first because it also emits the `Task.project` execution-time deprecation.
3. Utility plugins:
   `file_picker`, `connectivity_plus`
   These are lower runtime-risk for Scholesa, but still good candidates for upstream cleanup requests.