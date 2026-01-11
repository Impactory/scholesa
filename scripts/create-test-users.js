// Create test users for Scholesa platform
// Run: node scripts/create-test-users.js

const admin = require('firebase-admin');

// Initialize with your service account
// IMPORTANT: Download a new key from Firebase Console > Project Settings > Service accounts
const serviceAccount = require('../studio-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'studio-3328096157-e3f79'
});

const auth = admin.auth();
const db = admin.firestore();

const testUsers = [
  { email: 'learner@scholesa.test', role: 'learner', displayName: 'Test Learner' },
  { email: 'educator@scholesa.test', role: 'educator', displayName: 'Test Educator' },
  { email: 'parent@scholesa.test', role: 'parent', displayName: 'Test Parent' },
  { email: 'site@scholesa.test', role: 'site', displayName: 'Test Site Lead' },
  { email: 'hq@scholesa.test', role: 'hq', displayName: 'Test HQ Admin' },
  { email: 'partner@scholesa.test', role: 'partner', displayName: 'Test Partner' },
];

async function createTestUsers() {
  console.log('Creating test users for Scholesa...\n');
  
  for (const user of testUsers) {
    try {
      // Create Auth user
      const userRecord = await auth.createUser({
        email: user.email,
        password: 'Test123!',
        displayName: user.displayName,
        emailVerified: true,
      });
      
      // Create Firestore profile
      await db.collection('users').doc(userRecord.uid).set({
        uid: userRecord.uid,
        email: user.email,
        displayName: user.displayName,
        role: user.role,
        siteIds: ['site_001'],
        status: 'active',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log(`✅ Created ${user.role}: ${user.email} (${userRecord.uid})`);
    } catch (err) {
      if (err.code === 'auth/email-already-exists') {
        console.log(`⏭️  ${user.email} already exists`);
      } else {
        console.error(`❌ Error creating ${user.email}:`, err.message);
      }
    }
  }
  
  console.log('\n✅ Done! Test users ready.');
  console.log('\nLogin credentials:');
  console.log('  Password for all: Test123!');
  process.exit(0);
}

createTestUsers();
