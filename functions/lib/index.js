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
exports.scheduledDailyGenerator = exports.onDailySummaryNotificationCreated = exports.onGeneralNotificationCreated = exports.sendMessageNotification = exports.onMessageCreated = exports.proxyDownload = exports.proxyUpload = exports.getSignedUploadUrl = exports.placeDetailsHttp = exports.placesAutocompleteHttp = exports.createBillingPortalSession = exports.updateSubscription = exports.cancelSubscription = exports.stripeWebhook = exports.createCheckoutSession = exports.deleteUser = exports.createUser = exports.repairTaskTitlesFromCsv = exports.repairTemplateTaskTitles = exports.migrateChecklistTemplates = exports.syncTodayOnShiftChange = exports.syncTodayOnTemplateChange = void 0;
/* eslint-disable @typescript-eslint/no-require-imports */
const admin = __importStar(require("firebase-admin"));
// Ensure admin is initialized (idempotent)
admin.initializeApp();
// Re-export the JS function implementation under a TypeScript entrypoint name.
// This allows us to have a TS entry while keeping the existing JS implementation.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const syncModule = require("./syncTodayOnTemplateChange");
exports.syncTodayOnTemplateChange = syncModule.syncTodayOnTemplateChange;
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
// Export messaging notification functions
var messagingNotifications_1 = require("./messagingNotifications");
Object.defineProperty(exports, "onMessageCreated", { enumerable: true, get: function () { return messagingNotifications_1.onMessageCreated; } });
Object.defineProperty(exports, "sendMessageNotification", { enumerable: true, get: function () { return messagingNotifications_1.sendMessageNotification; } });
var messagingNotifications_2 = require("./messagingNotifications");
Object.defineProperty(exports, "onGeneralNotificationCreated", { enumerable: true, get: function () { return messagingNotifications_2.onGeneralNotificationCreated; } });
Object.defineProperty(exports, "onDailySummaryNotificationCreated", { enumerable: true, get: function () { return messagingNotifications_2.onDailySummaryNotificationCreated; } });
// Export daily generator (scheduled function to create daily checklists)
var dailyGenerator_1 = require("./dailyGenerator");
Object.defineProperty(exports, "scheduledDailyGenerator", { enumerable: true, get: function () { return dailyGenerator_1.scheduledDailyGenerator; } });
