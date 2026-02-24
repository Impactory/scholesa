# Voice Egress Proof Spec (No External Calls)

## Goal
Prove scholesa-stt and scholesa-tts never call external vendors.

## Methods (use at least one)
- Network policy + egress firewall and log-based verification
- Runtime interception (denylist domains) in integration tests
- VPC flow logs inspection (if using VPC)

## VIBE output JSON fields
- gitSha
- runId
- servicesChecked: [scholesa-stt, scholesa-tts]
- outboundRequestsDetected: 0
- notes

<!-- TELEMETRY_WIRING:START -->
## Telemetry & End-to-End Wiring
- Wired end-to-end: yes
- Canonical telemetry contract: `docs/infrastructure/telemetry/VIBE_TELEMETRY_AUDIT_MASTER.md`
- Canonical events/spec: `docs/18_ANALYTICS_TELEMETRY_SPEC.md`
- Validation gates: `npm run qa:vibe-telemetry:audit` and `npm run qa:vibe-telemetry:blockers`
- Doc scope: `Scholesa_TTS_Full_Deployment_MD_Pack/06-vibe/VOICE_EGRESS_PROOF_SPEC.md`
<!-- TELEMETRY_WIRING:END -->
