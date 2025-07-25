// Debug function to analyze Firestore state
const functions = require("firebase-functions");
const {admin, db} = require("./firebase_config");

exports.debugFirestoreState = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
      try {
        console.log("Starting Firestore state analysis...");

        // Get all Firebase Auth users
        const authUsers = [];
        let pageToken;
        do {
          const listUsersResult = await admin.auth().listUsers(1000, pageToken);
          authUsers.push(...listUsersResult.users);
          pageToken = listUsersResult.pageToken;
        } while (pageToken);

        // Get all organizations
        const orgsSnapshot = await db.collection("organizations").get();
        const organizations = orgsSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        // Get all locations
        const locationsSnapshot = await db.collection("locations").get();
        const locations = locationsSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        // Get all users
        const usersSnapshot = await db.collection("users").get();
        const users = usersSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        // Get all invites
        const invitesSnapshot = await db.collection("invites").get();
        const invites = invitesSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        const analysis = {
          authUsers: authUsers.map((user) => ({
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            creationTime: user.metadata.creationTime,
            lastSignInTime: user.metadata.lastSignInTime,
          })),
          organizations: organizations,
          locations: locations,
          users: users,
          invites: invites,
          summary: {
            totalAuthUsers: authUsers.length,
            totalOrganizations: organizations.length,
            totalLocations: locations.length,
            totalUsers: users.length,
            totalInvites: invites.length,
          },
          orphanedData: {
            authUsersWithoutFirestoreDoc: authUsers.filter(
                (authUser) => !users.find((user) => user.id === authUser.uid),
            ).map((user) => ({
              uid: user.uid,
              email: user.email,
              displayName: user.displayName,
            })),
            firestoreUsersWithoutAuth: users.filter(
                (user) => !authUsers.find((authUser) => authUser.uid === user.id),
            ),
            organizationsWithoutCreator: organizations.filter(
                (org) => !authUsers.find((authUser) => authUser.uid === org.createdBy),
            ),
            locationsWithoutOrganization: locations.filter(
                (location) => !organizations.find((org) => org.id === location.organizationId),
            ),
          },
        };

        res.status(200).json(analysis);
      } catch (error) {
        console.error("Error analyzing Firestore state:", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    });
