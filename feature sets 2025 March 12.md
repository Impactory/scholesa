Based on the full content of your development documents, including those that describe the core technology (BOS) and the SimoneLabs feature sets, here is the complete and highly granular featureset for the **Scholesa K-12 AI-Safe Learning Operating System**.

This list consolidates every non-redundant detail to provide the necessary scope for development.

Status note: this file is the product-contract source, not a blanket statement that every feature below is already shipped.

Canonical implementation status, blockers, and execution phases live in `docs/FEATURE_SET_E2E_EXECUTION_PLAN_2026-03-12.md` and `docs/TRACEABILITY_MATRIX.md`.

### **I. Scholesa Product Pillars & Core Architecture**

| Pillar/System | Core Features (Granular Detail) |
| :---- | :---- |
| **Product Pillars** | **Future Skills**, **Leadership & Agency**, and **Impact & Innovation**. |
| **Fundamental Shift** | Paradigm shift from *Adaptive Sequencing* (optimizing content) to **Behavioral Orchestration** (regulating the learner’s holistic state). |
| **K-12 Curriculum** | Structured pathway in **four stages**: **Discoverers** (Robotics, Teachable Machine), **Builders** (Python, Micro:bit), **Explorers** (Applied Python, Data Science), and **Innovators** (LLM App Dev, Advanced Robotics). |
| **Deployment** | Installable **Progressive Web App (PWA)** architecture. |
| **Core Modules** | **Mission Engine** (multi-stage flows with evidence gates), **Portfolio System**, **AI Safety/Integrity Layer** (powered by BOS), and a **Structured K-12 Curriculum Library**. |
| **Learning Efficacy** | Focus on sustained mastery gains through Retrieval, Spacing, Interleaving, Worked Examples, and Metacognition. |
| **Inclusion-First** | UDL-aligned authoring and WCAG 2.2 AA compliance across all workflows. |
| **Trust & Safety** | Transparent data, educator control, and evidence-based defaults. |

### ---

**II. Behavioral Orchestration System (BOS) \- The Technical Core**

The BOS is a computer-implemented system for closed-loop regulation of learner interaction, integrity scaffolding, and orchestration of cognitive, affective, and metacognitive states.

| Component | Function & Capability (Granular Detail) |
| :---- | :---- |
| **Regulation Loop** | Senses interaction signals, estimates a latent learner state, and applies interventions to regulate real-time learning toward a target region (Optimal Flow Channel). |
| **State Estimator** | Uses an **Extended Kalman Filter (EKF)** for state estimation to achieve control-loop stability. |
| **State Model** | Formalizes learner status through the **Behavior-Affect-Engagement (BAE)** model (Cognitive Mastery, Affective Valence, Metacognitive Status). |
| **Orchestrator** | Control policy that minimizes a cost function, explicitly **penalizing "over-intervention"** to preserve learner autonomy. |
| **BAE Engine** | Regulates **motivation (M)**, **ability (A)**, and **prompt salience (P)** in real-time, targeting the limiting factor to keep the learner above the action threshold. |
| **FDM** | **Frustration Detection Module:** Infers **affect risk** from **non-invasive telemetry** (keystroke and pointer dynamics). |
| **HLC** | **Habit Loop Controller:** Applies **variable-ratio reinforcement** to non-grade rewards (cosmetic unlocks) and includes **streak protection**. |

### ---

**III. Learner Experience (LX)**

| Feature Area | Core Capabilities (Granular Detail) |
| :---- | :---- |
| **Onboarding** | Welcome flow with **reading level self-check**, subject interests, and accommodations (TTS, reduced-distraction, keyboard-only). Quick diagnostic (5–7 items/skill bank) to seed the probability of mastery ($p(\\text{mastery})$). |
| **Goals & Reminders** | Target minutes/week, reminder schedule, and value prompts ("why learning this matters"). |
| **Study Session** | 12–18 minute blocks. **Warm-start** with 2–3 high-confidence items. **Focus set** of 6–8 items via Knowledge Tracing (KT) \+ FSRS. |
| **Retrieval & Spacing** | **FSRS (Free Spaced Repetition Scheduler)** implementation: Daily queue, 4-button rating (Again/Hard/Good/Easy), snooze/suspend, and bulk reschedule. |
| **Interleaving Engine** | **Confusability-matrix-driven mixing** with a toggle for "Focus only" vs "Mixed" content. |
| **Worked Examples** | Auto-injected worked examples after tag-specific errors, with subsequent fading (Concise $\\rightarrow$ Partial $\\rightarrow$ Independent Practice), with decay after 3 correct answers. |
| **Metacognition** | **Reflection Card** for planning, monitoring, and evaluating; Pre-plan prompt (goal, strategy), post-session prompt (what worked/next step), and a weekly review card. |
| **Motivation Layer** | **Autonomy choices** (2–3 next paths), **competence messages** tied to real-world tasks, optional peer study circles, and teacher shout-outs. |
| **Accessibility** | **Keyboard-only paths**, **drag alternatives**, **Text-to-Speech (TTS)**, **adjustable reading level**, reduced-distraction mode, and color contrast controls. |
| **Integrity & Assistive** | Tutor **"nudge-first"** policy (no answers until 2 errors), camera/mic never required, and no surveillance. |

