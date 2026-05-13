# Scholesa Web Kubernetes Manifests

These manifests deploy the existing Node.js/Next.js web container defined by the root `Dockerfile`.

Included resources:
- `Deployment` with 3 replicas and rolling updates
- `Service` of type `LoadBalancer`
- CPU-based `HorizontalPodAutoscaler` with 3 minimum replicas and 10 maximum replicas
- `PodDisruptionBudget` that keeps at least 2 replicas available during voluntary disruptions
- `ServiceAccount` and namespace

Build and tag the image before deploying:

```bash
docker build \
  --build-arg NEXT_PUBLIC_FIREBASE_API_KEY="$NEXT_PUBLIC_FIREBASE_API_KEY" \
  --build-arg NEXT_PUBLIC_FIREBASE_PROJECT_ID="$NEXT_PUBLIC_FIREBASE_PROJECT_ID" \
  --build-arg NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN="$NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN" \
  --build-arg NEXT_PUBLIC_FIREBASE_APP_ID="$NEXT_PUBLIC_FIREBASE_APP_ID" \
  --build-arg NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET="$NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET" \
  --build-arg NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID="$NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID" \
  --build-arg NEXT_PUBLIC_ENABLE_SW="${NEXT_PUBLIC_ENABLE_SW:-false}" \
  -t scholesa-web:latest .
```

Create the namespace, then create runtime config from local environment values without committing them:

```bash
kubectl apply -f k8s/web/namespace.yaml
```

```bash
kubectl create configmap scholesa-web-public-config \
  --namespace scholesa \
  --from-literal=NEXT_PUBLIC_FIREBASE_API_KEY="$NEXT_PUBLIC_FIREBASE_API_KEY" \
  --from-literal=NEXT_PUBLIC_FIREBASE_PROJECT_ID="$NEXT_PUBLIC_FIREBASE_PROJECT_ID" \
  --from-literal=NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN="$NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN" \
  --from-literal=NEXT_PUBLIC_FIREBASE_APP_ID="$NEXT_PUBLIC_FIREBASE_APP_ID" \
  --from-literal=NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET="$NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET" \
  --from-literal=NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID="$NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID" \
  --from-literal=NEXT_PUBLIC_ENABLE_SW="${NEXT_PUBLIC_ENABLE_SW:-false}"
```

If the cluster does not use workload identity, create the server secret out of band:

```bash
kubectl create secret generic scholesa-web-server-secrets \
  --namespace scholesa \
  --from-literal=FIREBASE_SERVICE_ACCOUNT="$FIREBASE_SERVICE_ACCOUNT"
```

Deploy with kustomize:

```bash
kubectl apply -k k8s/web
```

For registry deployments, patch the image without editing committed manifests:

```bash
kubectl set image deployment/scholesa-web web="$IMAGE" --namespace scholesa
```

Do not commit generated logs, local env files, kubeconfigs, service-account JSON, or temporary deployment output. The repo ignores common local temp and Playwright output paths.
