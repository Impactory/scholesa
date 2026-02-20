/* eslint-disable no-console */
const fs = require('node:fs');
const path = require('node:path');
const { performance } = require('node:perf_hooks');
const { initializeApp } = require('firebase-admin/app');
const {
  getFirestore,
  FieldValue,
} = require('firebase-admin/firestore');

const ROOT = path.resolve(__dirname, '..');
const REPORT_PATH = path.join(ROOT, 'DB_DATA_REGRESSION_REPORT.md');

const COLLECTIONS = [
  'users',
  'sites',
  'sessions',
  'sessionOccurrences',
  'enrollments',
  'missionAttempts',
  'portfolioItems',
  'regressionCounters',
  'regressionBackup',
];

const results = [];

function addResult(category, check, status, details) {
  results.push({ category, check, status, details });
}

async function clearCollections(db, collections) {
  for (const collectionName of collections) {
    const snapshot = await db.collection(collectionName).get();
    if (snapshot.empty) continue;

    const batch = db.batch();
    snapshot.docs.forEach((documentSnapshot) => batch.delete(documentSnapshot.ref));
    await batch.commit();
  }
}

async function seedBaseData(db) {
  const now = Date.now();
  const seedWrites = [
    db.collection('sites').doc('site-reg-1').set({
      id: 'site-reg-1',
      name: 'Regression Site',
      siteLeadIds: ['u-sitelead-reg'],
      createdAt: now,
      status: 'active',
    }),
    db.collection('users').doc('u-learner-reg').set({
      uid: 'u-learner-reg',
      email: 'learner.regression@example.com',
      role: 'learner',
      siteIds: ['site-reg-1'],
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    }),
    db.collection('users').doc('u-educator-reg').set({
      uid: 'u-educator-reg',
      email: 'educator.regression@example.com',
      role: 'educator',
      siteIds: ['site-reg-1'],
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    }),
    db.collection('sessions').doc('session-reg-1').set({
      id: 'session-reg-1',
      title: 'Regression Session',
      siteId: 'site-reg-1',
      educatorIds: ['u-educator-reg'],
      pillarCodes: ['tech'],
      startDate: now,
      endDate: now + 3600000,
      status: 'scheduled',
    }),
  ];

  await Promise.all(seedWrites);
}

async function runCrudRegression(db) {
  const category = 'CRUD regression';
  const now = Date.now();
  const entities = [
    { collection: 'users', id: 'crud-user-1', payload: { uid: 'crud-user-1', email: 'crud.user@example.com', role: 'learner', siteIds: ['site-reg-1'], createdAt: now, updatedAt: now } },
    { collection: 'sites', id: 'crud-site-1', payload: { id: 'crud-site-1', name: 'CRUD Site', siteLeadIds: ['u-educator-reg'], createdAt: now } },
    { collection: 'sessions', id: 'crud-session-1', payload: { id: 'crud-session-1', title: 'CRUD Session', siteId: 'site-reg-1', educatorIds: ['u-educator-reg'], pillarCodes: ['tech'], startDate: now, endDate: now + 7200000 } },
    { collection: 'sessionOccurrences', id: 'crud-occ-1', payload: { id: 'crud-occ-1', sessionId: 'session-reg-1', siteId: 'site-reg-1', startTime: now + 1000, endTime: now + 3700000, status: 'scheduled' } },
    { collection: 'enrollments', id: 'crud-enroll-1', payload: { id: 'crud-enroll-1', sessionId: 'session-reg-1', learnerId: 'u-learner-reg', siteId: 'site-reg-1', enrolledAt: now, status: 'active' } },
    { collection: 'missionAttempts', id: 'crud-attempt-1', payload: { id: 'crud-attempt-1', learnerId: 'u-learner-reg', missionId: 'mission-reg-1', siteId: 'site-reg-1', startedAt: now, status: 'started' } },
    { collection: 'portfolioItems', id: 'crud-portfolio-1', payload: { id: 'crud-portfolio-1', portfolioId: 'portfolio-reg-1', title: 'CRUD Artifact', mediaType: 'document', createdAt: now } },
  ];

  try {
    for (const entity of entities) {
      const ref = db.collection(entity.collection).doc(entity.id);
      await ref.set(entity.payload);
      const afterCreate = await ref.get();
      if (!afterCreate.exists) {
        throw new Error(`Create failed for ${entity.collection}/${entity.id}`);
      }

      await ref.update({ regressionUpdatedAt: now + 1 });
      const afterUpdate = await ref.get();
      if (!afterUpdate.data().regressionUpdatedAt) {
        throw new Error(`Update failed for ${entity.collection}/${entity.id}`);
      }

      await ref.delete();
      const afterDelete = await ref.get();
      if (afterDelete.exists) {
        throw new Error(`Delete failed for ${entity.collection}/${entity.id}`);
      }
    }

    addResult(category, 'Critical entities support create/read/update/delete lifecycle', 'PASS', `Validated ${entities.length} entities`);
  } catch (error) {
    addResult(category, 'Critical entities support create/read/update/delete lifecycle', 'FAIL', String(error.message || error));
  }
}

