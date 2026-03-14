# REQ-036 Cloud Run API Build/Health Proof

Date: 2026-03-14

Requirement: REQ-036 Cloud Run API build/health

Files added or updated:
- `Dockerfile`
- `app/api/healthz/route.ts`
- `src/__tests__/healthz.test.ts`

Local proof:
- `docker build -t scholesa-api-proof:local .`
- `docker run --rm -p 8081:8080 scholesa-api-proof:local`
- `curl -sSf http://127.0.0.1:8081/api/healthz`

Observed result:
- Container image built successfully on the repo Dockerfile after aligning the image baseline to Node 24.
- Containerized runtime started successfully and served `GET /api/healthz`.
- Health response returned `{"ok":true,"version":"0.1.0","buildTag":"dev","services":{"auth":"unconfigured","firestore":"unconfigured"}}`, which is the expected deterministic readiness shape when Firebase Admin credentials are absent.

Status:
- REQ-036 can be marked complete.