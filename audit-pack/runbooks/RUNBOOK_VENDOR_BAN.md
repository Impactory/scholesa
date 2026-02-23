# RUNBOOK_VENDOR_BAN

Purpose: Remediate any external GenAI usage (Gemini/Vertex/other non-internal providers).

1. Run `npm run ai:internal-only:all` and review failed report(s) in `audit-pack/reports`.
2. Remove banned dependencies/imports/domains from runtime code.
3. Confirm egress guard files block denied hosts and emit `SECURITY_EGRESS_BLOCKED`.
4. Remove/rotate any banned secrets (`GEMINI_API_KEY` patterns) from secret stores and env files.
5. Re-run compliance operator (`npm run compliance:run`) and attach new evidence.
