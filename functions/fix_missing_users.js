// One-time fix to create missing user documents for existing accounts
const functions = require("firebase-functions");
const {admin, db} = require("./firebase_config");

exports.fixMissingUserDocuments = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
      try {
        console.log("Starting missing user documents fix...");

        // Get all Firebase Auth users
        const authUsers = [];
        let pageToken;
        do {
          const listUsersResult = await admin.auth().listUsers(1000, pageToken);
          authUsers.push(...listUsersResult.users);
          pageToken = listUsersResult.pageToken;
        } while (pageToken);

        console.log(`Found ${authUsers.length} Firebase Auth users`);

        const missingUsers = [];
        const existingUsers = [];

        // Check which users have Firestore documents
        for (const authUser of authUsers) {
          const userDoc = await db.collection("users").doc(authUser.uid).get();
          if (!userDoc.exists) {
            missingUsers.push(authUser);
          } else {
            existingUsers.push(authUser);
          }
        }

        console.log(`Found ${missingUsers.length} users without Firestore documents`);
        console.log(`Found ${existingUsers.length} users with Firestore documents`);

        const results = [];

        // For each missing user, try to find their organization and create user document
        for (const authUser of missingUsers) {
          try {
            // Find organization created by this user
            const orgsQuery = await db
                .collection("organizations")
                .where("createdBy", "==", authUser.uid)
                .limit(1)
                .get();

            if (!orgsQuery.empty) {
              const orgDoc = orgsQuery.docs[0];
              const orgData = orgDoc.data();
              const orgId = orgDoc.id;

              // Find primary location for this organization
              const locationsQuery = await db
                  .collection("locations")
                  .where("organizationId", "==", orgId)
                  .where("isPrimary", "==", true)
                  .limit(1)
                  .get();

              let primaryLocationId = null;
              if (!locationsQuery.empty) {
                primaryLocationId = locationsQuery.docs[0].id;
              }

              // Extract name from display name or email
              const displayName = authUser.displayName || "";
              const nameParts = displayName.split(" ");
              const firstName = nameParts[0] || authUser.email.split("@")[0];
              const lastName = nameParts.length > 1 ? nameParts.slice(1).join(" ") : "";

              // Create user document
              const userData = {
                firstName: firstName,
                lastName: lastName,
                email: authUser.email,
                userRole: 2, // Owner/Admin role
                organizationId: orgId,
                primaryLocationId: primaryLocationId,
                locationIds: primaryLocationId ? [primaryLocationId] : [],
                jobTypes: [],
                phoneNumber: authUser.phoneNumber || "",
                isAdmin: true,
                isActive: true,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                lastLogin: admin.firestore.FieldValue.serverTimestamp(),
                permissions: {
                  canManageUsers: true,
                  canManageLocations: true,
                  canManageShifts: true,
                  canViewReports: true,
                  canManageSettings: true,
                },
              };

              await db.collection("users").doc(authUser.uid).set(userData);

              results.push({
                uid: authUser.uid,
                email: authUser.email,
                organizationId: orgId,
                organizationName: orgData.name,
                status: "created",
                primaryLocationId: primaryLocationId,
              });

              console.log(`Created user document for ${authUser.email} (${authUser.uid})`);
            } else {
              results.push({
                uid: authUser.uid,
                email: authUser.email,
                status: "no_organization_found",
              });
              console.log(`No organization found for ${authUser.email} (${authUser.uid})`);
            }
          } catch (userError) {
            results.push({
              uid: authUser.uid,
              email: authUser.email,
              status: "error",
              error: userError.message,
            });
            console.error(`Error processing user ${authUser.email}:`, userError);
          }
        }

        res.status(200).json({
          success: true,
          totalAuthUsers: authUsers.length,
          existingUserDocs: existingUsers.length,
          missingUserDocs: missingUsers.length,
          results: results,
          summary: {
            created: results.filter((r) => r.status === "created").length,
            noOrgFound: results.filter((r) => r.status === "no_organization_found").length,
            errors: results.filter((r) => r.status === "error").length,
          },
        });
      } catch (error) {
        console.error("Error fixing missing user documents:", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    });
