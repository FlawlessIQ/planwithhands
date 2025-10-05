// Run this directly in the Firebase Console under Firestore → Query
// Or use Firebase CLI: firebase firestore:query

// MANUAL INVESTIGATION STEPS for Firebase Console:

console.log("🔍 MANUAL INVESTIGATION GUIDE");
console.log("Use this checklist in Firebase Console to find the issue:");

console.log("\n1️⃣ CHECK ORGANIZATION 3qjYzHagWmfbnMieJ1aj:");
console.log("Path: organizations → 3qjYzHagWmfbnMieJ1aj");
console.log("- Verify this document exists");
console.log("- Check timezone field");

console.log("\n2️⃣ CHECK SHIFTS COLLECTION:");
console.log("Path: organizations → 3qjYzHagWmfbnMieJ1aj → shifts");
console.log("- Look for shift: CioNb2WRnPiRLM6wRH8p (Dinner)");
console.log("- Check its checklistTemplateIds field");
console.log("- Note down all template IDs");

console.log("\n3️⃣ CHECK TEMPLATES COLLECTION:");
console.log("Path: organizations → 3qjYzHagWmfbnMieJ1aj → checklist_templates");
console.log("- List all template documents");
console.log("- For each template ID from step 2, verify it exists here");
console.log("- Check template names and isActive status");

console.log("\n4️⃣ CHECK TODAY'S CHECKLISTS:");
console.log("Path: organizations → 3qjYzHagWmfbnMieJ1aj → locations → sYhcOTkX1VkeoPjtPuwZ → daily_checklists");
console.log("- Look for documents with date: '2025-10-02'");
console.log("- Check their checklistTemplateIds fields");
console.log("- Note which template IDs are being used");

console.log("\n5️⃣ SPECIFIC CHECKS:");
console.log("Template IDs from Dinner shift (verify each exists):");
console.log("- DHz50oOtwOYaH1mRhJlu");
console.log("- JR599ZROMJ93uPr0S4uj"); 
console.log("- C50oqsAGPshQ2Xxv4p2n");

console.log("\n6️⃣ FIND THE PROBLEM:");
console.log("For each template ID that DOESN'T exist:");
console.log("a) Delete it from the shift's checklistTemplateIds array");
console.log("b) OR replace it with a valid template ID");

console.log("\n7️⃣ CLEAN UP TODAY'S CHECKLISTS:");
console.log("Delete any daily_checklists from today that reference non-existent templates");

console.log("\n8️⃣ ALTERNATIVE APPROACH - CHECK ALL SHIFTS:");
console.log("If the issue is in multiple shifts, check each shift in:");
console.log("organizations → 3qjYzHagWmfbnMieJ1aj → shifts");
console.log("And validate their checklistTemplateIds against existing templates");

// QUICK FIX TEMPLATE (modify with actual IDs):
const quickFixTemplate = `
// QUICK FIX: Update shift with valid template IDs
// Path: organizations → 3qjYzHagWmfbnMieJ1aj → shifts → CioNb2WRnPiRLM6wRH8p

// BEFORE (invalid):
{
  "checklistTemplateIds": [
    "DHz50oOtwOYaH1mRhJlu",  // ← Check if this exists
    "JR599ZROMJ93uPr0S4uj",  // ← Check if this exists  
    "C50oqsAGPshQ2Xxv4p2n"   // ← Check if this exists
  ]
}

// AFTER (use only existing template IDs):
{
  "checklistTemplateIds": [
    "5e4L09wyBWDZUJROt1eT",  // "Bar closing"
    "8PhXYUoXvRmBlrZLv7KQ",  // "Line Dinner"
    "C50oqsAGPshQ2Xxv4p2n"   // "Host Stand" (if it exists)
  ]
}
`;

console.log("\n9️⃣ QUICK FIX TEMPLATE:");
console.log(quickFixTemplate);

console.log("\n🔟 VERIFY FIX:");
console.log("1. Save changes to shift");
console.log("2. Wait for next daily generator run (every hour)");
console.log("3. Check that new checklists use valid template IDs");
console.log("4. Verify 'Unknown Template' no longer appears in app");

// Database debugging function
function debugDatabase() {
  console.log("\n🔧 DATABASE DEBUGGING:");
  console.log("My scripts might be connecting to wrong database instance.");
  console.log("Possible issues:");
  console.log("1. Using default database instead of 'planwithhands'");
  console.log("2. Different project or region");
  console.log("3. Permission/authentication issues");
  console.log("4. Data visibility/caching issues");
}

debugDatabase();