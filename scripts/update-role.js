// Update a user's role
// Usage: node scripts/update-role.js <email> <new-role>
// Example: node scripts/update-role.js educator@scholesa.test hq

const admin = require('firebase-admin');

// Initialize with your service account
const serviceAccount = require('../studio-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'studio-3328096157-e3f79'
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
