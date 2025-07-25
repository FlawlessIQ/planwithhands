const functions = require("firebase-functions");
const {admin, db} = require("./firebase_config");

// Fix the user document to remove string role and use only integer userRole
exports.fixUserRoleCorrectly = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
      try {
        const userId = "GSMxCCzSnEbqhy1myX5PhBopgIU2";
        const organizationId = "vnE0olvi1Tswjtdb19MI";
        const primaryLocationId = "quFoiwZv1jlLZhdaMTUw";

        // Get current user document to preserve some fields
        const userDoc = await db.collection("users").doc(userId).get();
        const currentData = userDoc.data();

        // Create the correct user document structure
        const userData = {
          firstName: "Conor",
          lastName: "Lawless",
          email: "conor@flawlessiq.com",
          userRole: 2, // ✅ INTEGER role (0=user, 1=manager, 2=admin/owner)
          organizationId: organizationId,
          primaryLocationId: primaryLocationId,
          locationIds: [primaryLocationId],
          jobTypes: [],
          phoneNumber: "",
          isAdmin: true,
          isActive: true,
          createdAt: currentData ? currentData.createdAt : admin.firestore.FieldValue.serverTimestamp(),
          lastLogin: admin.firestore.FieldValue.serverTimestamp(),
          permissions: {
            canManageUsers: true,
            canManageLocations: true,
            canManageShifts: true,
            canViewReports: true,
            canManageSettings: true,
          },
        };

        // REPLACE the entire document (not merge) to remove the old "role" field
        await db.collection("users").doc(userId).set(userData);

        res.status(200).json({
          success: true,
          message: `User role fixed correctly! User ${userId} now has userRole: 2 (Owner/Admin)`,
          userData: userData,
        });
      } catch (error) {
        console.error("Error fixing user role:", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    });
