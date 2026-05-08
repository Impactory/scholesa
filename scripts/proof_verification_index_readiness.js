#!/usr/bin/env node

const { execFileSync } = require('child_process');

const projectId = process.env.GCP_PROJECT_ID ||
  process.env.FIREBASE_PROJECT_ID ||
  'studio-3328096157-e3f79';

const requiredIndexes = [
  {
    collection: 'portfolioItems',
    fields: ['siteId:ASCENDING', 'verificationStatus:ASCENDING', 'createdAt:DESCENDING'],
  },
  {
    collection: 'portfolioItems',
    fields: ['siteId:ASCENDING', 'createdAt:DESCENDING'],
  },
  {
    collection: 'proofOfLearningBundles',
    fields: ['siteId:ASCENDING', 'verificationStatus:ASCENDING', 'createdAt:DESCENDING'],
  },
  {
    collection: 'proofOfLearningBundles',
    fields: ['verificationStatus:ASCENDING', 'createdAt:DESCENDING'],
  },
  {
    collection: 'proofOfLearningBundles',
    fields: ['learnerId:ASCENDING', 'createdAt:DESCENDING'],
  },
  {
    collection: 'proofOfLearningBundles',
    fields: ['learnerId:ASCENDING', 'updatedAt:DESCENDING'],
  },
];

function collectionGroup(index) {
  if (index.collectionGroup) return index.collectionGroup;
  const match = String(index.name || '').match(/collectionGroups\/([^/]+)/);
  return match ? match[1] : '';
}

function indexFields(index) {
  return (index.fields || [])
    .filter((field) => field.fieldPath !== '__name__')
    .map((field) => `${field.fieldPath}:${field.order || field.arrayConfig}`);
}

function fetchIndexes() {
  try {
    return execFileSync(
      'gcloud',
      [
        'firestore',
        'indexes',
        'composite',
        'list',
        '--project',
        projectId,
        '--format=json',
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
  } catch (error) {
    const stderr = error && typeof error === 'object' && 'stderr' in error ? error.stderr : '';
    console.error('Proof/verification index readiness check failed to list indexes.');
    if (stderr) console.error(String(stderr).trim());
    process.exit(1);
  }
}

const indexes = JSON.parse(fetchIndexes());
const ready = [];
const missing = [];

for (const requiredIndex of requiredIndexes) {
  const found = indexes.find((index) => {
    if (collectionGroup(index) !== requiredIndex.collection) return false;
    if (index.state !== 'READY') return false;
    const fields = indexFields(index);
    return requiredIndex.fields.every((field, position) => fields[position] === field);
  });

  const label = `${requiredIndex.collection}(${requiredIndex.fields.join(', ')})`;
  if (found) ready.push(label);
  else missing.push(label);
}

console.log(`PROJECT=${projectId}`);
console.log(`READY=${ready.length}`);
for (const item of ready) console.log(`READY ${item}`);
console.log(`MISSING=${missing.length}`);
for (const item of missing) console.log(`MISSING ${item}`);

if (missing.length > 0) {
  process.exit(1);
}