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
