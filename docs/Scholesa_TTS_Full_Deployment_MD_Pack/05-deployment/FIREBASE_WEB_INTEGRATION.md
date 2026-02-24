# Firebase Web Integration (Copilot Widget + Voice)

## UI components
- Floating Copilot button (bottom-right)
- Drawer panel with:
  - mic button (primary)
  - transcript preview
  - voice playback controls
  - "quiet mode" indicator (if set by teacher)

## Voice-first nudges (student)
- Default mic prompt: "Tap and speak"
- If user types repeatedly: gentle reminder "Try saying it out loud"
- If long silence: "Want a hint? Say 'hint'."
- Never shame or pressure.

## Accessibility
- Always allow typed input as alternative
- Closed captions for voice output (show text)

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/05-deployment/FIREBASE_WEB_INTEGRATION.md`
<!-- TELEMETRY_WIRING:END -->
