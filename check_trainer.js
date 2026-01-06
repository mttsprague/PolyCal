const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkTrainer() {
  const uid = 'YOUR_UID_HERE'; // Replace with your actual UID from the error logs
  
  const trainerDoc = await db.collection('trainers').doc(uid).get();
  
  if (trainerDoc.exists) {
    console.log('✅ Trainer document exists:', trainerDoc.data());
  } else {
    console.log('❌ No trainer document found for UID:', uid);
    console.log('Creating trainer document...');
    
    await db.collection('trainers').doc(uid).set({
      name: 'Matt Sprague',
      email: 'matt@example.com',
      active: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('✅ Trainer document created');
  }
}

checkTrainer().then(() => process.exit(0)).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
