#!/usr/bin/env node

const { execFileSync } = require('child_process');

const projectId = process.env.GCP_PROJECT_ID || 'studio-3328096157-e3f79';
const region = process.env.GCP_REGION || 'us-central1';
const rehearsalTag = process.env.CLOUD_RUN_REHEARSAL_TAG || 'gold-rehearsal';
const services = [
  process.env.CLOUD_RUN_SERVICE || 'scholesa-web',
  process.env.CLOUD_RUN_FLUTTER_SERVICE || 'empire-web',
  process.env.COMPLIANCE_RUN_SERVICE || 'scholesa-compliance',
];

function fail(message) {
  console.error(`Cloud Run rehearsal URL lookup failed: ${message}`);
  process.exit(1);
}

function describeService(service) {
  try {
    const output = execFileSync(
      'gcloud',
      [
        'run',
        'services',
        'describe',
        service,
        '--project',
        projectId,
        '--region',
        region,
        '--format=json(metadata.name,status.url,status.traffic,status.latestCreatedRevisionName,status.latestReadyRevisionName)',
      ],
      {
        encoding: 'utf8',
        env: {
          ...process.env,
          CLOUDSDK_CORE_DISABLE_PROMPTS: '1',
        },
        stdio: ['ignore', 'pipe', 'pipe'],
      }
    );
    return JSON.parse(output);
  } catch (error) {
    const stderr = error && typeof error === 'object' && 'stderr' in error ? error.stderr : '';
    if (stderr) console.error(String(stderr).trim());
    fail(`unable to describe ${service}`);
  }
}

console.log(`PROJECT=${projectId}`);
console.log(`REGION=${region}`);
console.log(`TAG=${rehearsalTag}`);

for (const service of services) {
  const state = describeService(service);
  const traffic = state.status?.traffic || [];
  const rehearsal = traffic.find((entry) => entry.tag === rehearsalTag);
  const serving = traffic.filter((entry) => entry.percent === 100);

  if (!rehearsal?.url) {
    fail(`${service} does not expose tag '${rehearsalTag}' with a URL`);
  }

  console.log(`SERVICE=${service}`);
  console.log(`LATEST_CREATED=${state.status?.latestCreatedRevisionName || ''}`);
  console.log(`LATEST_READY=${state.status?.latestReadyRevisionName || ''}`);
  console.log(`REHEARSAL_REVISION=${rehearsal.revisionName || ''}`);
  console.log(`REHEARSAL_URL=${rehearsal.url}`);
  console.log(`SERVING_100=${serving.map((entry) => entry.revisionName).join(',')}`);
}