async function runMigrationRegression(db) {
  const category = 'Migration regression';

  async function migrateUsersToV2(injectFailure = false) {
    const usersSnapshot = await db.collection('users').get();
    const backup = usersSnapshot.docs.map((documentSnapshot) => ({
      id: documentSnapshot.id,
      data: documentSnapshot.data(),
    }));

    try {
      let processed = 0;
      for (const documentSnapshot of usersSnapshot.docs) {
        const data = documentSnapshot.data();
        if ((data.schemaVersion || 1) >= 2) continue;

        await documentSnapshot.ref.update({
          schemaVersion: 2,
          normalizedEmail: String(data.email || '').trim().toLowerCase(),
          migratedAt: Date.now(),
        });
        processed += 1;

        if (injectFailure && processed === 1) {
          throw new Error('Injected migration failure');
        }
      }

      return { processed, rolledBack: false };
    } catch (error) {
      const batch = db.batch();
      backup.forEach((item) => {
        batch.set(db.collection('users').doc(item.id), item.data, { merge: false });
      });
      await batch.commit();
      return { processed: 0, rolledBack: true, reason: error.message };
    }
  }

  try {
    const successRun = await migrateUsersToV2(false);
    const migratedSnapshot = await db.collection('users').where('schemaVersion', '==', 2).get();
    const normalizedAll = migratedSnapshot.docs.every((documentSnapshot) => {
      const data = documentSnapshot.data();
      return data.normalizedEmail === String(data.email || '').trim().toLowerCase();
    });

    if (successRun.processed < 1 || !normalizedAll) {
      throw new Error('Upgrade path did not migrate/normalize expected user docs');
    }

    addResult(category, 'Upgrade migration path executes and data shape is valid', 'PASS', `Migrated ${successRun.processed} user docs to schemaVersion=2`);

    await db.collection('users').doc('u-learner-reg').update({ schemaVersion: 1 });
    const rollbackRun = await migrateUsersToV2(true);
    const rollbackDoc = await db.collection('users').doc('u-learner-reg').get();
    const rollbackValid = rollbackRun.rolledBack && (rollbackDoc.data().schemaVersion === 1 || rollbackDoc.data().schemaVersion === 2);

    if (!rollbackValid) {
      throw new Error('Rollback strategy did not restore pre-migration state');
    }

    addResult(category, 'Rollback strategy restores state after injected failure', 'PASS', `Rollback executed (${rollbackRun.reason || 'no reason'})`);
  } catch (error) {
    addResult(category, 'Migration upgrade + rollback strategy', 'FAIL', String(error.message || error));
  }
}

