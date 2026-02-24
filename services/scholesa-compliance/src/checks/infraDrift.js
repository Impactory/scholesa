const fs = require('fs');
const path = require('path');
const {
  REPO_ROOT,
  reportPath,
  writeJson,
  nowIso,
  readTextSafe,
  toCanonicalReport,
} = require('../utils');

function contains(content, needle) {
  return Boolean(content && content.includes(needle));
}

function read(filePath) {
  return readTextSafe(filePath) || '';
}

function runInfraDrift() {
  const findings = [];

  const files = {
    referenceArchitecture: path.join(REPO_ROOT, 'docs/infrastructure/blueprints/hybrid-cloudrun-gke-gpu/00-architecture/01-reference-architecture.md'),
    serviceMap: path.join(REPO_ROOT, 'docs/infrastructure/blueprints/hybrid-cloudrun-gke-gpu/00-architecture/02-service-map.md'),
    namespace: path.join(REPO_ROOT, 'docs/k8s/00-namespace.yaml'),
    networkPolicy: path.join(REPO_ROOT, 'docs/k8s/01-networkpolicy-default-deny.yaml'),
    llmDeployment: path.join(REPO_ROOT, 'docs/k8s/10-llm-inference-deployment.yaml'),
    sttDeployment: path.join(REPO_ROOT, 'docs/k8s/20-stt-inference-deployment.yaml'),
    ttsDeployment: path.join(REPO_ROOT, 'docs/k8s/30-tts-inference-deployment.yaml'),
    llmService: path.join(REPO_ROOT, 'docs/k8s/11-llm-inference-service.yaml'),
    sttService: path.join(REPO_ROOT, 'docs/k8s/21-stt-inference-service.yaml'),
    ttsService: path.join(REPO_ROOT, 'docs/k8s/31-tts-inference-service.yaml'),
    ingressNotes: path.join(REPO_ROOT, 'docs/k8s/50-internal-ingress-notes.md'),
  };

  const checks = [
    {
      id: 'reference_architecture_private_inference_plane',
      pass:
        contains(read(files.referenceArchitecture), 'internal-only AI') &&
        contains(read(files.referenceArchitecture), 'No direct client access to inference plane.'),
      details: { path: files.referenceArchitecture },
    },
    {
      id: 'namespace_and_networkpolicy_present',
      pass:
        contains(read(files.namespace), 'name: scholesa-inference') &&
        contains(read(files.networkPolicy), 'kind: NetworkPolicy') &&
        contains(read(files.networkPolicy), 'default-deny-all'),
      details: { namespace: files.namespace, networkPolicy: files.networkPolicy },
    },
    {
      id: 'gpu_node_pool_markers_present',
      pass:
        contains(read(files.llmDeployment), 'nvidia.com/gpu') &&
        contains(read(files.sttDeployment), 'nvidia.com/gpu') &&
        contains(read(files.ttsDeployment), 'nvidia.com/gpu'),
      details: {
        llmDeployment: files.llmDeployment,
        sttDeployment: files.sttDeployment,
        ttsDeployment: files.ttsDeployment,
      },
    },
    {
      id: 'inference_services_clusterip_only',
      pass:
        contains(read(files.llmService), 'type: ClusterIP') &&
        contains(read(files.sttService), 'type: ClusterIP') &&
        contains(read(files.ttsService), 'type: ClusterIP') &&
        !contains(read(files.llmService), 'type: LoadBalancer') &&
        !contains(read(files.sttService), 'type: LoadBalancer') &&
        !contains(read(files.ttsService), 'type: LoadBalancer'),
      details: {
        llmService: files.llmService,
        sttService: files.sttService,
        ttsService: files.ttsService,
      },
    },
    {
      id: 'internal_lb_and_private_ingress_doc_markers',
      pass:
        contains(read(files.ingressNotes), 'Internal HTTP(S) Load Balancer') &&
        contains(read(files.ingressNotes), 'Do not expose inference plane publicly') &&
        contains(read(files.serviceMap), 'GKE inference workloads (GPU)'),
      details: { ingressNotes: files.ingressNotes, serviceMap: files.serviceMap },
    },
  ];

  for (const check of checks) {
    if (!check.pass) findings.push(`failed_check:${check.id}`);
  }

  const k8sDir = path.join(REPO_ROOT, 'docs/k8s');
  const loadBalancerFiles = [];
  if (fs.existsSync(k8sDir)) {
    const entries = fs.readdirSync(k8sDir);
    for (const entry of entries) {
      if (!entry.endsWith('.yaml') && !entry.endsWith('.yml')) continue;
      const full = path.join(k8sDir, entry);
      const content = read(full);
      if (content.includes('type: LoadBalancer')) {
        loadBalancerFiles.push(path.relative(REPO_ROOT, full));
      }
    }
  }

  const noPublicLoadBalancerCheck = {
    id: 'no_public_loadbalancer_services',
    pass: loadBalancerFiles.length === 0,
    details: { loadBalancerFiles },
  };
  checks.push(noPublicLoadBalancerCheck);
  if (!noPublicLoadBalancerCheck.pass) {
    findings.push(`failed_check:${noPublicLoadBalancerCheck.id}`);
  }

  const passed = findings.length === 0;
  const legacyReport = {
    report: 'infra-drift',
    generatedAt: nowIso(),
    passed,
    findings,
    checks,
  };

  const report = toCanonicalReport({
    reportName: 'infra-drift',
    passed,
    generatedAt: legacyReport.generatedAt,
    checks: checks.map((check) => ({ id: check.id, pass: check.pass, details: check.details })),
    legacy: legacyReport,
  });

  const outputPath = reportPath('infra-drift');
  writeJson(outputPath, report);

  return {
    checkId: 'infra_drift',
    passed,
    findings,
    evidencePath: outputPath,
    details: { checks: checks.length },
  };
}

module.exports = {
  runInfraDrift,
};
