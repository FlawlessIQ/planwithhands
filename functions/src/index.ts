/* eslint-disable @typescript-eslint/no-require-imports */
import * as dotenv from "dotenv";
import * as admin from "firebase-admin";

// Load local env vars for local/dev + deploy trigger discovery.
// In production, env vars are provided by the Functions runtime; missing .env is OK.
try {
  dotenv.config({ path: `${__dirname}/../.env` });
} catch {
  // ignore
}

// Ensure admin is initialized (idempotent)
try {
	admin.initializeApp();
} catch (e) {
	// noop if already initialized
}

// Log database binding for visibility in logs
const boundDb = process.env.FIRESTORE_DATABASE_ID || "(default)";
console.log(`[functions] Booting with FIRESTORE_DATABASE_ID=${boundDb}`);

// Re-export the JS function implementation under a TypeScript entrypoint name.
// This allows us to have a TS entry while keeping the existing JS implementation.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const syncModule = require("./syncTodayOnTemplateChange");

export const syncTodayOnTemplateChange = syncModule.syncTodayOnTemplateChange as any;
// eslint-disable-next-line @typescript-eslint/no-var-requires
const syncTemplateNameModule = require("./syncTemplateNameChange");
export const syncTemplateNameChange = syncTemplateNameModule.syncTemplateNameChange as any;

// Export cleanup function for deleted templates
export {cleanupDeletedTemplate} from "./cleanupDeletedTemplate";

// eslint-disable-next-line @typescript-eslint/no-var-requires
const syncShiftModule = require("./syncTodayOnShiftChange");
export const syncTodayOnShiftChange = syncShiftModule.syncTodayOnShiftChange as any;

// eslint-disable-next-line @typescript-eslint/no-var-requires
const migrateModule = require("../migrations/migrate_checklist_templates_to_subcollections");
export const migrateChecklistTemplates = migrateModule.migrateChecklistTemplates as any;

// eslint-disable-next-line @typescript-eslint/no-var-requires
const repairModule = require("../migrations/repair_template_task_titles");
export const repairTemplateTaskTitles = repairModule.repairTemplateTaskTitles as any;

// eslint-disable-next-line @typescript-eslint/no-var-requires
const repairCsvModule = require("../migrations/repair_task_titles_from_csv");
export const repairTaskTitlesFromCsv = repairCsvModule.repairTaskTitlesFromCsv as any;

// Export user functions
// eslint-disable-next-line @typescript-eslint/no-var-requires
const userModule = require("../user_functions");
export const createUser = userModule.createUser as any;
export const deleteUser = userModule.deleteUser as any;
export const sendOrganizationSignupNotification = userModule.sendOrganizationSignupNotification as any;

// Export other JS-based functions
// eslint-disable-next-line @typescript-eslint/no-var-requires
const stripeModule = require("../stripe_functions");
export const createCheckoutSession = stripeModule.createCheckoutSession as any;
export const stripeWebhook = stripeModule.stripeWebhook as any;
export const cancelSubscription = stripeModule.cancelSubscription as any;
export const updateSubscription = stripeModule.updateSubscription as any;
export const createBillingPortalSession = stripeModule.createBillingPortalSession as any;

// eslint-disable-next-line @typescript-eslint/no-var-requires
const placesModule = require("../places_functions");
export const placesAutocompleteHttp = placesModule.placesAutocompleteHttp as any;
export const placeDetailsHttp = placesModule.placeDetailsHttp as any;

// Export help functions
// eslint-disable-next-line @typescript-eslint/no-var-requires
const helpModule = require("../help_functions");
export const sendHelpRequest = helpModule.sendHelpRequest as any;

// Signed upload URL provider
// eslint-disable-next-line @typescript-eslint/no-var-requires
const signedUploadModule = require("./signedUpload");
export const getSignedUploadUrl = signedUploadModule.getSignedUploadUrl as any;

// Export proxy upload callable
// eslint-disable-next-line @typescript-eslint/no-var-requires
const proxyUploadModule = require("./proxyUpload");
export const proxyUpload = proxyUploadModule.proxyUpload as any;

// eslint-disable-next-line @typescript-eslint/no-var-requires
const proxyDownloadModule = require("./proxyDownload");
export const proxyDownload = proxyDownloadModule.proxyDownload as any;

// Export new loop-proof messaging notification function
export {onNotificationOutboxCreated} from "./messagingNotifications";

// Export daily generator (scheduled function to create daily checklists)
export {scheduledDailyGenerator} from "./dailyGenerator";

// Export scheduled daily summary (sends daily summary notifications to admins)
export {scheduledDailySummary, triggerDailySummary} from "./scheduledDailySummary";

// Export scheduled carry-forward function (carries forward missed tasks daily)
export {dailyCarryForwardMissedTasks} from "./scheduledCarryForward";

// Export daily summary time change validation and update functions
export {validateDailySummaryTimeChange} from "./validateDailySummaryTimeChange";
export {updateOrganizationDailySummaryTime} from "./updateOrganizationDailySummaryTime";
export {sendTodaySummaryNow} from "./sendTodaySummaryNow";
export {diagnoseRuntimeEnv} from "./diagnoseRuntimeEnv";

// Shared Mode (communal device / PIN)
export {sharedModeSetPin, sharedModeVerifyPin} from "./sharedMode";

// Export manual test email endpoint for one-off debugging
export {manualTestEmail} from "./manualTestEmail";

// Export checklist auditing and diagnostics endpoints
export {auditOrgChecklists} from "./auditOrgChecklists";
// export {diagnoseLocationChecklists} from "./diagnoseLocationChecklists";
export {enforceDailyChecklistOwnership} from "./enforceDailyChecklistOwnership";

// Export new Payment Element Stripe functions
export {
  ensureStripeCustomer,
  createSubscriptionElements,
  createSetupIntentForCustomer,
  createEmbeddedCheckoutSession,
  getCheckoutSessionStatus,
  // Expose both callable and HTTP publishable-key endpoints
  getStripePublishableKey,
  getStripePublishableKeyHttp,
  updateSubscriptionQuantity,
  cancelSubscription as cancelSubscriptionElements,
  createBillingPortalSession as createBillingPortalSessionElements,
  getSubscriptionData,
  validateCoupon,
  backfillSubscriptionQuantityForOrg,
} from "./stripe";
