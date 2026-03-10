# Voice Runtime Smoke Test (Floating AI Assistant)

## Scope
Validate end-to-end wiring for:
- Lower-right floating AI assistant entry point
- STT (upload path + fallback speech recognition)
- AI response path (voice API first, BOS fallback)
- TTS playback (voice API audio URL + local TTS fallback)
- Interrupt UX and control locking

## Preconditions
- User is authenticated in app.
- User has at least one valid `siteId` context.
- Cloud Function `voiceApi` is deployed and reachable for current Firebase project.
- Device has network access.

## Quick Run (5 minutes)
Use this for daily sanity checks before deeper validation.

1. Open app, confirm lower-right floating AI button appears, open assistant.
2. Tap mic, record a short question, stop recording.
3. Confirm transcript appears in input.
4. Send prompt and confirm response appears.
5. Confirm speaking state appears and audio starts.
6. Tap **Tap to interrupt** and verify playback stops + snackbar appears.
7. Turn voice output off, send another prompt, verify text-only response.

Quick-run pass criteria:
- No crashes or stuck controls.
- STT input works (or shows friendly fallback message).
- AI response arrives via primary path or graceful fallback.
- Interrupt always restores controls immediately.

## 1) Floating assistant surface
1. Launch app and sign in.
2. Confirm floating AI button appears at lower-right.
3. Tap it and confirm sheet opens.
4. Close sheet and confirm no crash.

Expected:
- Open/close interaction is stable.
- Assistant sheet renders mode chips, chat area, and input row controls.

## 2) First-run permission UX (mic)
1. Tap mic button in input row.
2. Deny microphone permission.
3. Tap mic again.

Expected:
- Permission prompt appears when needed.
- If denied, user sees clear message indicating mic permission is required.
- App remains usable for text-only input.

## 3) STT upload path
1. Grant microphone permission.
2. Tap mic to start recording.
3. Speak a short sentence.
4. Tap mic again to stop.

Expected:
- Transcript appears in input field.
- No crash or frozen controls.
- If upload STT fails, user receives friendly fallback message.

## 4) AI request path
1. Send a short prompt from transcript/text.
2. Observe response bubble.

Expected:
- Voice API path should return response in normal network conditions.
- If voice API fails and role is learner, BOS callable fallback should return a coach response.
- If voice API fails and role is non-learner (educator/parent/site/hq), app should return friendly failure without learner-only BOS permission errors.
- Chat remains interactive after response.

## 4A) Session occurrence scoping (BOS context)
1. Open assistant while an educator has an active class in progress.
2. Send one prompt.
3. Repeat with no active class but with recent learner mission attempts.

Expected:
- Assistant initializes without delay-related crashes.
- Runtime resolves best available `sessionOccurrenceId` and BOS listeners initialize with that context.
- Behavior still works when no occurrence is found (graceful null-context operation).

## 4B) Telemetry field verification
Verify in telemetry sink/logs that these fields are present when applicable:
- `voice.transcribe`: `source`, `traceId`, `latencyMs`, `modelVersion`
- `voice.message`: `mode`, `traceId`, `safetyOutcome`, `policyVersion`
- `voice.tts`: `source` (`voice_api_audio`, `flutter_tts`, `user_interrupt`)
- BOS events (`ai_help_opened`, `ai_help_used`, `ai_coach_response`): includes `mode` and, when available, `sessionOccurrenceId`
- Goal reset actions:
  - `cta.clicked` + `cta_id=clear_learning_goals_cancel`
  - `cta.clicked` + `cta_id=clear_learning_goals_confirm`

## 4C) Conversational intelligence checks
1. Send a first question in `hint` mode.
2. Send a second follow-up question referencing the prior answer.
3. Repeat in `verify` and `debug` modes.

Expected:
- Assistant answers reference current context and remain coherent across turns.
- Responses include actionable next steps, not just generic text.
- Responses end with a coaching follow-up question (or equivalent conversational prompt).
- Mode behavior shifts correctly (`hint` vs `verify` vs `debug`).

