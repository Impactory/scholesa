# Internal Inference Gateway (Blueprint)
Generated: 2026-02-23T16:48:32Z

This folder provides **template configs** for an internal gateway that:
- is exposed only via **internal** load balancer/ingress
- validates Cloud Run **ID tokens (OIDC)**
- routes to ClusterIP inference services
- logs only trace metadata (no raw prompts/transcripts)

Choose one:
- NGINX Ingress + auth_request (OIDC sidecar) pattern
- Envoy + ext_authz OIDC validator
