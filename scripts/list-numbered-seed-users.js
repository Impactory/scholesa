#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const credentialCandidates = [
  process.env.GOOGLE_APPLICATION_CREDENTIALS,
  path.resolve(process.cwd(), 'firebase-service-account.json'),
  path.resolve(process.cwd(), 'studio-service-account.json'),
]
  .filter((entry) => typeof entry === 'string' && entry.trim().length > 0)
  .map((entry) => path.resolve(process.cwd(), entry));

function resolveCredentialPath() {
  for (const candidate of credentialCandidates) {
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

function isNumberedAccount(value) {
  if (typeof value !== 'string') return false;
  const normalized = value.trim().toLowerCase();
  return /(parent|guardian|student|learner)[-_]?\d{3}/.test(normalized);
}

async function main() {
  const credentialPath = resolveCredentialPath();
  if (!credentialPath) {
    throw new Error('No service account json found.');
  }
  const serviceAccount = JSON.parse(fs.readFileSync(credentialPath, 'utf8'));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });

  const db = admin.firestore();
  const auth = admin.auth();
  const usersSnap = await db.collection('users').get();
  const authList = await auth.listUsers(1000);
  const authEmailSet = new Set(
    authList.users
      .map((entry) => (typeof entry.email === 'string' ? entry.email.toLowerCase() : null))
      .filter((entry) => typeof entry === 'string'),
  );
  const authUidSet = new Set(authList.users.map((entry) => entry.uid));

  const matches = [];
  for (const doc of usersSnap.docs) {
    const data = doc.data() || {};
    const uid = typeof data.uid === 'string' ? data.uid : doc.id;
    const email = typeof data.email === 'string' ? data.email : '';
    const displayName = typeof data.displayName === 'string' ? data.displayName : '';
    const role = typeof data.role === 'string' ? data.role : '';
    if (!isNumberedAccount(uid) && !isNumberedAccount(email) && !isNumberedAccount(displayName)) {
      continue;
    }
    matches.push({
      uid,
      email,
      displayName,
      role,
      authAccountExists:
        authUidSet.has(uid) ||
        (typeof email === 'string' && email.trim().length > 0
          ? authEmailSet.has(email.toLowerCase())
          : false),
      activeSiteId: typeof data.activeSiteId === 'string' ? data.activeSiteId : null,
      siteIds: Array.isArray(data.siteIds)
        ? data.siteIds.filter((entry) => typeof entry === 'string')
        : [],
    });
  }

  matches.sort((a, b) => String(a.email || a.uid).localeCompare(String(b.email || b.uid)));

  process.stdout.write(
    JSON.stringify(
      {
        projectId: serviceAccount.project_id,
        credentialPath: path.relative(process.cwd(), credentialPath),
        totalUsers: usersSnap.size,
        totalAuthUsersScanned: authList.users.length,
        numberedMatches: matches.length,
        numberedMatchesWithAuth: matches.filter((entry) => entry.authAccountExists).length,
        numberedMatchesWithoutAuth: matches.filter((entry) => !entry.authAccountExists).length,
        users: matches,
      },
      null,
      2,
    ) + '\n',
  );
}

main().catch((error) => {
  process.stderr.write(
    JSON.stringify(
      {
        error: error instanceof Error ? error.message : String(error),
      },
      null,
      2,
    ) + '\n',
  );
  process.exit(1);
});
