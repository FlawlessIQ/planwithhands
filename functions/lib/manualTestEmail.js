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
exports.manualTestEmail = void 0;
const functions = __importStar(require("firebase-functions"));
const sgMail = require('@sendgrid/mail');
/**
 * Simple HTTP endpoint to send a test SendGrid email using the daily summary template.
 * Accepts POST JSON: { email: string, orgId?: string }
 */
exports.manualTestEmail = functions.https.onRequest(async (req, res) => {
    try {
        if (req.method !== 'POST') {
            res.status(405).send('Method Not Allowed');
            return;
        }
        const { email, orgId } = req.body || {};
        if (!email) {
            res.status(400).json({ error: 'email is required' });
            return;
        }
        // Read SendGrid API key from env (Firebase CLI dotenv support injects this at deploy/runtime)
        const apiKey = process.env.SENDGRID_API_KEY || process.env.SENDGRID_KEY;
        if (!apiKey) {
            functions.logger.warn('SendGrid API key not configured - cannot send test email');
            res.status(500).json({ error: 'SendGrid API key not configured' });
            return;
        }
        sgMail.setApiKey(apiKey);
        const templateId = 'd-000519b45ca84c0882d31d2cb7965948';
        // Match daily summary template variables used by the app/functions.
        // Note: HTML sections must be injected unescaped in the template via {{{VAR}}}.
        const displayDate = new Date().toDateString();
        const templateData = {
            // Preferred (current) keys used by the template
            ORGANIZATION_NAME: orgId || 'Test Organization',
            FORMATTED_DATE: displayDate,
            PERFORMANCE_EMOJI: '✅',
            PERFORMANCE_MESSAGE: 'This is a test email from Plan With Hands.',
            OVERALL_PERCENTAGE: '100',
            COMPLETED_TASKS: '10',
            TOTAL_TASKS: '10',
            LOCATION_SUMMARY: '<div class="muted" style="margin-top:6px; font-size:12px; font-weight:700; color:rgba(255,255,255,0.72) !important;">1 location • 1 shift</div>',
            LOCATION_BREAKDOWN: '',
            YESTERDAY_PROGRESS: '',
            INSIGHTS_SECTION: '',
            NOTABLE_ITEMS: '',
            ACTION_ITEMS: '<li>Review today\'s dashboard for details.</li><li>Confirm coverage for the next shift.</li>',
            // Legacy keys (kept for older templates/tests)
            organization_name: orgId || 'Test Organization',
            formatted_date: displayDate,
            performance_emoji: '✅',
            performance_message: 'This is a test email from Plan With Hands.',
            overall_percentage: '100',
            completed_tasks: '10',
            total_tasks: '10',
            action_items: 'Review today\'s dashboard for details.',
        };
        const msg = {
            to: email,
            from: process.env.SENDGRID_FROM_EMAIL || 'noreply@em5998.planwithhands.com',
            templateId,
            dynamicTemplateData: templateData,
            categories: ['manual_test_email']
        };
        await sgMail.send(msg);
        functions.logger.info(`manualTestEmail: sent test email to ${email}`);
        res.json({ success: true, message: 'Test email sent', to: email });
    }
    catch (error) {
        const msg = error?.message || String(error);
        functions.logger.error('manualTestEmail error:', msg);
        res.status(500).json({ error: msg });
    }
});
