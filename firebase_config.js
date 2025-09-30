const admin = require('firebase-admin');

// Singleton for Firebase Admin initialization
let db = null;

function getDB() {
  if (db) {
    return db;
  }

  // Initialize Firebase Admin SDK if not already done
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  }

  // Get Firestore instance and configure for planwithhands database
  db = admin.firestore();
  
  // Only set settings if this is the first time
  try {
    db.settings({
      databaseId: 'planwithhands'
    });
  } catch (error) {
    // Settings already set, which is fine
    if (!error.message.includes('already been initialized')) {
      throw error;
    }
  }

  return db;
}

module.exports = {
  getDB,
  admin
};