/* eslint-disable @typescript-eslint/no-require-imports */
import * as admin from "firebase-admin";

// Ensure admin is initialized (idempotent)
admin.initializeApp();

// Re-export the JS function implementation under a TypeScript entrypoint name.
// This allows us to have a TS entry while keeping the existing JS implementation.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const syncModule = require("./syncTodayOnTemplateChange");

export const syncTodayOnTemplateChange = syncModule.syncTodayOnTemplateChange as any;

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
