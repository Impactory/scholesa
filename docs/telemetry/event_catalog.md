# Telemetry Event Catalog

This document provides a catalog of all telemetry events used in the Scholesa Learning OS. All events adhere to the canonical event envelope.

## Canonical Event Envelope

Every event is wrapped in a standard envelope that provides core, consistent context.
- `event_name`: The unique, snake_case name of the event.
- `event_version`: The semantic version of the event schema.
- `timestamp_ms`: The UTC timestamp in milliseconds when the event occurred.
- `session_id`: A UUID identifying the learner's session.
- `learner_id_hash`: A hashed identifier for the learner.
- `device_id_hash`: A hashed identifier for the device.
- `actor`: Who performed the action (`learner`, `teacher`, `system`).
- `context`: Situational context (grade, subject, mission).
- `privacy`: Consent and data classification information.
- `payload`: Event-specific data object.
- `metrics`: Event-specific numerical measurements.
- `trace`: Distributed tracing identifiers.

---

## Event Types

### Learning / BOS Signals

Events related to the learner's progress, interaction, and the BOS's response.

- **session_started**: Fired when a new learning session begins.
- **mission_started**: Fired when a learner starts a new mission.
- **mission_step_presented**: Fired when a new step or prompt is shown to the learner.
- **learner_response_captured**: Fired when the learner provides a response (voice, text, or other).
- **retrieval_check_presented**: Fired when a formative assessment (retrieval practice) is shown.
- **retrieval_check_scored**: Fired after a retrieval check is automatically scored.
- **hint_requested**: Fired when the learner asks for a hint.
- **hint_delivered**: Fired when the system provides a hint.
- **confusion_detected**: Fired when the system infers the learner is confused.
- **autonomy_choice_presented**: Fired when the learner is offered a choice (e.g., which topic to explore).
- **autonomy_choice_selected**: Fired when the learner makes an autonomy choice.
- **mastery_estimate_updated**: Fired when the system updates its model of the learner's mastery.
- **metacognitive_reflection_prompted**: Fired when the learner is prompted to reflect on their thinking.
- **metacognitive_reflection_submitted**: Fired when a learner submits a reflection.
- **portfolio_artifact_saved**: Fired when a piece of work is saved to the learner's portfolio.
- **version_history_checkpointed**: Fired when the system saves a version of the learner's work-in-progress.

### Voice Signals (STT/TTS)

Events related to the real-time voice interaction pipeline.

- **stt_stream_started**: Fired when the Speech-to-Text stream is opened.
- **stt_stream_partial**: Fired with an interim, non-final transcript.
- **stt_final_transcript**: Fired with the final, stable transcript.
- **stt_confidence_scored**: Fired with a confidence score for the final transcript.
- **tts_request_started**: Fired when a Text-to-Speech generation is requested.
- **tts_audio_first_byte**: Fired when the first byte of TTS audio is received and ready for playback.
- **tts_audio_completed**: Fired when the TTS audio playback finishes.
- **barge_in_detected**: Fired when the learner interrupts the TTS playback.
- **turn_taking_timeout**: Fired when the learner does not respond within the expected time.

### Safety / Policy Signals

Events related to the enforcement of safety, privacy, and content policies.

- **policy_check_started**: Fired when a policy check is initiated.
- **policy_check_blocked**: Fired when a policy check blocks an action.
- **hallucination_risk_scored**: Fired with a risk score for potential AI hallucination.
- **unsafe_content_detected**: Fired when potentially unsafe content is detected in learner or AI output.
- **pii_detected_redacted**: Fired when PII is detected and redacted from a transcript or text.
- **safe_mode_activated**: Fired when the system enters a fail-safe, restricted mode.

### System Quality Signals

Events related to the performance and reliability of the platform.

- **api_latency**: Fired to log the latency of an API call.
- **queue_lag**: Fired to log the time an event spent in a queue.
- **error_raised**: Fired when an unexpected error occurs.
- **retry_attempted**: Fired when a retry mechanism is triggered for a failed operation.
- **degraded_mode_enabled**: Fired when a system component enters a degraded-performance mode.
