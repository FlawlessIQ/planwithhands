const functions = require("firebase-functions");

// Uses Node 20 global fetch
const GOOGLE_PLACES_ROOT = "https://places.googleapis.com/v1";

function getApiKey() {
  const key = functions.config().google && functions.config().google.places_api_key;
  if (!key) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Missing Google Places API key. Set functions config google.places_api_key"
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
