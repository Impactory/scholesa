# Scholesa Platform Kubernetes Manifests

This layer makes the platform horizontally deployable by service domain while keeping tenant data isolation in Firebase/Firestore rules and application authorization. It composes the primary web manifests from `k8s/web` and adds independently scalable Flutter web and compliance domains.

Deployable service domains:

| Domain | Image | Public surface | Scaling |
| --- | --- | --- | --- |
| Primary web | `scholesa-web` from `Dockerfile` | `LoadBalancer` on port 80 | HPA min 3, max 10, CPU 70% |
| Flutter web | `scholesa-flutter-web` from `Dockerfile.flutter` | `LoadBalancer` on port 80 | HPA min 3, max 10, CPU 70% |
| Compliance operator | `scholesa-compliance` from `Dockerfile.compliance` | `ClusterIP` only | HPA min 3, max 8, CPU 70% |

Reliability controls:

- Three replicas per deployable service domain.
- Rolling updates use `maxUnavailable: 0`.
- PodDisruptionBudgets keep at least two replicas available per domain.
- CPU and memory requests/limits are set for autoscaling and scheduling.
- Readiness and liveness probes use real service endpoints.
- Topology spread constraints avoid concentrating all replicas on one node when capacity allows.
- NetworkPolicy defaults to deny ingress, then opens public web domains and keeps compliance internal to namespace pods.

Tenant isolation model:

- Runtime tenant boundaries remain enforced by Firebase Auth claims, Firestore rules, route metadata, and application code.
- Kubernetes isolates service domains and network ingress, but it does not replace site-scoped reads/writes.
- Do not create per-tenant static manifests with committed secrets or service-account JSON. Use workload identity or out-of-band secret creation.

Build images:

```bash
docker build -t scholesa-web:latest .
docker build -f Dockerfile.flutter -t scholesa-flutter-web:latest .
docker build -f Dockerfile.compliance -t scholesa-compliance:latest .
```

For the primary web image, pass the required public Firebase build args listed in `k8s/web/README.md`. Do not commit those values.

Create runtime config and secrets out of band:

```bash
kubectl apply -f k8s/web/namespace.yaml
kubectl create configmap scholesa-web-public-config --namespace scholesa \
  --from-literal=NEXT_PUBLIC_FIREBASE_API_KEY="$NEXT_PUBLIC_FIREBASE_API_KEY" \
  --from-literal=NEXT_PUBLIC_FIREBASE_PROJECT_ID="$NEXT_PUBLIC_FIREBASE_PROJECT_ID" \
  --from-literal=NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN="$NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN" \
  --from-literal=NEXT_PUBLIC_FIREBASE_APP_ID="$NEXT_PUBLIC_FIREBASE_APP_ID" \
  --from-literal=NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET="$NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET" \
  --from-literal=NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID="$NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID" \
  --from-literal=NEXT_PUBLIC_ENABLE_SW="${NEXT_PUBLIC_ENABLE_SW:-false}"
```

Deploy the platform layer:

```bash
kubectl apply -k k8s/platform
```

Patch registry images without editing committed manifests:

```bash
kubectl set image deployment/scholesa-web web="$WEB_IMAGE" --namespace scholesa
kubectl set image deployment/scholesa-flutter-web flutter-web="$FLUTTER_WEB_IMAGE" --namespace scholesa
kubectl set image deployment/scholesa-compliance compliance="$COMPLIANCE_IMAGE" --namespace scholesa
```

Operational checks:

```bash
kubectl rollout status deployment/scholesa-web --namespace scholesa
kubectl rollout status deployment/scholesa-flutter-web --namespace scholesa
kubectl rollout status deployment/scholesa-compliance --namespace scholesa
kubectl get hpa --namespace scholesa
kubectl get pdb --namespace scholesa
```

Evidence-heavy classroom workload notes:

- Web and Flutter web can scale independently for classroom login, navigation, evidence capture, and learner/guardian viewing spikes.
- Compliance remains internal and separately scalable so release/compliance scans cannot starve classroom-facing pods.
- Firestore and Firebase remain the evidence persistence tier; verify Firestore indexes and rules before any classroom-heavy cutover.
- For internal LLM/STT/TTS inference, use the dedicated `docs/k8s` inference plane blueprints only after real internal images and model artifact stores are available.
