// API route to send contact form messages via SendGrid HTTP API
// Expects JSON POST: { name, email, subject, message }
// Environment variables (website/marketing/.env.local):
// SENDGRID_API_KEY - required for real sending
// SENDGRID_FROM - optional (default no-reply@planwithhands.com)
// SENDGRID_TO - optional (default support@planwithhands.com)
// DEV_FAKE_SEND - if set to '1' or 'true' and no SENDGRID_API_KEY present, the payload will be logged and the endpoint will return success (useful for local dev)

const RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute
const MAX_PER_WINDOW = 6; // allow up to 6 submissions per window per IP
const ipCounters = new Map(); // simple in-memory rate limiter (resets with server restart)

function getIp(req) {
  const xff = req.headers['x-forwarded-for'];
  if (xff) return Array.isArray(xff) ? xff[0] : String(xff).split(',')[0].trim();
  return (req.socket && req.socket.remoteAddress) || 'unknown';
}

function isDevFake() {
  const v = process.env.DEV_FAKE_SEND || '';
  return v === '1' || v.toLowerCase() === 'true';
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', ['POST']);
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const ip = getIp(req);
  const now = Date.now();
  const entry = ipCounters.get(ip) || { count: 0, windowStart: now };
  if (now - entry.windowStart > RATE_LIMIT_WINDOW) {
    entry.count = 0;
    entry.windowStart = now;
  }
  entry.count += 1;
  ipCounters.set(ip, entry);
  if (entry.count > MAX_PER_WINDOW) {
    return res.status(429).json({ error: 'Too many requests. Please try again later.' });
  }

  const raw = req.body || {};
  const name = (raw.name || '').toString().trim().slice(0, 200);
  const email = (raw.email || '').toString().trim().slice(0, 254);
  const subject = (raw.subject || '').toString().trim().slice(0, 200);
  const message = (raw.message || '').toString().trim().slice(0, 8000);

  if (!email || !subject || !message) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  // simple email regex
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: 'Invalid email address' });
  }

  // Forward to the same cloud function used by the Flutter app so behavior/config is identical.
  // The Flutter HelpPage posts to: https://us-central1-plan-with-hands.cloudfunctions.net/placesAutocompleteHttp
  // We'll include the same fields and prefix the message with a marketing-site note.
  const CLOUD_FUNCTION_URL = process.env.CLOUD_FUNCTION_URL || 'https://us-central1-plan-with-hands.cloudfunctions.net/placesAutocompleteHttp';

  const augmentedMessage = ['[Marketing site — Info question] This message originated from the marketing site and is NOT an in-app support request.', '', message, '', `Received at: ${new Date().toISOString()}`, `Sender IP: ${ip}`].join('\n');

  const payload = {
    requestType: 'help',
    email,
    subject,
    message: augmentedMessage,
  };

  // Dev fallback: if CLOUD_FUNCTION_URL is not reachable and DEV_FAKE_SEND is set, log and return success
  if (!CLOUD_FUNCTION_URL) {
    if (isDevFake()) {
      console.info('[contact API] DEV_FAKE_SEND enabled — logging payload instead of forwarding.');
      console.info(JSON.stringify(payload, null, 2));
      return res.status(200).json({ message: 'Message recorded (dev fake send)' });
    }
    return res.status(500).json({ error: 'No cloud function configured' });
  }

  try {
    const resp = await fetch(CLOUD_FUNCTION_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    const text = await resp.text();
    // Try to parse JSON if present
    let jsonBody = null;
    try { jsonBody = JSON.parse(text); } catch (_) { /* not JSON */ }

    if (!resp.ok) {
      console.error('[contact API] Cloud function error:', resp.status, text);
      return res.status(502).json({ error: jsonBody?.error || 'Failed to forward message to cloud function' });
    }

    // If the cloud function returned a JSON message, surface it; otherwise return generic success
    return res.status(200).json({ message: jsonBody?.message || 'Message forwarded to cloud function' });
  } catch (err) {
    console.error('[contact API] Error forwarding to cloud function', err);
    if (isDevFake()) {
      console.info('[contact API] DEV_FAKE_SEND fallback — logging payload');
      console.info(JSON.stringify(payload, null, 2));
      return res.status(200).json({ message: 'Message recorded (dev fake send)' });
    }
    return res.status(500).json({ error: 'Internal server error' });
  }
}
