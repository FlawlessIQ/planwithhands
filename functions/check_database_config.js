const functions = require("firebase-functions");
const {admin, db} = require("./firebase_config");

// Check database configuration and target
exports.checkDatabaseConfig = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
      try {
        console.log("Checking database configuration...");

        // Get the database reference info
        const dbInfo = {
          databaseId: db._settings ? db._settings.databaseId : "(default)",
          projectId: db._settings ? db._settings.projectId : admin.app().options.projectId,
        };

        console.log("Database settings:", dbInfo);

        // Try to read the specific user document
        const userId = "GSMxCCzSnEbqhy1myX5PhBopgIU2";
        const userDoc = await db.collection("users").doc(userId).get();

        const userExists = userDoc.exists;
        const userData = userExists ? userDoc.data() : null;

        // Try to read from (default) database explicitly
        const defaultDb = admin.firestore();
        const defaultUserDoc = await defaultDb.collection("users").doc(userId).get();
        const defaultUserExists = defaultUserDoc.exists;
        const defaultUserData = defaultUserExists ? defaultUserDoc.data() : null;

        // Get all users from both databases
        const usersSnapshot = await db.collection("users").get();
        const allUsers = usersSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        const defaultUsersSnapshot = await defaultDb.collection("users").get();
        const allDefaultUsers = defaultUsersSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        res.status(200).json({
          success: true,
          config: dbInfo,
          targetDatabase: {
            userExists: userExists,
            userData: userData,
            totalUsers: allUsers.length,
            allUsers: allUsers,
          },
          defaultDatabase: {
            userExists: defaultUserExists,
            userData: defaultUserData,
            totalUsers: allDefaultUsers.length,
            allUsers: allDefaultUsers,
          },
          comparison: {
            sameUserCount: allUsers.length === allDefaultUsers.length,
            userExistsInTarget: userExists,
            userExistsInDefault: defaultUserExists,
          },
        });
      } catch (error) {
        console.error("Error checking database config:", error);
        res.status(500).json({
          success: false,
          error: error.message,
          stack: error.stack,
        });
      }
    });
