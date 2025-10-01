import * as functions from 'firebase-functions';
const sgMail = require('@sendgrid/mail');

/**
 * Simple HTTP endpoint to send a test SendGrid email using the daily summary template.
 * Accepts POST JSON: { email: string, orgId?: string }
 */
export const manualTestEmail = functions.https.onRequest(async (req, res) => {
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

    // Read SendGrid API key from functions config
    const sendgridConfig = functions.config().sendgrid || {};
    const apiKey = sendgridConfig.key || sendgridConfig.api_key;
    if (!apiKey) {
      functions.logger.warn('SendGrid API key not configured - cannot send test email');
      res.status(500).json({ error: 'SendGrid API key not configured' });
      return;
    }

    sgMail.setApiKey(apiKey);

    const templateId = 'd-b24a7a9c340046d3a5429f203c19470e';

    // Match final template: lowercase keys and HTML sections
    const templateData = {
      organization_name: orgId || 'Test Organization',
      formatted_date: new Date().toDateString(),
      performance_emoji: '✅',
      performance_message: 'This is a test email from Plan With Hands.',
      overall_percentage: '100',
      completed_tasks: '0',
      total_tasks: '0',
      // Sections expected in the template (safe defaults)
      overall_delta_html: '<span style="color:#8cf68c;font-weight:700;">+0% vs yesterday</span>',
      key_metrics_html: '<table width="100%" style="border-collapse:collapse;color:#ffffff;font-size:13px;"><tr><td style="padding:6px 0;">No additional metrics in test.</td></tr></table>',
      missed_tasks_html: '<div style="color:#9b9b9b;">No missed tasks in this test email.</div>',
      photo_compliance_html: '<div style="color:#9b9b9b;">No photo compliance issues in this test.</div>',
      staff_notes_html: '<div style="color:#9b9b9b;">No staff notes recorded in this test.</div>',
      action_items: 'Keep up the great work! Review dashboard for full details.',
    };

    const msg = {
      to: email,
      from: 'noreply@planwithhands.com',
      templateId,
      dynamicTemplateData: templateData,
      categories: ['manual_test_email']
    };

    await sgMail.send(msg);
    functions.logger.info(`manualTestEmail: sent test email to ${email}`);
    res.json({ success: true, message: 'Test email sent', to: email });
  } catch (error: any) {
    const msg = error?.message || String(error);
    functions.logger.error('manualTestEmail error:', msg);
    res.status(500).json({ error: msg });
  }
});