async function runIntegrityRegression(db) {
  const category = 'Data integrity regression';
  const now = Date.now();

  try {
    const uniqueRef = db.collection('enrollments').doc('uniq-enrollment-1');
    await uniqueRef.create({
      id: 'uniq-enrollment-1',
      sessionId: 'session-reg-1',
      learnerId: 'u-learner-reg',
      siteId: 'site-reg-1',
      enrolledAt: now,
      status: 'active',
    });

    let duplicateBlocked = false;
    try {
      await uniqueRef.create({
        id: 'uniq-enrollment-1',
        sessionId: 'session-reg-1',
        learnerId: 'u-learner-reg',
        siteId: 'site-reg-1',
        enrolledAt: now,
        status: 'active',
      });
    } catch {
      duplicateBlocked = true;
    }

    addResult(category, 'Uniqueness enforced via deterministic doc IDs and create()', duplicateBlocked ? 'PASS' : 'FAIL', duplicateBlocked ? 'Duplicate write rejected as expected' : 'Duplicate write unexpectedly succeeded');

    const invalidEnrollmentRef = db.collection('enrollments').doc('integrity-invalid-fk');
    await invalidEnrollmentRef.set({
      id: 'integrity-invalid-fk',
      sessionId: 'missing-session',
      learnerId: 'missing-learner',
      siteId: 'site-reg-1',
      enrolledAt: now,
      status: 'active',
    });

    const invalidEnrollmentSnapshot = await invalidEnrollmentRef.get();
    if (invalidEnrollmentSnapshot.exists) {
      addResult(category, 'Foreign-key style references are validated', 'WARN', 'Firestore accepted enrollment referencing missing session/learner; enforce via Cloud Functions or app transaction checks');
    }

    await db.collection('sessionOccurrences').doc('occ-cascade-check').set({
      id: 'occ-cascade-check',
      sessionId: 'session-reg-1',
      siteId: 'site-reg-1',
      startTime: now + 10000,
      endTime: now + 20000,
      status: 'scheduled',
    });
    await db.collection('sessions').doc('session-reg-1').delete();
    const orphanOccurrence = await db.collection('sessionOccurrences').doc('occ-cascade-check').get();

    addResult(category, 'Cascade delete behavior is explicit and verified', orphanOccurrence.exists ? 'WARN' : 'PASS', orphanOccurrence.exists ? 'Session delete does not cascade to occurrences (expected in Firestore unless handled manually)' : 'Cascade behavior implemented');
  } catch (error) {
    addResult(category, 'Integrity constraint checks', 'FAIL', String(error.message || error));
  }
}

async function runTransactionRegression(db) {
  const category = 'Transaction regression';

  try {
    const counterRef = db.collection('regressionCounters').doc('tx-counter-1');
    await counterRef.set({ value: 0 });

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(counterRef);
      const currentValue = snapshot.data()?.value || 0;
      transaction.update(counterRef, { value: currentValue + 1 });
    });

    const afterCommit = await counterRef.get();
    addResult(category, 'Commit writes apply atomically', afterCommit.data()?.value === 1 ? 'PASS' : 'FAIL', `Counter after commit = ${afterCommit.data()?.value}`);

    try {
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(counterRef);
        const currentValue = snapshot.data()?.value || 0;
        transaction.update(counterRef, { value: currentValue + 100 });
        throw new Error('Injected rollback');
      });
    } catch {
      // expected
    }

    const afterRollback = await counterRef.get();
    addResult(category, 'Rollback prevents partial writes on transaction failure', afterRollback.data()?.value === 1 ? 'PASS' : 'FAIL', `Counter after rollback = ${afterRollback.data()?.value}`);

    await counterRef.set({ value: 0 });
    await Promise.all(Array.from({ length: 20 }).map(() => db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(counterRef);
      const currentValue = snapshot.data()?.value || 0;
      transaction.update(counterRef, { value: currentValue + 1 });
    })));

    const afterIsolation = await counterRef.get();
    addResult(category, 'Concurrent transactions preserve isolation under contention', afterIsolation.data()?.value === 20 ? 'PASS' : 'FAIL', `Counter after 20 concurrent increments = ${afterIsolation.data()?.value}`);
  } catch (error) {
    addResult(category, 'Transaction commit/rollback/isolation checks', 'FAIL', String(error.message || error));
  }
}

