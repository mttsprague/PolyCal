// One-time script to add missing lesson package for user
// Run with: node add-missing-package.js

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function addMissingPackage() {
  const userId = 'kmOY58NXOqdKC46FUAx0xlgGyxn1';
  const packageType = 'class_pass';
  const purchaseDate = new Date('2025-12-31T00:00:00Z');
  const expirationDate = new Date('2026-12-31T00:00:00Z'); // 1 year from purchase
  
  const packageData = {
    packageType: packageType,
    totalLessons: 1,
    lessonsUsed: 0,
    purchaseDate: admin.firestore.Timestamp.fromDate(purchaseDate),
    expirationDate: admin.firestore.Timestamp.fromDate(expirationDate),
    transactionId: 'manual-backfill-' + Date.now()
  };

  try {
    const docRef = await db
      .collection('users')
      .doc(userId)
      .collection('lessonPackages')
      .add(packageData);
    
    console.log('✅ Successfully added class pass package!');
    console.log('Document ID:', docRef.id);
    console.log('User ID:', userId);
    console.log('Package Type:', packageType);
    console.log('Total Lessons:', 1);
    console.log('Lessons Used:', 0);
    console.log('Expiration:', expirationDate.toISOString());
  } catch (error) {
    console.error('❌ Error adding package:', error);
  }
  
  process.exit(0);
}

addMissingPackage();
