const functions = require("firebase-functions");
const {logger} = require("firebase-functions");
const {admin, db} = require("./firebase_config");
const sgMail = require('@sendgrid/mail');

function getSendGridApiKey() {
  return process.env.SENDGRID_API_KEY || process.env.SENDGRID_KEY;
}

function normalizePreferredLanguageCode(value) {
  const normalized = String(value || '').trim().toLowerCase().replace(/_/g, '-');
  if (normalized.startsWith('es')) return 'es';
  if (normalized.startsWith('pt')) return 'pt';
  return 'en';
}

function getHelpCopy(preferredLanguageCode) {
  const languageCode = normalizePreferredLanguageCode(preferredLanguageCode);
  if (languageCode === 'es') {
    return {
      missingFields: 'Faltan campos obligatorios: correo electrónico, asunto o mensaje',
      invalidEmail: 'Formato de correo electrónico inválido',
      messageTooShort: 'El mensaje debe tener al menos 10 caracteres',
      success:
        '¡Solicitud enviada con éxito! Te responderemos dentro de 24 horas.',
      failed:
        'No se pudo enviar la solicitud de ayuda. Inténtalo de nuevo.',
      methodNotAllowed: 'Método no permitido',
    };
  }
  if (languageCode === 'pt') {
    return {
      missingFields: 'Faltam campos obrigatórios: e-mail, assunto ou mensagem',
      invalidEmail: 'Formato de e-mail inválido',
      messageTooShort: 'A mensagem deve ter pelo menos 10 caracteres',
      success:
        'Solicitação enviada com sucesso! Responderemos em até 24 horas.',
      failed:
        'Não foi possível enviar a solicitação de ajuda. Tente novamente.',
      methodNotAllowed: 'Método não permitido',
    };
  }

  return {
    missingFields: 'Missing required fields: email, subject, or message',
    invalidEmail: 'Invalid email format',
    messageTooShort: 'Message must be at least 10 characters long',
    success:
      "Help request submitted successfully. We'll get back to you within 24 hours.",
    failed: 'Failed to submit help request. Please try again.',
    methodNotAllowed: 'Method not allowed',
  };
}

// Initialize SendGrid with API key from env (Firebase CLI dotenv support)
const sendgridApiKey = getSendGridApiKey();
if (sendgridApiKey) {
  sgMail.setApiKey(sendgridApiKey);
} else {
  logger.warn("SendGrid API key not configured (SENDGRID_API_KEY)");
}

/**
 * Send help request email to support team
 */
exports.sendHelpRequest = functions.https.onRequest(async (req, res) => {
  // Robust CORS handling
  const origin = req.get('origin') || '*';
  const reqHeaders = req.get('Access-Control-Request-Headers');
  res.set('Vary', 'Origin');
  res.set('Access-Control-Allow-Origin', origin);
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', reqHeaders || 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  const preferredLanguageCode = normalizePreferredLanguageCode(
    req.body?.preferredLanguageCode,
  );
  const copy = getHelpCopy(preferredLanguageCode);

  if (req.method !== 'POST') {
    res.status(405).json({ error: copy.methodNotAllowed });
    return;
  }

  const {email, subject, message, userId, userRole, organizationId} = req.body;

  // Validate input
  if (!email || !subject || !message) {
    res.status(400).json({ error: copy.missingFields });
    return;
  }

  // Validate email format
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    res.status(400).json({ error: copy.invalidEmail });
    return;
  }

  // Validate message length
  if (message.trim().length < 10) {
    res.status(400).json({ error: copy.messageTooShort });
    return;
  }

  try {
    // Get user info - simplified for HTTP function
    let userInfo = {
      userId: userId || "anonymous",
      userEmail: email,
      userRole: userRole ?? "unknown",
      organizationId: organizationId || "unknown",
    };

    // Store help request in Firestore
    const helpRequestData = {
      email: email.trim(),
      subject: subject.trim(),
      message: message.trim(),
      userInfo,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: "new",
      source: "app_help_form",
      preferredLanguageCode,
    };

    const helpRequestRef = await db.collection("help_requests").add(helpRequestData);
    logger.info(`Help request created: ${helpRequestRef.id}`, helpRequestData);

    // Send email via SendGrid
    if (sendgridApiKey) {
      try {
        const supportEmail = {
          to: 'conor@planwithhands.com',
          from: process.env.SENDGRID_FROM_EMAIL || 'noreply@planwithhands.com',
          subject: `Help Request: ${subject}`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #FF6B35;">New Help Request</h2>
              <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
                <p><strong>From:</strong> ${email}</p>
                <p><strong>User ID:</strong> ${userInfo.userId}</p>
                <p><strong>Organization:</strong> ${userInfo.organizationId}</p>
                <p><strong>User Role:</strong> ${userInfo.userRole}</p>
                <p><strong>Request ID:</strong> ${helpRequestRef.id}</p>
              </div>
              <h3>Subject:</h3>
              <p>${subject}</p>
              <h3>Message:</h3>
              <div style="background: white; padding: 15px; border-left: 4px solid #FF6B35; margin: 10px 0;">
                ${message.replace(/\n/g, '<br>')}
              </div>
              <hr style="margin: 30px 0; border: none; border-top: 1px solid #ddd;">
              <p style="color: #666; font-size: 12px;">
                This email was sent from the Hands app help system.<br>
                Timestamp: ${new Date().toISOString()}
              </p>
            </div>
          `,
        };
        
        await sgMail.send(supportEmail);
        logger.info(`Email sent successfully for help request: ${helpRequestRef.id}`);
      } catch (emailError) {
        logger.error("Failed to send email notification:", emailError);
        // Don't fail the whole request if email fails - the request is still stored
      }
    }

    res.status(200).json({
      success: true,
      message: copy.success,
      requestId: helpRequestRef.id,
    });
  } catch (error) {
    logger.error("Error processing help request:", error);
    res.status(500).json({ error: copy.failed });
  }
});