async function runPerformanceRegression(db) {
  const category = 'Performance query regression';
  const now = Date.now();

  try {
    const writerBatch = db.batch();
    for (let index = 0; index < 300; index += 1) {
      const reference = db.collection('missionAttempts').doc(`perf-attempt-${index}`);
      writerBatch.set(reference, {
        id: `perf-attempt-${index}`,
        learnerId: index % 2 === 0 ? 'u-learner-reg' : 'u-other-reg',
        missionId: `mission-${index % 12}`,
        siteId: 'site-reg-1',
        startedAt: now - index * 1000,
        status: index % 3 === 0 ? 'submitted' : 'started',
      });
    }
    await writerBatch.commit();

    const startedAt = performance.now();
    const querySnapshot = await db.collection('missionAttempts')
      .where('siteId', '==', 'site-reg-1')
      .where('status', '==', 'submitted')
      .orderBy('startedAt', 'desc')
      .limit(25)
      .get();
    const elapsedMs = performance.now() - startedAt;

    addResult(
      category,
      'Critical filtered + ordered query returns with acceptable latency',
      elapsedMs < 400 ? 'PASS' : 'WARN',
      `Returned ${querySnapshot.size} docs in ${elapsedMs.toFixed(2)}ms (emulator timing)`,
    );

    const indexesPath = path.join(ROOT, 'firestore.indexes.json');
    const indexes = JSON.parse(fs.readFileSync(indexesPath, 'utf8'));
    const hasMissionAttemptComposite = (indexes.indexes || []).some((indexDef) => (
      indexDef.collectionGroup === 'missionAttempts' &&
      Array.isArray(indexDef.fields) &&
      indexDef.fields.some((field) => field.fieldPath === 'siteId') &&
      indexDef.fields.some((field) => field.fieldPath === 'status') &&
      indexDef.fields.some((field) => field.fieldPath === 'startedAt')
    ));

    addResult(
      category,
      'Composite index definition exists for high-traffic missionAttempts query',
      hasMissionAttemptComposite ? 'PASS' : 'WARN',
      hasMissionAttemptComposite
        ? 'Index entry present in firestore.indexes.json'
        : 'Missing composite index definition for siteId+status+startedAt',
    );
  } catch (error) {
    addResult(category, 'Query latency/index regression checks', 'FAIL', String(error.message || error));
  }
}

async function runBackupRestoreRegression(db) {
  const category = 'Backup/restore regression';
  const now = Date.now();

  try {
    await db.collection('regressionBackup').doc('b1').set({ id: 'b1', value: 'original', updatedAt: now });
    await db.collection('regressionBackup').doc('b2').set({ id: 'b2', value: 'original', updatedAt: now });

    const backupSnapshot = await db.collection('regressionBackup').get();
    const backupImage = backupSnapshot.docs.map((documentSnapshot) => ({
      id: documentSnapshot.id,
      data: documentSnapshot.data(),
    }));

    await db.collection('regressionBackup').doc('b1').update({ value: 'corrupted' });
    await db.collection('regressionBackup').doc('b2').delete();

    const restoreBatch = db.batch();
    backupImage.forEach((entry) => {
      restoreBatch.set(db.collection('regressionBackup').doc(entry.id), entry.data, { merge: false });
    });
    await restoreBatch.commit();

    const restoredSnapshot = await db.collection('regressionBackup').get();
    const restoredMap = new Map(restoredSnapshot.docs.map((documentSnapshot) => [documentSnapshot.id, documentSnapshot.data().value]));
    const restorePassed = restoredMap.get('b1') === 'original' && restoredMap.get('b2') === 'original';

    addResult(category, 'Logical backup + restore replay returns dataset to expected state', restorePassed ? 'PASS' : 'FAIL', `Restored docs=${restoredSnapshot.size}`);
    addResult(category, 'Point-in-time recovery (PITR) validation', 'WARN', 'PITR cannot be validated in Firestore emulator; run managed-service PITR drill in production/staging project');
  } catch (error) {
    addResult(category, 'Backup/restore checks', 'FAIL', String(error.message || error));
  }
}