## 4D) Goals memory controls (educator/HQ)
1. Open assistant as `educator` or `hq`.
2. Confirm **Current goals** row is visible after a few learner turns.
3. Tap **Clear goals**.
4. In dialog, tap **Cancel**.
5. Tap **Clear goals** again, then tap **Clear**.

Expected:
- Confirmation dialog appears before goals are cleared.
- Cancel keeps goals intact.
- Confirm clears all goals immediately.
- Learner/parent roles do not see **Clear goals** action.

## 5) TTS playback path
1. With voice output enabled, send a prompt.
2. Verify speaking state appears.

Expected:
- If `tts.audioUrl` exists, network audio plays.
- If URL playback fails/unavailable, local TTS speaks response text.
- During speaking, send/mic/input are disabled.

## 6) Interrupt controls
1. While assistant is speaking, tap **Tap to interrupt**.

Expected:
- Playback stops immediately.
- Haptic/click feedback occurs where supported.
- Snackbar “Playback stopped” appears briefly.
- Controls re-enable immediately.

## 7) Voice output toggle
1. Turn voice output off.
2. Send prompt.

Expected:
- No playback should occur.
- Text response still appears.

## 8) Platform checks
### Android
- Confirm `RECORD_AUDIO` permission path works on fresh install.
- Verify interrupt + resume behavior after app background/foreground.

### iOS
- Confirm first-run prompts for microphone/speech recognition are shown.
- Verify audio ducking/route behavior does not lock app audio session.

### macOS
- Confirm microphone/speech permission prompts appear.
- Verify transcript and playback function with desktop audio route.

## 9) Regression checks
1. Open/close assistant multiple times (5x).
2. Send consecutive prompts (3–5).
3. Alternate text-only and voice-input prompts.

Expected:
- No memory-like degradation in UI responsiveness.
- No stuck `_isSpeaking` / `_isListening` behavior.
- No duplicate speaking overlays.

## 11) Pass/Fail log template
Use this format per platform:

- Platform:
- Build:
- Network: (Wi-Fi/Cell/Offline)
- Test sections passed: (1..10)
- Failures:
  - Step:
  - Observed:
  - Expected:
  - Repro rate:
- Notes:

## Automated Evidence Snapshot (2026-03-09)

The following automated Flutter voice-runtime slice was executed against the current app baseline:

```bash
flutter test \
  test/bos_voice_integration_test.dart \
  test/ai_coach_widget_regression_test.dart \
  test/ai_coach_regression_test.dart \
  test/global_ai_assistant_overlay_regression_test.dart
```

Observed result:

- 41 tests passed
- 0 tests failed

What this evidence covers:

- Floating AI coach surface renders correctly.
- AI coach contract and regression suite remains stable.
- Auto greeting still speaks through the test override path.
- BOS hesitation auto-assist still triggers a voiced response path.
- Voice-only conversation mode still hides text controls correctly.
- Global overlay auto-popup telemetry still records the BOS trigger metadata.

Additional build-health evidence captured on the same date:

```bash
.fvm/flutter_sdk/bin/flutter analyze
.fvm/flutter_sdk/bin/flutter build apk --debug
.fvm/flutter_sdk/bin/flutter build macos --debug
```

Observed result:

- Analyze: pass
- Android debug build: pass
- macOS debug build: pass

Limits of this automated slice:

- It does not substitute for a live microphone permission check on a physical device.
- It does not prove end-user audio route behavior on Android, iOS, or macOS hardware.
- It validates current control-surface behavior and regression coverage, not a full manual audio-session acceptance pass.

## macOS Live Launch Evidence (2026-03-09)

The built macOS app binary was launched directly from the generated debug product:

```bash
cd apps/empire_flutter/app
build/macos/Build/Products/Debug/scholesa_app.app/Contents/MacOS/scholesa_app
```

Observed result:

- The app process started successfully.
- The process remained alive after launch verification.
- Verified active process name/path matched `scholesa_app`.
- Runtime logs showed repeated telemetry permission-denied responses for `cta.clicked` events.
- Runtime logs also showed a Google sign-in configuration error: `No active configuration. Make sure GIDClientID is set in Info.plist.`

Automated verification command:

