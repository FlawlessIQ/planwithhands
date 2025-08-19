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
exports.repairTaskTitlesFromCsv = exports.repairTemplateTaskTitles = exports.migrateChecklistTemplates = exports.syncTodayOnShiftChange = exports.syncTodayOnTemplateChange = void 0;
const admin = __importStar(require("firebase-admin"));
// Ensure admin is initialized (idempotent)
admin.initializeApp();
// Re-export the JS function implementation under a TypeScript entrypoint name.
// This allows us to have a TS entry while keeping the existing JS implementation.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const syncModule = require('./syncTodayOnTemplateChange');
exports.syncTodayOnTemplateChange = syncModule.syncTodayOnTemplateChange;
// eslint-disable-next-line @typescript-eslint/no-var-requires
const syncShiftModule = require('./syncTodayOnShiftChange');
exports.syncTodayOnShiftChange = syncShiftModule.syncTodayOnShiftChange;
// eslint-disable-next-line @typescript-eslint/no-var-requires
const migrateModule = require('../migrations/migrate_checklist_templates_to_subcollections');
exports.migrateChecklistTemplates = migrateModule.migrateChecklistTemplates;
// eslint-disable-next-line @typescript-eslint/no-var-requires
const repairModule = require('../migrations/repair_template_task_titles');
exports.repairTemplateTaskTitles = repairModule.repairTemplateTaskTitles;
// eslint-disable-next-line @typescript-eslint/no-var-requires
const repairCsvModule = require('../migrations/repair_task_titles_from_csv');
exports.repairTaskTitlesFromCsv = repairCsvModule.repairTaskTitlesFromCsv;
