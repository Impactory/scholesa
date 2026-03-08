#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

const argv = process.argv.slice(2);
const strict = argv.includes('--strict');
const json = argv.includes('--json');
const apiKeyArg = argv.find((arg) => arg.startsWith('--api-key='));
const firebaseOptionsPath = path.resolve(
  __dirname,
  '../apps/empire_flutter/app/lib/firebase_options.dart',
);

const apiKey =
  (apiKeyArg && apiKeyArg.split('=')[1]) ||
  process.env.FIREBASE_WEB_API_KEY ||
  extractWebApiKey();

const password =
  process.env.TEST_USER_PASSWORD ||
  process.env.SEED_TEST_PASSWORD ||
  process.env.TEST_LOGIN_PASSWORD ||
  'Test123!';

const LOGIN_PROFILES = [
  { email: 'amelda@scholesa.com', expectedUid: 'WXmnwwgFlpfQNeQ8ixVq' },
  { email: 'ameldalin561@gmail.com', expectedUid: 'i7dq6t07N8MTR22eTVbg' },
  { email: 'partner@example.com', expectedUid: 'u-partner' },
];

function extractWebApiKey() {
  if (!fs.existsSync(firebaseOptionsPath)) {
    throw new Error(`Missing firebase_options.dart at ${firebaseOptionsPath}`);
  }

  const source = fs.readFileSync(firebaseOptionsPath, 'utf8');
  const webBlock = source.match(/static const FirebaseOptions web = FirebaseOptions\(([\s\S]*?)\n\s*\);/);
  if (!webBlock) {
    throw new Error('Unable to locate web FirebaseOptions block');
  }

  const apiKeyMatch = webBlock[1].match(/apiKey:\s*'([^']+)'/);
  if (!apiKeyMatch) {
    throw new Error('Unable to locate web Firebase apiKey');
  }

  return apiKeyMatch[1];
}

async function signIn(email, expectedUid) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${email}: ${payload.error?.message || response.status}`);
  }
  if (payload.localId !== expectedUid) {
    throw new Error(`${email}: expected uid ${expectedUid}, got ${payload.localId}`);
  }
  return {
    email,
    uid: payload.localId,
  };
}

async function main() {
  const results = [];
  for (const profile of LOGIN_PROFILES) {
    results.push(await signIn(profile.email, profile.expectedUid));
  }

  const summary = {
    verified: results.length,
    password,
    results,
  };

  if (json) {
    console.log(JSON.stringify(summary, null, 2));
  } else {
    console.log(`Verified ${summary.verified} login profiles with password ${password}`);
    for (const item of results) {
      console.log(`- ${item.email} -> ${item.uid}`);
    }
  }
}

main().catch((error) => {
  console.error(error.message || error);
  if (strict) {
    process.exit(1);
  }
  process.exit(1);
});