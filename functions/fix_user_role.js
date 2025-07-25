const functions = require("firebase-functions");
const {admin, db} = require("./firebase_config");

// One-time fix for user role
exports.fixUserRole = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
      try {
        const userId = "GSMxCCzSnEbqhy1myX5PhBopgIU2";
        const organizationId = "vnE0olvi1Tswjtdb19MI";

        // Update the user document with correct role
        await db.collection("users").doc(userId).set({
          "firstName": "Conor",
          "lastName": "Lawless",
          "email": "conor@flawlessiq.com",
          "userRole": 2, // Owner/Admin role
          "organizationId": organizationId,
          "isAdmin": true,
          "isActive": true,
          "createdAt": admin.firestore.FieldValue.serverTimestamp(),
          "permissions": {
            "canManageUsers": true,
            "canManageLocations": true,
            "canManageShifts": true,
            "canViewReports": true,
            "canManageSettings": true,
          },
        }, {merge: true});

        res.status(200).json({
          success: true,
          message: `User role updated successfully! User ${userId} now has role: 2 (Owner/Admin)`,
        });
      } catch (error) {
        console.error("Error updating user role:", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    });
