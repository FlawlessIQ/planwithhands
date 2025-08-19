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