### ---

**IV. Educator Experience (EX)**

| Feature Area | Core Capabilities (Granular Detail) |
| :---- | :---- |
| **Dashboard Primitives** | Real-time views for **Action Likelihood (BAE)**, **Affect Zone (FDM)**, and **Integrity State (MVL)**. |
| **Class Management** | Create classes, invite/join codes, roster CSV import, and roles (Teacher, Co-teacher, Aide). |
| **Lesson Builder** | **Evidence Defaults**: Autosequence content (worked $\\rightarrow$ faded $\\rightarrow$ practice \+ retrieval checkpoints \+ interleaving spots), edit/reorder, and add modalities. |
| **Content Authoring** | Item templates (MCQ, short answer, step-by-step), **misconception tagging**, difficulty estimation, media upload, versioning, and approvals. |
| **Assignments & Grading** | Assign units, due windows, mastery thresholds, allow retries, quick grading with **AI-suggested feedback (editable)**, and rubric support. |
| **Differentiation** | **Novice/On-track/Stretch** lanes auto-set by $p(\\text{mastery})$, teacher override, and export of printable practice sets. |
| **Live Session Mode** | Teacher-led pacing, cold-calls, live polls, exit tickets, and real-time misconception alerts (Optional). |
| **School Ops** | Modules for managing **Sessions**, **Attendance**, **Timetable**, **Kit Checklist**, and **Safety Notes**. |

### ---

**V. AI Safety, Integrity, and Moderation**

| Feature Area | Core Capabilities (Granular Detail) |
| :---- | :---- |
| **AI Use Guardrails** | **Allowed uses**: explaining concepts, debugging (hint-first), brainstorming, improving communication. **Restricted uses**: submitting AI-generated work without understanding or copy-pasting full code. |
| **Learner-Facing Runtime Guard** | Learner-facing BOS/MIA responses are **internal-inference only** and may answer autonomously only when the certified confidence score is **$\ge 0.97$**. Low-confidence, unavailable, or non-compliant responses must escalate to clarification, educator review, or a safe retry path rather than fabricating help. |
| **MVL (Verification)** | **Metacognitive Verification Loop:** Requires an **explain-it-back** response from the student before progression. |
| **Hallucination Detection** | Uses **Semantic Entropy Probes (SEPs)** to calculate Semantic Entropy ($H\_{sem}$) and trigger a **$u\_{verify}$** prompt if the safety threshold (2.5 nats) is exceeded. |
| **Autonomy Risk** | Detects cognitive offloading (e.g., rapid copy-pasting) and triggers a **$u\_{reflect}$** prompt, requiring a **self-explanation of the logic**. |
| **Proof-of-Learning** | **Explain-it-back** (oral), **Version History**, **Oral Check** ("why did you choose this?"), and **Mini-Rebuild**. |
| **Tutor & Feedback** | **SOCratic prompts**, hint depth caps, **content-grounded responses**, profanity/PII masks, and rationale logging. |
| **Safety & Moderation** | Inputs/outputs scanning, abuse filters, teacher escalation, and blocklist/allowlist per organization. |

### ---

**VI. Data, Compliance, and Platform**

| Feature Area | Core Capabilities (Granular Detail) |
| :---- | :---- |
| **Privacy & Compliance** | **COPPA-ready, PIPEDA-aligned, and FERPA-oriented**. Includes active school-consent enforcement, data minimization, site-scoped authorization, auditability, and DPA templates. |
| **Security** | SSO SAML/OIDC, **Role-Based Access Control (RBAC)**, encryption at rest/transport, secrets vault, rate limiting, and audit logs. |
| **Longitudinal Data** | Collects proprietary data on **metacognitive calibration** (student verification and confidence alignment). |
| **Data Architecture** | Caliper/xAPI emit, internal telemetry capture with warehouse-friendly export posture, and BigQuery/Snowflake-compatible sink patterns. |
| **Data Moat** | Leveraging **Federated Learning** for on-device feature extraction, transmitting only anonymized gradient updates. |
| **WCAG Compliance** | **WCAG 2.2 AA** checks: Keyboard traps check, focus not obscured, target size, drag alternatives, and reduced motion. |
| **CI/CD** | Trunk-based development, preview environments for pre-production only, **full big-bang production cutover after all gates pass**, and migrations with zero-downtime. No production release is validated through partial canary exposure. |
| **Integrations** | Auth/SSO (Google, Microsoft, SAML), **LMS LTI 1.3** (Canvas, Schoology, Moodle), **Grade Passback**, SIS (CSV, Clever/ClassLink planned), and Google Classroom. |