```bash
pgrep -fl "scholesa_app|/Contents/MacOS/scholesa_app"
```

Observed result:

- One active process was found for the launched app binary.

What this proves:

- The macOS app can launch beyond build time.
- There is no immediate startup crash in the current debug product.

What this still does not prove:

- Mic permission UX on first interaction
- Live transcript capture through `speech_to_text`
- Real audio route playback through `audioplayers` or `flutter_tts`
- User-interrupt behavior during active playback

Runtime issues observed during unattended launch:

- Telemetry Cloud Function calls can fail with `[firebase_functions/permission-denied] Telemetry origin not allowed.`
- Google sign-in can fail on macOS startup if the platform config does not provide an active `GIDClientID` in the Apple configuration path.

Status:

- Automated macOS runtime launch: pass
- Interactive hardware/audio acceptance: still requires manual operator validation
- macOS launch-time configuration/runtime follow-up: required for telemetry origin policy and Google sign-in configuration

## macOS Live Launch Follow-up (2026-03-09, post runtime patch)

After patching the Flutter client runtime behavior, the macOS debug build was rebuilt and launched again:

```bash
cd apps/empire_flutter/app
.fvm/flutter_sdk/bin/flutter build macos --debug
/Users/simonluke/dev/scholesa/apps/empire_flutter/app/build/macos/Build/Products/Debug/scholesa_app.app/Contents/MacOS/scholesa_app
```

Observed result:

- The app rebuilt successfully.
- The app launched cleanly again.
- The previous anonymous telemetry permission-denied spam did not recur on unattended startup.
- Startup emitted a single client-side notice instead: `TelemetryService: skipping anonymous native telemetry for public events until auth is established.`
- No passive Google sign-in platform exception was observed during this unattended launch sample.

Interpretation:

- Anonymous native public telemetry is now suppressed client-side until Firebase auth exists, which avoids the impossible `origin` check path for macOS native callable traffic.
- Apple Google sign-in still requires proper project configuration to fully work interactively. The Flutter app now surfaces that requirement through an explicit configuration path (`GOOGLE_SIGN_IN_CLIENT_ID` / Apple `CLIENT_ID`) instead of relying on the incomplete bundled plist.

Current status after follow-up:

- Telemetry startup noise on macOS: fixed
- macOS build after patch: pass
- Interactive Apple Google sign-in: still blocked until correct Apple OAuth client configuration is restored

## macOS Apple Config Restoration (2026-03-09, Firebase export-backed)

After retrieving the authoritative Apple SDK configs from the live Firebase project, the app-owned Apple configuration was updated and revalidated:

```bash
cd apps/empire_flutter/app
flutter test test/auth_service_test.dart test/deploy_ops_regression_test.dart
flutter build macos --debug
build/macos/Build/Products/Debug/scholesa_app.app/Contents/MacOS/scholesa_app
```

Observed result:

- The iOS Firebase plist now includes the exported `CLIENT_ID` and `REVERSED_CLIENT_ID` for `com.scholesa.app`.
- The macOS Firebase plist now targets the registered Firebase macOS app and uses bundle ID `com.scholesa.app.macos`.
- Apple `Info.plist` files now include `CFBundleURLTypes` and `GIDClientID` entries required by `google_sign_in` redirect handling.
- Focused Flutter tests passed, including auth-service coverage for Apple Google Sign-In configuration.
- `flutter build macos --debug` passed after the desktop bundle alignment.
- Launching the built macOS binary directly produced a clean Firebase startup log and did not reproduce the prior `No active configuration. Make sure GIDClientID is set in Info.plist.` error on startup.

Remaining limits:

- This machine could not complete a fresh `flutter run -d macos` session because the temporary build volume hit `OS Error: No space left on device`.
- Interactive Google Sign-In still needs one manual click-through validation on macOS to prove the OAuth redirect round-trip succeeds end to end.

Current status after restoration:

- Apple Firebase plist completeness: fixed
- macOS Firebase app/bundle alignment: fixed
- macOS startup-time Google config exception: no longer reproduced in unattended launch sample
- Interactive Apple Google Sign-In: pending manual smoke verification
