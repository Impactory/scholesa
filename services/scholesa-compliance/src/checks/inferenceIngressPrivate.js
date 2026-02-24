const path = require('path');
const { REPO_ROOT, reportPath, writeJson, nowIso, readTextSafe } = require('../utils');

function contains(content, needle) {
  return Boolean(content && content.includes(needle));
}

function runInferenceIngressPrivate() {
  const findings = [];

  const ingressNotesPath = path.join(REPO_ROOT, 'docs/k8s/50-internal-ingress-notes.md');
  const k8sReadmePath = path.join(REPO_ROOT, 'docs/k8s/README.md');
  const npPath = path.join(REPO_ROOT, 'docs/k8s/01-networkpolicy-default-deny.yaml');
  const llmSvcPath = path.join(REPO_ROOT, 'docs/k8s/11-llm-inference-service.yaml');
  const sttSvcPath = path.join(REPO_ROOT, 'docs/k8s/21-stt-inference-service.yaml');
  const ttsSvcPath = path.join(REPO_ROOT, 'docs/k8s/31-tts-inference-service.yaml');

  const ingressNotes = readTextSafe(ingressNotesPath);
  const k8sReadme = readTextSafe(k8sReadmePath);
  const np = readTextSafe(npPath);
  const llmSvc = readTextSafe(llmSvcPath);
  const sttSvc = readTextSafe(sttSvcPath);
  const ttsSvc = readTextSafe(ttsSvcPath);

  const checks = [
    {
      id: 'ingress_notes_internal_lb_only',
      pass:
        contains(ingressNotes, 'Internal HTTP(S) Load Balancer') &&
        contains(ingressNotes, 'Do not expose inference plane publicly'),
      details: { ingressNotesPath },
    },
    {
      id: 'k8s_readme_internal_ingress_only',
      pass: contains(k8sReadme, 'Internal Ingress / Internal Load Balancer only'),
      details: { k8sReadmePath },
    },
    {
      id: 'networkpolicy_default_deny_present',
      pass: contains(np, 'kind: NetworkPolicy') && contains(np, 'default-deny-all'),
      details: { npPath },
    },
    {
      id: 'inference_services_clusterip_only',
      pass:
        contains(llmSvc, 'type: ClusterIP') &&
        contains(sttSvc, 'type: ClusterIP') &&
        contains(ttsSvc, 'type: ClusterIP') &&
        !contains(llmSvc, 'type: LoadBalancer') &&
        !contains(sttSvc, 'type: LoadBalancer') &&
        !contains(ttsSvc, 'type: LoadBalancer'),
      details: { llmSvcPath, sttSvcPath, ttsSvcPath },
    },
  ];

  for (const check of checks) {
    if (!check.pass) findings.push(`failed_check:${check.id}`);
  }

  const passed = findings.length === 0;
  const report = {
    report: 'inference-ingress-private',
    generatedAt: nowIso(),
    passed,
    findings,
    checks,
  };

  const outputPath = reportPath('inference-ingress-private');
  writeJson(outputPath, report);

  return {
    checkId: 'inference_ingress_private',
    passed,
    findings,
    evidencePath: outputPath,
    details: { checks: checks.length },
  };
}

module.exports = {
  runInferenceIngressPrivate,
};
