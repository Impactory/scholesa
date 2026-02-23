# Cloud Run Baseline Standards

For every service:
- Dedicated service account (no default compute SA)
- Ingress: internal+LB OR justified public
- Authentication: verified tokens at edge
- Concurrency: explicitly set
- Min instances: set for prod low-latency (if budget allows)
- CPU allocation: explicit
- Timeouts: explicit
- Egress: controlled if required
- Revision pinning: container digest pinned in release evidence
