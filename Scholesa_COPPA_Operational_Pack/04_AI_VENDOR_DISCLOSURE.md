# AI Vendor Disclosure (Operational)

Date: 2026-02-23

Scholesa may use third-party AI providers for educational assistance features.

## Data Shared With AI Providers
- Minimal task context needed for instructional response.
- Redacted learner input where applicable.
- Grade-band and policy metadata to enforce safety constraints.

## Data Explicitly Prohibited
- Credentials, secrets, payment data.
- Cross-tenant data.
- Unnecessary direct identifiers.

## Technical Safeguards
- Redaction path: `src/lib/ai/redactionService.ts`
- Request logging boundaries: `src/lib/ai/interactionLogger.ts`
- Grade-band enforcement on AI gateway: `functions/src/index.ts` (`genAiCoach`)

## Vendor Contract Requirements
- DPA in place.
- Clear retention terms.
- Documented training usage status.
- No advertising use of student data.

## Parent-Facing Position
- AI is used only to support education features.
- Data handling details are surfaced via school privacy notice and district process.
