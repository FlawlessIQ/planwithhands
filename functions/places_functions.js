const functions = require("firebase-functions");
const admin = require("firebase-admin");
const sgMail = require('@sendgrid/mail');

// Initialize SendGrid - use same approach as working user functions
let sendgridApiKey;
try {
  sendgridApiKey = process.env.SENDGRID_API_KEY || process.env.SENDGRID_KEY;
  if (!sendgridApiKey) {
    console.warn("SendGrid API key is not configured. Email sending will be skipped.");
  } else {
    sgMail.setApiKey(sendgridApiKey);
    console.info("SendGrid API key configured successfully");
  }
} catch (error) {
  console.warn("Error configuring SendGrid:", error.message);
}

// Uses Node 20 global fetch
const GOOGLE_PLACES_ROOT = "https://places.googleapis.com/v1";

function getApiKey() {
  const key = process.env.GOOGLE_PLACES_API_KEY || process.env.PLACES_API_KEY;
  if (!key) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Missing Google Places API key. Set GOOGLE_PLACES_API_KEY"
    );
  }
  return key;
}

exports.placesAutocomplete = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    const { input, sessionToken, languageCode, regionCode } = data || {};
    if (!input || typeof input !== "string") {
      throw new functions.https.HttpsError("invalid-argument", "'input' is required");
    }
    const apiKey = getApiKey();
    const url = `${GOOGLE_PLACES_ROOT}/places:autocomplete`;
    const headers = {
      "Content-Type": "application/json; charset=utf-8",
      "X-Goog-Api-Key": apiKey,
      "X-Goog-FieldMask":
        "suggestions.placePrediction.placeId,suggestions.placePrediction.place,suggestions.placePrediction.text",
    };
    if (sessionToken) headers["X-Goog-Maps-Session-Token"] = sessionToken;
    const body = {
      input,
      ...(sessionToken ? { sessionToken } : {}),
      ...(languageCode ? { languageCode } : {}),
      ...(regionCode ? { regionCode } : {}),
    };
    const resp = await fetch(url, { method: "POST", headers, body: JSON.stringify(body) });
    const text = await resp.text();
    if (!resp.ok) {
      throw new functions.https.HttpsError("internal", `Places autocomplete error ${resp.status}: ${text}`);
    }
    try {
      return JSON.parse(text);
    } catch (e) {
      return { raw: text };
    }
  });

exports.placeDetails = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    const { placeId, sessionToken, languageCode, regionCode } = data || {};
    if (!placeId || typeof placeId !== "string") {
      throw new functions.https.HttpsError("invalid-argument", "'placeId' is required");
    }
    const apiKey = getApiKey();
    const resourceName = placeId.startsWith("places/") ? placeId : `places/${placeId}`;
    const url = new URL(`${GOOGLE_PLACES_ROOT}/${resourceName}`);
    if (languageCode) url.searchParams.set("languageCode", languageCode);
    if (regionCode) url.searchParams.set("regionCode", regionCode);
    const headers = {
      "X-Goog-Api-Key": apiKey,
      "X-Goog-FieldMask": "id,displayName,formattedAddress,location,addressComponents",
    };
    if (sessionToken) headers["X-Goog-Maps-Session-Token"] = sessionToken;
    const resp = await fetch(url, { headers });
    const text = await resp.text();
    if (!resp.ok) {
      throw new functions.https.HttpsError("internal", `Places details error ${resp.status}: ${text}`);
    }
    try {
      return JSON.parse(text);
    } catch (e) {
      return { raw: text };
    }
  });

// CORS helper
function allowCors(req, res) {
  const origin = req.headers.origin || '*';
  res.set('Access-Control-Allow-Origin', origin);
  // Reflect requested headers to satisfy preflight
  const reqHeaders = req.headers['access-control-request-headers'];
  if (reqHeaders) {
    res.set('Access-Control-Allow-Headers', reqHeaders);
  } else {
    res.set('Access-Control-Allow-Headers', 'Content-Type');
  }
  const reqMethod = req.headers['access-control-request-method'];
  res.set('Access-Control-Allow-Methods', reqMethod || 'POST, OPTIONS');
  res.set('Access-Control-Max-Age', '3600');
  res.set('Vary', 'Origin, Access-Control-Request-Headers, Access-Control-Request-Method');
}

