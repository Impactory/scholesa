# RC3 Sign-Off Checklist (Floating AI Runtime)

**Release:** 1.0.0-rc.3  
**Date:** ____________________  
**Build/Commit:** ____________________

## Owners
- **Engineering Owner:** ____________________
- **QA Owner:** ____________________
- **Product Owner:** ____________________
- **Release Manager:** ____________________

---

## 1) Build & Test Gates
- [ ] `flutter analyze` passed in `apps/empire_flutter/app`
- [ ] `flutter test` passed in `apps/empire_flutter/app`
- [ ] Golden baselines reviewed/updated for intentional UI changes
- [ ] No unresolved P0/P1 issues for floating AI runtime scope

## 2) End-to-End Wiring Gates (AI/BOS/TTS/STT)
- [ ] Floating AI opens from lower-right FAB for all intended roles
- [ ] STT upload path works (`/voice/transcribe`)
- [ ] STT fallback path works (on-device speech recognition)
- [ ] AI response path works (`/copilot/message`)
- [ ] Learner-only BOS fallback verified when voice API unavailable
- [ ] Session occurrence scoping present when context is available
- [ ] TTS URL playback works when `tts.audioUrl` is present
- [ ] Local TTS fallback works when URL playback unavailable
- [ ] Interrupt flow works (stop playback + control restore)

## 3) Role & Safety Gates
- [ ] Non-learner roles do not hit learner-only BOS permission path
- [ ] Conversational responses remain coaching-oriented (no final graded answers)
- [ ] Goals memory control visible only for educator/HQ
- [ ] Clear-goals confirmation dialog cancel/confirm flows verified

## 4) Platform Gates
### Android
- [ ] Microphone permission flow verified
- [ ] Voice input/output and interrupt verified on device

### iOS
- [ ] Microphone + speech recognition permissions verified
- [ ] Voice input/output and interrupt verified on device

### macOS (if included)
- [ ] Microphone + speech recognition permissions verified
- [ ] Voice input/output and interrupt verified on device

## 5) Telemetry Gates
- [ ] `voice.transcribe` events present with expected metadata
- [ ] `voice.message` events present with expected metadata
- [ ] `voice.tts` events present for audio/fallback/interrupt sources
- [ ] BOS events (`ai_help_opened`, `ai_help_used`, `ai_coach_response`) present
- [ ] Goal reset events logged (`clear_learning_goals_cancel`, `clear_learning_goals_confirm`)

## 6) Documentation Gates
- [ ] Smoke checklist completed: `docs/VOICE_RUNTIME_SMOKE_TEST.md`
- [ ] RC3 gate doc reviewed: `docs/vibe/RC3_RELEASE_GATE.md`
- [ ] Dependency baseline reviewed: `docs/DEPENDENCY_BASELINE_SCHOLESA.md`

---

## Final Sign-Off
- **Engineering Owner Sign-Off:** ____________________  Date: __________
- **QA Owner Sign-Off:** ____________________  Date: __________
- **Product Owner Sign-Off:** ____________________  Date: __________
- **Release Manager Approval (GO/NO-GO):** ____________________  Date: __________

## Notes / Exceptions
________________________________________________________________________________
________________________________________________________________________________
________________________________________________________________________________
