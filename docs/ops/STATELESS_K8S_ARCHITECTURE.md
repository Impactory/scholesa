# Stateless Kubernetes Architecture

Scholesa deploys as horizontally scalable, stateless service domains. The Kubernetes boundary is responsible for replica management, rolling updates, network isolation, probes, and service-domain scaling. Tenant isolation and evidence integrity remain enforced by Firebase Auth, Firestore rules, Cloud Functions callables, and site-scoped application queries.

## Service Domains

| Domain | Runtime | State ownership | Scaling boundary |
| --- | --- | --- | --- |
| Primary web | Next.js Node container | No local durable state; Firebase/Firestore/Storage only | `scholesa-web` Deployment + HPA |
| Flutter web | Nginx static WASM container | No local durable state | `scholesa-flutter-web` Deployment + HPA |
| Compliance operator | Node compliance service | Reads repo/runtime checks; writes reports through approved audit paths | `scholesa-compliance` Deployment + HPA |
| Firebase Functions | Managed Gen 2 functions | Firestore/Storage/Admin SDK | Firebase-managed scaling |
| Internal inference | Future internal-only model services | Model artifact store only; no student-data source of truth | `docs/k8s` blueprints until real images exist |

## Statelessness Rules

- Pods may keep request-local memory only.
- Pods must not write evidence, learner state, tenant configuration, reports, voice traces, or audit data to local disk as durable state.
- Any local cache must be disposable and rebuildable from Firebase/Firestore, Cloud Storage, or approved managed services.
- Background processing must be idempotent. A retry must update the same site-scoped evidence chain record rather than duplicating learner claims.
- Do not use shared persistent volumes for tenant data unless a future design explicitly models tenancy, encryption, retention, and provenance.

## Tenant-Safe Persistence

- Every tenant-scoped query/write must carry `siteId` where the model supports site scope.
- Role access must remain enforced at four layers: Firebase Auth claims/profile, Firestore rules, route metadata, and client role gates.
- K8s namespaces and labels isolate service domains; they do not replace application tenant authorization.
- Evidence outputs must retain provenance from capture through proof, rubric, growth, portfolio, and Passport/report surfaces.

## Evidence-Heavy Classroom Workloads

- Classroom spikes are expected around session starts, live evidence capture, artifact submission, proof review, and guardian viewing windows.
- Web and Flutter web scale independently so classroom UI traffic does not contend with compliance scans.
- Compliance remains internal and separately scalable so operator checks cannot starve learner/educator traffic.
- Firestore indexes and security rules are release gates before classroom-heavy cutovers.
- In-pod queues are not allowed. Use Firestore, Cloud Tasks, Pub/Sub, or Firebase-managed scheduled/callable functions when a workflow needs asynchronous evidence processing.

## Kubernetes Operational Boundary

The deployable platform manifests live in `k8s/platform`:

- 3 replicas per deployable service domain.
- CPU HPAs for each service domain.
- PodDisruptionBudgets keep at least two replicas available.
- Rolling updates use zero unavailable pods.
- Topology spread constraints reduce node concentration risk.
- NetworkPolicies deny ingress and egress by default, then allow only explicit service paths.
- Namespace pod-security labels enforce the restricted profile.

## Release Gates

Before any live promotion:

1. Render manifests with `kubectl kustomize k8s/platform`.
2. Run `git diff --check`.
3. Run `npm run typecheck`, `npm run lint`, `npm test -- --runInBand`.
4. Run `npm run compliance:gate`, `npm run ai:internal-only:all`, and `npm run qa:workflow:no-mock`.
5. Run Firebase rules and evidence-chain emulator suites.
6. Build and smoke all changed images.
7. Run `bash ./scripts/cloud_run_release_state_probe.sh` or the equivalent cluster release-state probe for the chosen runtime.

Do not claim blanket Gold if the deployed candidate has not been proven against the evidence chain with real or canonical synthetic data.
