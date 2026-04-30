"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.createSetupIntentForCustomer = exports.createSubscriptionElements = exports.ensureStripeCustomer = exports.enforceDailyChecklistOwnership = exports.auditOrgChecklists = exports.manualTestEmail = exports.sharedModeVerifyPin = exports.sharedModeSetPin = exports.updateCrmOrganizationFlags = exports.createCrmPromotionCode = exports.listCrmPromotionCodes = exports.getCrmOrganization = exports.getCrmDashboard = exports.diagnoseRuntimeEnv = exports.sendTodaySummaryNow = exports.updateOrganizationDailySummaryTime = exports.validateDailySummaryTimeChange = exports.dailyCarryForwardMissedTasks = exports.triggerDailySummary = exports.scheduledDailySummary = exports.scheduledDailyGenerator = exports.onNotificationOutboxCreated = exports.proxyDownload = exports.proxyUpload = exports.getSignedUploadUrl = exports.sendHelpRequest = exports.placeDetailsHttp = exports.placesAutocompleteHttp = exports.createBillingPortalSession = exports.updateSubscription = exports.cancelSubscription = exports.stripeWebhook = exports.createCheckoutSession = exports.lookupInviteByEmail = exports.revokeInvite = exports.resendInvite = exports.acceptInvite = exports.verifyInvite = exports.createInvite = exports.sendOrganizationSignupNotification = exports.createOrganizationSignup = exports.deleteUser = exports.createUser = exports.repairTaskTitlesFromCsv = exports.repairTemplateTaskTitles = exports.migrateChecklistTemplates = exports.syncTodayOnShiftChange = exports.cleanupDeletedTemplate = exports.syncTemplateNameChange = exports.syncTodayOnTemplateChange = void 0;
exports.backfillSubscriptionQuantityForOrg = exports.validateCoupon = exports.getSubscriptionData = exports.createBillingPortalSessionElements = exports.cancelSubscriptionElements = exports.updateSubscriptionQuantity = exports.getStripePublishableKeyHttp = exports.getStripePublishableKey = exports.getCheckoutSessionStatus = exports.createEmbeddedCheckoutSession = void 0;
/* eslint-disable @typescript-eslint/no-require-imports */
const dotenv = __importStar(require("dotenv"));
const admin = __importStar(require("firebase-admin"));
// Load local env vars for local/dev + deploy trigger discovery.
// In production, env vars are provided by the Functions runtime; missing .env is OK.
try {
    dotenv.config({ path: `${__dirname}/../.env` });
}
catch {
    // ignore
}
// Ensure admin is initialized (idempotent)
try {
    admin.initializeApp();
}
catch (e) {
    // noop if already initialized
}
// Log database binding for visibility in logs
const boundDb = process.env.FIRESTORE_DATABASE_ID || "(default)";
console.log(`[functions] Booting with FIRESTORE_DATABASE_ID=${boundDb}`);
// Re-export the JS function implementation under a TypeScript entrypoint name.
// This allows us to have a TS entry while keeping the existing JS implementation.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const syncModule = require("./syncTodayOnTemplateChange");
exports.syncTodayOnTemplateChange = syncModule.syncTodayOnTemplateChange;
// eslint-disable-next-line @typescript-eslint/no-var-requires
const syncTemplateNameModule = require("./syncTemplateNameChange");
exports.syncTemplateNameChange = syncTemplateNameModule.syncTemplateNameChange;
// Export cleanup function for deleted templates
var cleanupDeletedTemplate_1 = require("./cleanupDeletedTemplate");
Object.defineProperty(exports, "cleanupDeletedTemplate", { enumerable: true, get: function () { return cleanupDeletedTemplate_1.cleanupDeletedTemplate; } });
// eslint-disable-next-line @typescript-eslint/no-var-requires
const syncShiftModule = require("./syncTodayOnShiftChange");
exports.syncTodayOnShiftChange = syncShiftModule.syncTodayOnShiftChange;
// eslint-disable-next-line @typescript-eslint/no-var-requires
const migrateModule = require("../migrations/migrate_checklist_templates_to_subcollections");
exports.migrateChecklistTemplates = migrateModule.migrateChecklistTemplates;
// eslint-disable-next-line @typescript-eslint/no-var-requires
const repairModule = require("../migrations/repair_template_task_titles");
exports.repairTemplateTaskTitles = repairModule.repairTemplateTaskTitles;
// eslint-disable-next-line @typescript-eslint/no-var-requires
const repairCsvModule = require("../migrations/repair_task_titles_from_csv");
exports.repairTaskTitlesFromCsv = repairCsvModule.repairTaskTitlesFromCsv;
// Export user functions
// eslint-disable-next-line @typescript-eslint/no-var-requires
const userModule = require("../user_functions");
exports.createUser = userModule.createUser;
exports.deleteUser = userModule.deleteUser;
exports.createOrganizationSignup = userModule.createOrganizationSignup;
exports.sendOrganizationSignupNotification = userModule.sendOrganizationSignupNotification;
// eslint-disable-next-line @typescript-eslint/no-var-requires
const inviteModule = require("../invite_functions");
exports.createInvite = inviteModule.createInvite;
exports.verifyInvite = inviteModule.verifyInvite;
exports.acceptInvite = inviteModule.acceptInvite;
exports.resendInvite = inviteModule.resendInvite;
exports.revokeInvite = inviteModule.revokeInvite;
exports.lookupInviteByEmail = inviteModule.lookupInviteByEmail;
// Export other JS-based functions
// eslint-disable-next-line @typescript-eslint/no-var-requires
const stripeModule = require("../stripe_functions");
exports.createCheckoutSession = stripeModule.createCheckoutSession;
exports.stripeWebhook = stripeModule.stripeWebhook;
exports.cancelSubscription = stripeModule.cancelSubscription;
exports.updateSubscription = stripeModule.updateSubscription;
exports.createBillingPortalSession = stripeModule.createBillingPortalSession;
// eslint-disable-next-line @typescript-eslint/no-var-requires
const placesModule = require("../places_functions");
exports.placesAutocompleteHttp = placesModule.placesAutocompleteHttp;
exports.placeDetailsHttp = placesModule.placeDetailsHttp;
// Export help functions
// eslint-disable-next-line @typescript-eslint/no-var-requires
const helpModule = require("../help_functions");
exports.sendHelpRequest = helpModule.sendHelpRequest;
// Signed upload URL provider
// eslint-disable-next-line @typescript-eslint/no-var-requires
const signedUploadModule = require("./signedUpload");
exports.getSignedUploadUrl = signedUploadModule.getSignedUploadUrl;
// Export proxy upload callable
// eslint-disable-next-line @typescript-eslint/no-var-requires
const proxyUploadModule = require("./proxyUpload");
exports.proxyUpload = proxyUploadModule.proxyUpload;
// eslint-disable-next-line @typescript-eslint/no-var-requires
const proxyDownloadModule = require("./proxyDownload");
exports.proxyDownload = proxyDownloadModule.proxyDownload;
// Export new loop-proof messaging notification function
var messagingNotifications_1 = require("./messagingNotifications");
Object.defineProperty(exports, "onNotificationOutboxCreated", { enumerable: true, get: function () { return messagingNotifications_1.onNotificationOutboxCreated; } });
// Export daily generator (scheduled function to create daily checklists)
var dailyGenerator_1 = require("./dailyGenerator");
Object.defineProperty(exports, "scheduledDailyGenerator", { enumerable: true, get: function () { return dailyGenerator_1.scheduledDailyGenerator; } });
// Export scheduled daily summary (sends daily summary notifications to admins)
var scheduledDailySummary_1 = require("./scheduledDailySummary");
Object.defineProperty(exports, "scheduledDailySummary", { enumerable: true, get: function () { return scheduledDailySummary_1.scheduledDailySummary; } });
Object.defineProperty(exports, "triggerDailySummary", { enumerable: true, get: function () { return scheduledDailySummary_1.triggerDailySummary; } });
// Export scheduled carry-forward function (carries forward missed tasks daily)
var scheduledCarryForward_1 = require("./scheduledCarryForward");
Object.defineProperty(exports, "dailyCarryForwardMissedTasks", { enumerable: true, get: function () { return scheduledCarryForward_1.dailyCarryForwardMissedTasks; } });
// Export daily summary time change validation and update functions
var validateDailySummaryTimeChange_1 = require("./validateDailySummaryTimeChange");
Object.defineProperty(exports, "validateDailySummaryTimeChange", { enumerable: true, get: function () { return validateDailySummaryTimeChange_1.validateDailySummaryTimeChange; } });
var updateOrganizationDailySummaryTime_1 = require("./updateOrganizationDailySummaryTime");
Object.defineProperty(exports, "updateOrganizationDailySummaryTime", { enumerable: true, get: function () { return updateOrganizationDailySummaryTime_1.updateOrganizationDailySummaryTime; } });
var sendTodaySummaryNow_1 = require("./sendTodaySummaryNow");
Object.defineProperty(exports, "sendTodaySummaryNow", { enumerable: true, get: function () { return sendTodaySummaryNow_1.sendTodaySummaryNow; } });
var diagnoseRuntimeEnv_1 = require("./diagnoseRuntimeEnv");
Object.defineProperty(exports, "diagnoseRuntimeEnv", { enumerable: true, get: function () { return diagnoseRuntimeEnv_1.diagnoseRuntimeEnv; } });
var crm_1 = require("./crm");
Object.defineProperty(exports, "getCrmDashboard", { enumerable: true, get: function () { return crm_1.getCrmDashboard; } });
Object.defineProperty(exports, "getCrmOrganization", { enumerable: true, get: function () { return crm_1.getCrmOrganization; } });
Object.defineProperty(exports, "listCrmPromotionCodes", { enumerable: true, get: function () { return crm_1.listCrmPromotionCodes; } });
Object.defineProperty(exports, "createCrmPromotionCode", { enumerable: true, get: function () { return crm_1.createCrmPromotionCode; } });
Object.defineProperty(exports, "updateCrmOrganizationFlags", { enumerable: true, get: function () { return crm_1.updateCrmOrganizationFlags; } });
// Shared Mode (communal device / PIN)
var sharedMode_1 = require("./sharedMode");
Object.defineProperty(exports, "sharedModeSetPin", { enumerable: true, get: function () { return sharedMode_1.sharedModeSetPin; } });
Object.defineProperty(exports, "sharedModeVerifyPin", { enumerable: true, get: function () { return sharedMode_1.sharedModeVerifyPin; } });
// Export manual test email endpoint for one-off debugging
var manualTestEmail_1 = require("./manualTestEmail");
Object.defineProperty(exports, "manualTestEmail", { enumerable: true, get: function () { return manualTestEmail_1.manualTestEmail; } });
// Export checklist auditing and diagnostics endpoints
var auditOrgChecklists_1 = require("./auditOrgChecklists");
Object.defineProperty(exports, "auditOrgChecklists", { enumerable: true, get: function () { return auditOrgChecklists_1.auditOrgChecklists; } });
// export {diagnoseLocationChecklists} from "./diagnoseLocationChecklists";
var enforceDailyChecklistOwnership_1 = require("./enforceDailyChecklistOwnership");
Object.defineProperty(exports, "enforceDailyChecklistOwnership", { enumerable: true, get: function () { return enforceDailyChecklistOwnership_1.enforceDailyChecklistOwnership; } });
// Export new Payment Element Stripe functions
var stripe_1 = require("./stripe");
Object.defineProperty(exports, "ensureStripeCustomer", { enumerable: true, get: function () { return stripe_1.ensureStripeCustomer; } });
Object.defineProperty(exports, "createSubscriptionElements", { enumerable: true, get: function () { return stripe_1.createSubscriptionElements; } });
Object.defineProperty(exports, "createSetupIntentForCustomer", { enumerable: true, get: function () { return stripe_1.createSetupIntentForCustomer; } });
Object.defineProperty(exports, "createEmbeddedCheckoutSession", { enumerable: true, get: function () { return stripe_1.createEmbeddedCheckoutSession; } });
Object.defineProperty(exports, "getCheckoutSessionStatus", { enumerable: true, get: function () { return stripe_1.getCheckoutSessionStatus; } });
// Expose both callable and HTTP publishable-key endpoints
Object.defineProperty(exports, "getStripePublishableKey", { enumerable: true, get: function () { return stripe_1.getStripePublishableKey; } });
Object.defineProperty(exports, "getStripePublishableKeyHttp", { enumerable: true, get: function () { return stripe_1.getStripePublishableKeyHttp; } });
Object.defineProperty(exports, "updateSubscriptionQuantity", { enumerable: true, get: function () { return stripe_1.updateSubscriptionQuantity; } });
Object.defineProperty(exports, "cancelSubscriptionElements", { enumerable: true, get: function () { return stripe_1.cancelSubscription; } });
Object.defineProperty(exports, "createBillingPortalSessionElements", { enumerable: true, get: function () { return stripe_1.createBillingPortalSession; } });
Object.defineProperty(exports, "getSubscriptionData", { enumerable: true, get: function () { return stripe_1.getSubscriptionData; } });
Object.defineProperty(exports, "validateCoupon", { enumerable: true, get: function () { return stripe_1.validateCoupon; } });
Object.defineProperty(exports, "backfillSubscriptionQuantityForOrg", { enumerable: true, get: function () { return stripe_1.backfillSubscriptionQuantityForOrg; } });
