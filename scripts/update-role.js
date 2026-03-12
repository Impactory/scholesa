// Update a user's role
// Usage: node scripts/update-role.js <email> <new-role>
// Example: node scripts/update-role.js educator@scholesa.test hq

const admin = require('firebase-admin');
const path = require('node:path');
const {
  initializeFirebaseAdmin,
  resolveCredentialPath,
  resolveProjectId,
} = require('./firebase_runtime_auth');

const extraCredentialPaths = [
  path.resolve(__dirname, '../studio-service-account.json'),
  path.resolve(__dirname, '../firebase-service-account.json'),
];
const credentialPath = resolveCredentialPath(process.env.GOOGLE_APPLICATION_CREDENTIALS, extraCredentialPaths);

initializeFirebaseAdmin(admin, {
  projectId: resolveProjectId(process.env.FIREBASE_PROJECT_ID, credentialPath),
  credentialPath,
  extraCredentialPaths,
});

const db = admin.firestore();

const VALID_ROLES = ['learner', 'educator', 'parent', 'site', 'partner', 'hq'];

async function updateUserRole(email, newRole) {
  if (!VALID_ROLES.includes(newRole)) {
    console.error(`❌ Invalid role: ${newRole}`);
    console.log(`Valid roles: ${VALID_ROLES.join(', ')}`);
    process.exit(1);
  }

  try {
    // Find user by email
    const snapshot = await db.collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (snapshot.empty) {
      console.error(`❌ User not found: ${email}`);
      process.exit(1);
    }

    const userDoc = snapshot.docs[0];
    const oldRole = userDoc.data().role;

    // Update role
    await userDoc.ref.update({
      role: newRole,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Updated ${email}`);
    console.log(`   Role: ${oldRole} → ${newRole}`);
    process.exit(0);
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

// Parse CLI args
const args = process.argv.slice(2);
if (args.length < 2) {
  console.log('Usage: node scripts/update-role.js <email> <new-role>');
  console.log('');
  console.log('Valid roles:');
  VALID_ROLES.forEach(r => console.log(`  - ${r}${r === 'hq' ? ' (superuser)' : ''}`));
  console.log('');
  console.log('Example: node scripts/update-role.js educator@scholesa.test hq');
  process.exit(1);
}

updateUserRole(args[0], args[1]);
