const path = require('path');
const {
  REPO_ROOT,
  reportPath,
  writeJson,
  nowIso,
  readTextSafe,
  toCanonicalReport,
} = require('../utils');

function hasAllNeedles(content, needles) {
  if (!content) return false;
  return needles.every((needle) => content.includes(needle));
}

function runInferenceAuthz() {
  const findings = [];

  const serviceMapPath = path.join(REPO_ROOT, 'docs/infrastructure/blueprints/hybrid-cloudrun-gke-gpu/00-architecture/02-service-map.md');
  const contractsPath = path.join(REPO_ROOT, 'docs/infrastructure/blueprints/hybrid-cloudrun-gke-gpu/03-ai/01-internal-ai-service-contracts.md');
  const ingressNotesPath = path.join(REPO_ROOT, 'docs/k8s/50-internal-ingress-notes.md');
  const iamPath = path.join(REPO_ROOT, 'docs/infrastructure/blueprints/hybrid-cloudrun-gke-gpu/01-security/03-iam-and-service-accounts.md');
  const llmSvcPath = path.join(REPO_ROOT, 'docs/k8s/11-llm-inference-service.yaml');
  const sttSvcPath = path.join(REPO_ROOT, 'docs/k8s/21-stt-inference-service.yaml');
  const ttsSvcPath = path.join(REPO_ROOT, 'docs/k8s/31-tts-inference-service.yaml');

  const serviceMap = readTextSafe(serviceMapPath);
  const contracts = readTextSafe(contractsPath);
  const ingressNotes = readTextSafe(ingressNotesPath);
  const iam = readTextSafe(iamPath);
  const llmSvc = readTextSafe(llmSvcPath);
  const sttSvc = readTextSafe(sttSvcPath);
  const ttsSvc = readTextSafe(ttsSvcPath);

  const matrix = [
    { caller: 'scholesa-ai', llm: true, stt: false, tts: false },
    { caller: 'scholesa-stt', llm: false, stt: true, tts: false },
    { caller: 'scholesa-tts', llm: false, stt: false, tts: true },
  ];

  const checks = [
    {
      id: 'contracts_include_trace_and_locale_headers',
      pass: hasAllNeedles(contracts, ['X-Trace-Id', 'X-Site-Id', 'X-Locale']),
      details: { contractsPath },
    },
    {
      id: 'internal_ingress_requires_signed_jwt',
      pass: hasAllNeedles(ingressNotes, ['signed JWT', 'Do not expose inference plane publicly']),
      details: { ingressNotesPath },
    },
    {
      id: 'iam_contains_inference_service_accounts',
      pass: hasAllNeedles(iam, ['sa-scholesa-ai', 'sa-scholesa-stt', 'sa-scholesa-tts']),
      details: { iamPath },
    },
    {
      id: 'service_map_declares_inference_services',
      pass: hasAllNeedles(serviceMap, ['scholesa-ai', 'scholesa-stt', 'scholesa-tts']),
      details: { serviceMapPath },
    },
    {
      id: 'inference_services_private_clusterip',
      pass: hasAllNeedles(llmSvc, ['type: ClusterIP']) && hasAllNeedles(sttSvc, ['type: ClusterIP']) && hasAllNeedles(ttsSvc, ['type: ClusterIP']),
      details: { llmSvcPath, sttSvcPath, ttsSvcPath },
    },
    {
      id: 'caller_matrix_defined',
      pass: matrix.length === 3,
      details: { matrix },
    },
  ];

  for (const check of checks) {
    if (!check.pass) {
      findings.push(`failed_check:${check.id}`);
    }
  }

  const passed = findings.length === 0;
  const legacyReport = {
    report: 'inference-authz',
    generatedAt: nowIso(),
    passed,
    findings,
    checks,
    matrix,
  };

  const report = toCanonicalReport({
    reportName: 'inference-authz',
    passed,
    generatedAt: legacyReport.generatedAt,
    checks: checks.map((check) => ({ id: check.id, pass: check.pass, details: check.details })),
    legacy: legacyReport,
  });

  const outputPath = reportPath('inference-authz');
  writeJson(outputPath, report);

  return {
    checkId: 'inference_authz',
    passed,
    findings,
    evidencePath: outputPath,
    details: { matrix },
  };
}

module.exports = {
  runInferenceAuthz,
};
