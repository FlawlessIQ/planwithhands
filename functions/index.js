// Export Stripe functions
// Keep existing function exports but explicitly wire migrateChecklistTemplates
// so it is available as an HTTPS trigger at the top-level export name.
module.exports = {
  ...require("./stripe_functions"),
  ...require("./user_functions"),
  ...require("./places_functions"),
};

module.exports.migrateChecklistTemplates =
  require('./migrations/migrate_checklist_templates_to_subcollections').migrateChecklistTemplates;

module.exports.repairTemplateTaskTitles = require('./migrations/repair_template_task_titles').repairTemplateTaskTitles;
module.exports.repairTaskTitlesFromCsv = require('./migrations/repair_task_titles_from_csv').repairTaskTitlesFromCsv;

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
