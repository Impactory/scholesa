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
- If voice API fails, BOS callable fallback still returns a coach response.
- Chat remains interactive after response.

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

## 10) Pass/Fail log template
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
