#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---render-only}"
NAMESPACE="${K8S_NAMESPACE:-scholesa}"
WEB_DEPLOYMENT="${K8S_WEB_DEPLOYMENT:-scholesa-web}"
FLUTTER_DEPLOYMENT="${K8S_FLUTTER_DEPLOYMENT:-scholesa-flutter-web}"
COMPLIANCE_DEPLOYMENT="${K8S_COMPLIANCE_DEPLOYMENT:-scholesa-compliance}"

fail() {
  echo "Kubernetes platform health check failed: $*" >&2
  exit 1
}

log() {
  echo "[k8s] $*"
}

command -v kubectl >/dev/null 2>&1 || fail "kubectl not found on PATH"

render_manifests() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  kubectl kustomize k8s/web > "$tmpdir/web.yaml"
  kubectl kustomize k8s/platform > "$tmpdir/platform.yaml"

  [[ -s "$tmpdir/web.yaml" ]] || fail "k8s/web rendered an empty manifest"
  [[ -s "$tmpdir/platform.yaml" ]] || fail "k8s/platform rendered an empty manifest"

  grep -q 'kind: Deployment' "$tmpdir/platform.yaml" || fail "platform manifest is missing Deployments"
  grep -q "name: $WEB_DEPLOYMENT" "$tmpdir/platform.yaml" || fail "platform manifest is missing $WEB_DEPLOYMENT"
  grep -q "name: $FLUTTER_DEPLOYMENT" "$tmpdir/platform.yaml" || fail "platform manifest is missing $FLUTTER_DEPLOYMENT"
  grep -q "name: $COMPLIANCE_DEPLOYMENT" "$tmpdir/platform.yaml" || fail "platform manifest is missing $COMPLIANCE_DEPLOYMENT"
  grep -q 'kind: HorizontalPodAutoscaler' "$tmpdir/platform.yaml" || fail "platform manifest is missing HPA resources"
  grep -q 'kind: PodDisruptionBudget' "$tmpdir/platform.yaml" || fail "platform manifest is missing PDB resources"
  grep -q 'kind: NetworkPolicy' "$tmpdir/platform.yaml" || fail "platform manifest is missing NetworkPolicy resources"

  log "Kubernetes manifests rendered and structural checks passed."
}

require_gcloud_auth() {
  command -v gcloud >/dev/null 2>&1 || fail "gcloud not found on PATH"
  gcloud auth print-access-token --quiet >/dev/null 2>&1 || fail "gcloud auth cannot mint an access token. Run: gcloud auth login"
}

check_live_cluster() {
  require_gcloud_auth

  kubectl cluster-info >/dev/null
  kubectl get namespace "$NAMESPACE" >/dev/null
  kubectl get nodes --no-headers | awk '$2 != "Ready" { print; bad=1 } END { exit bad ? 1 : 0 }' \
    || fail "one or more Kubernetes nodes are not Ready"

  kubectl rollout status deployment/"$WEB_DEPLOYMENT" --namespace "$NAMESPACE" --timeout=180s
  kubectl rollout status deployment/"$FLUTTER_DEPLOYMENT" --namespace "$NAMESPACE" --timeout=180s
  kubectl rollout status deployment/"$COMPLIANCE_DEPLOYMENT" --namespace "$NAMESPACE" --timeout=180s

  kubectl get hpa --namespace "$NAMESPACE" >/dev/null
  kubectl get pdb --namespace "$NAMESPACE" >/dev/null
  kubectl get networkpolicy --namespace "$NAMESPACE" >/dev/null

  kubectl get pods --namespace "$NAMESPACE" --no-headers | awk '$3 != "Running" && $3 != "Completed" { print; bad=1 } END { exit bad ? 1 : 0 }' \
    || fail "one or more Scholesa pods are not Running or Completed"

  log "Live Kubernetes cluster health checks passed for namespace $NAMESPACE."
}

case "$MODE" in
  --render-only|render)
    render_manifests
    ;;
  --live|live)
    render_manifests
    check_live_cluster
    ;;
  *)
    fail "unknown mode '$MODE'. Use --render-only or --live."
    ;;
esac
