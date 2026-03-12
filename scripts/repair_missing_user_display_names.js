#!/usr/bin/env node

const { initializeFirebaseRestClients, resolveProjectId } = require('./firebase_runtime_auth');

const argv = process.argv.slice(2);
const apply = argv.includes('--apply');
const strict = argv.includes('--strict');
const projectArg = argv.find((arg) => arg.startsWith('--project='));
const projectId =
  resolveProjectId((projectArg && projectArg.split('=')[1]) || process.env.FIREBASE_PROJECT_ID) ||
  '';

const { db } = initializeFirebaseRestClients({ projectId });

function titleCaseRole(role) {
  switch ((role || '').trim()) {
    case 'hq':
      return 'HQ';
    case 'site':
      return 'Site';
    case 'educator':
      return 'Educator';
    case 'learner':
      return 'Learner';
    case 'parent':
      return 'Parent';
    case 'partner':
      return 'Partner';
    default:
      return 'User';
  }
}

function generatedDisplayName(uid, data) {
  const roleLabel = titleCaseRole(data.role);
  const email = typeof data.email === 'string' ? data.email.trim() : '';

  if (email === 'simon.luke@impactoryinstitute.com') {
    return 'Simon Luke (Master Admin)';
  }

  if (email.endsWith('@scholesa.dev')) {
    return `Test ${roleLabel} (${email})`;
  }

  if (email.endsWith('@example.com')) {
    return `${roleLabel} Example`;
  }

  if (email) {
    const handle = email.split('@')[0].replace(/[._-]+/g, ' ').trim();
    const humanized = handle
      .split(' ')
      .filter(Boolean)
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(' ');
    if (humanized) {
      return humanized;
    }
  }

  if (uid.startsWith('e2e-runner-')) {
    return `E2E ${roleLabel} ${uid.slice(-8)}`;
  }

  if (uid.startsWith('seed-live-')) {
    return `Seed ${roleLabel} ${uid.slice(-8)}`;
  }

  return `${roleLabel} ${uid.slice(0, 8)}`;
}

async function main() {
  const snap = await db.collection('users').get();
  const targets = [];

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (data.displayName) {
      continue;
    }

    targets.push({
      uid: doc.id,
      email: data.email || null,
      role: data.role || null,
      displayName: generatedDisplayName(doc.id, data),
    });
  }

  if (targets.length === 0) {
    console.log(`No missing display names found in ${projectId}.`);
    return;
  }

  if (!apply) {
    console.log(JSON.stringify({ projectId, count: targets.length, targets }, null, 2));
    if (strict) {
      process.exit(1);
    }
    return;
  }

  for (const target of targets) {
    await db.collection('users').doc(target.uid).set(
      {
        displayName: target.displayName,
        updatedAt: new Date(),
      },
      { merge: true },
    );
  }

  console.log(JSON.stringify({ projectId, repaired: targets.length, targets }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});