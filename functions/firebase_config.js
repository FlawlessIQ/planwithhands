const admin = require("firebase-admin");
const {Firestore} = require("@google-cloud/firestore");

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

// Create a Firestore instance that uses the planwithhands database
// This must match the client-side database ID
const db = new Firestore({
  projectId: "plan-with-hands",
  databaseId: "planwithhands",
});

module.exports = {
  admin,
  db,
};