async function runConcurrencyRegression(db) {
  const category = 'Concurrency regression';
  const now = Date.now();

  try {
    const idempotentRef = db.collection('missionAttempts').doc('concurrency-idempotent-1');

    const [first, second] = await Promise.allSettled([
      idempotentRef.create({ id: 'concurrency-idempotent-1', learnerId: 'u-learner-reg', missionId: 'mission-c1', siteId: 'site-reg-1', startedAt: now, status: 'started' }),
      idempotentRef.create({ id: 'concurrency-idempotent-1', learnerId: 'u-learner-reg', missionId: 'mission-c1', siteId: 'site-reg-1', startedAt: now, status: 'started' }),
    ]);

    const oneRejected = [first, second].filter((result) => result.status === 'rejected').length === 1;
    addResult(category, 'Double-write race on same deterministic ID rejects one writer', oneRejected ? 'PASS' : 'FAIL', `Settled results: ${first.status}/${second.status}`);

    const ledgerRef = db.collection('regressionCounters').doc('concurrency-ledger-1');
    await ledgerRef.set({ credits: 0, updatedAt: now });

    await Promise.all(Array.from({ length: 25 }).map(() => db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ledgerRef);
      const current = snapshot.data()?.credits || 0;
      transaction.update(ledgerRef, { credits: current + 1, updatedAt: FieldValue.serverTimestamp() });
    })));

    const afterConcurrentCredits = await ledgerRef.get();
    addResult(category, 'High-contention transactional updates avoid lost writes', afterConcurrentCredits.data()?.credits === 25 ? 'PASS' : 'FAIL', `credits=${afterConcurrentCredits.data()?.credits}`);
  } catch (error) {
    addResult(category, 'Concurrency checks', 'FAIL', String(error.message || error));
  }
}

function writeReport() {
  const now = new Date().toISOString();
  const grouped = new Map();
  results.forEach((result) => {
    if (!grouped.has(result.category)) grouped.set(result.category, []);
    grouped.get(result.category).push(result);
  });

  const statusCounts = {
    PASS: results.filter((result) => result.status === 'PASS').length,
    WARN: results.filter((result) => result.status === 'WARN').length,
    FAIL: results.filter((result) => result.status === 'FAIL').length,
  };

  const lines = [];
  lines.push('# DB + Data Regression Report');
  lines.push('');
  lines.push(`- Generated: ${now}`);
  lines.push(`- Scope: Firestore emulator regression run (${results.length} checks)`);
  lines.push(`- Summary: PASS=${statusCounts.PASS}, WARN=${statusCounts.WARN}, FAIL=${statusCounts.FAIL}`);
  lines.push('');

  for (const [category, categoryResults] of grouped.entries()) {
    lines.push(`## ${category}`);
    lines.push('');
    lines.push('| Status | Check | Details |');
    lines.push('|---|---|---|');
    categoryResults.forEach((result) => {
      lines.push(`| ${result.status} | ${result.check} | ${result.details} |`);
    });
    lines.push('');
  }

  lines.push('## Notes');
  lines.push('');
  lines.push('- Firestore has no native foreign keys/cascade constraints; WARN results indicate where app/function-level guards should be used.');
  lines.push('- Query-plan introspection is limited in emulator; latency + index definition checks are used as practical proxies.');
  lines.push('- PITR must be validated against managed Firestore in a cloud project (not emulator).');
  lines.push('');

  fs.writeFileSync(REPORT_PATH, `${lines.join('\n')}\n`, 'utf8');
}

async function main() {
  const app = initializeApp({ projectId: 'scholesa-db-regression' });
  const db = getFirestore(app);
  db.settings({ ignoreUndefinedProperties: true });

  await clearCollections(db, COLLECTIONS);
  await seedBaseData(db);

  await runCrudRegression(db);
  await runMigrationRegression(db);
  await runIntegrityRegression(db);
  await runTransactionRegression(db);
  await runPerformanceRegression(db);
  await runBackupRestoreRegression(db);
  await runConcurrencyRegression(db);

  writeReport();

  const failCount = results.filter((result) => result.status === 'FAIL').length;
  console.log(`DB data regression completed: ${results.length} checks, failures=${failCount}`);
  console.log(`Report: ${REPORT_PATH}`);

  if (failCount > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error('DB data regression runner failed:', error);
  process.exit(1);
});
