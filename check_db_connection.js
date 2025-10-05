const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function check() {
  try {
    console.log('admin.apps.length =', admin.apps.length);
    console.log('FIRESTORE_DATABASE_ID env =', process.env.FIRESTORE_DATABASE_ID || '<not set>');
    // read project id from internal settings if available
    try {
      const settings = db._settings || {};
      console.log('Firestore client settings:', settings);
    } catch (e) {
      console.log('Could not read db._settings');
    }
    // count organizations
    const orgsSnap = await db.collection('organizations').limit(50).get();
    console.log('Found organizations:', orgsSnap.size);
    const ids = orgsSnap.docs.map(d => d.id).slice(0, 10);
    console.log('Sample org ids:', ids);
  } catch (err) {
    console.error('Error:', err);
  }
  process.exit(0);
}

check();