// HTTP proxy variant with explicit CORS for web fallbacks
exports.placesAutocompleteHttp = functions
  .region('us-central1')
  .https.onRequest(async (req, res) => {
    allowCors(req, res);
    if (req.method === 'OPTIONS') {
      // End preflight
      return res.status(204).send('');
    }
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method Not Allowed' });
    }
    
    // Check if this is a help request
    if (req.body && req.body.requestType === 'help') {
      try {
        const {email, subject, message} = req.body;

        if (!email || !subject || !message) {
          return res.status(400).json({ error: "Missing required fields" });
        }

        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
          return res.status(400).json({ error: "Invalid email format" });
        }

        if (message.trim().length < 10) {
          return res.status(400).json({ error: "Message too short" });
        }

        const db = admin.firestore();
        const helpRequestRef = await db.collection("help_requests").add({
          email: email.trim(),
          subject: subject.trim(),
          message: message.trim(),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          status: "new",
          source: "app_help_form",
        });
        // Try to send email if SendGrid is configured
        if (sendgridApiKey && sgMail) {
          try {
            const emailData = {
              to: 'conor@planwithhands.com', // Switch to main domain email
              from: 'noreply@em5998.planwithhands.com', // Using verified SendGrid domain like user functions
              subject: `Help Request: ${subject}`,
              html: `<h3>New Help Request</h3><p><strong>From:</strong> ${email}</p><p><strong>Subject:</strong> ${subject}</p><p><strong>Message:</strong></p><p>${message.replace(/\n/g, '<br>')}</p><p><strong>Request ID:</strong> ${helpRequestRef.id}</p><p><strong>Timestamp:</strong> ${new Date().toISOString()}</p>`,
            };
            console.log('Attempting to send email with SendGrid...');
            await sgMail.send(emailData);
            console.log('Email sent successfully to support@planwithhands.com');
          } catch (emailError) {
            console.error("Email failed:", emailError);
            console.error("SendGrid error details:", emailError.response?.body || 'No additional details');
            // Still return success since the request was saved to Firestore
            console.log('Help request saved to Firestore despite email failure');
          }
        } else {
          console.warn("SendGrid not properly configured - email not sent, but help request saved to Firestore");
        }
        
        return res.status(200).json({
          success: true,
          message: "Help request submitted successfully!",
          requestId: helpRequestRef.id,
        });
      } catch (error) {
        console.error("Help request error:", error);
        return res.status(500).json({ error: "Internal server error" });
      }
    }
    
    // Original places logic
    try {
      const { input, sessionToken, languageCode, regionCode } = req.body || {};
      if (!input || typeof input !== 'string') {
        return res.status(400).json({ error: "'input' is required" });
      }
      const apiKey = getApiKey();
      const url = `${GOOGLE_PLACES_ROOT}/places:autocomplete`;
      const headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
          'suggestions.placePrediction.placeId,suggestions.placePrediction.place,suggestions.placePrediction.text',
      };
      if (sessionToken) headers['X-Goog-Maps-Session-Token'] = sessionToken;
      const body = {
        input,
        ...(sessionToken ? { sessionToken } : {}),
        ...(languageCode ? { languageCode } : {}),
        ...(regionCode ? { regionCode } : {}),
      };
      const resp = await fetch(url, { method: 'POST', headers, body: JSON.stringify(body) });
      const text = await resp.text();
      if (!resp.ok) {
        return res.status(resp.status).json({ error: `Places autocomplete error ${resp.status}: ${text}` });
      }
      try {
        return res.status(200).json(JSON.parse(text));
      } catch (e) {
        return res.status(200).json({ raw: text });
      }
    } catch (e) {
      return res.status(500).json({ error: (e && e.message) || String(e) });
    }
  });

exports.placeDetailsHttp = functions
  .region('us-central1')
  .https.onRequest(async (req, res) => {
    allowCors(req, res);
    if (req.method === 'OPTIONS') {
      // End preflight
      return res.status(204).send('');
    }
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method Not Allowed' });
    }
    try {
      const { placeId, sessionToken, languageCode, regionCode } = req.body || {};
      if (!placeId || typeof placeId !== 'string') {
        return res.status(400).json({ error: "'placeId' is required" });
      }
      const apiKey = getApiKey();
      const resourceName = placeId.startsWith('places/') ? placeId : `places/${placeId}`;
      const url = new URL(`${GOOGLE_PLACES_ROOT}/${resourceName}`);
      if (languageCode) url.searchParams.set('languageCode', languageCode);
      if (regionCode) url.searchParams.set('regionCode', regionCode);
      const headers = {
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'id,displayName,formattedAddress,location,addressComponents',
      };
      if (sessionToken) headers['X-Goog-Maps-Session-Token'] = sessionToken;
      const resp = await fetch(url, { headers });
      const text = await resp.text();
      if (!resp.ok) {
        return res.status(resp.status).json({ error: `Places details error ${resp.status}: ${text}` });
      }
      try {
        return res.status(200).json(JSON.parse(text));
      } catch (e) {
        return res.status(200).json({ raw: text });
      }
    } catch (e) {
      return res.status(500).json({ error: (e && e.message) || String(e) });
    }
  });

// Removed duplicate sendHelpRequest - using the one from help_functions.js instead
