const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
// lightweight CSV parser (handles simple CSV with header row)
function parseCsvSimple(text) {
  const lines = text.split(/\r?\n/).filter((l) => l.trim() !== "");
  if (lines.length === 0) return [];
  const headers = lines[0].split(",").map((h) => h.trim());
  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    const cols = lines[i].split(",");
    const row = {};
    for (let j = 0; j < headers.length; j++) {
      row[headers[j]] = cols[j] !== undefined ? cols[j].trim() : "";
    }
    rows.push(row);
  }
  return rows;
}

if (!admin.apps.length) admin.initializeApp();
const DB_ID = process.env.FIRESTORE_DB_ID || "(default)";
const db = getFirestore(admin.app(), DB_ID);

exports.repairTaskTitlesFromCsv = functions.https.onRequest(async (req, res) => {
  try {
    const dryRun = (req.query.dryRun || "true") === "true";
    let body = req.body;
    // If Content-Type text/csv, raw body will be the CSV
    if (!body || typeof body === "object") {
      // try reading raw body
      body = req.rawBody ? req.rawBody.toString("utf8") : "";
    }
    if (!body) return res.status(400).json({error: "No CSV body provided"});

    const records = parseCsvSimple(body);

    let rowsRead = 0;
    let rowsEligible = 0;
    let tasksPatched = 0;
    const errors = [];

    for (const r of records) {
      rowsRead++;
      const orgId = r.orgId || r.orgid || r.org || r.organizationId;
      const templateId = r.templateId || r.templateid || r.template || r.templateID;
      const order = r.order !== undefined ? parseInt(r.order, 10) : null;
      const title = r.title || r.TITLE || r.Title;
      if (!orgId || !templateId || order === null || !title) {
        errors.push({row: r, error: "missing fields"});
        continue;
      }
      try {
        const tasksRef = db.collection(`organizations/${orgId}/checklist_templates/${templateId}/tasks`);
        const q = tasksRef.where("order", "==", order).limit(1);
        const snap = await q.get();
        if (snap.empty) {
          errors.push({row: r, error: "task not found"});
          continue;
        }
        const doc = snap.docs[0];
        const cur = doc.data();
        if (!cur || !cur.title || !/^Task\s+\d+$/i.test(cur.title)) {
          // not eligible
          continue;
        }
        rowsEligible++;
        if (!dryRun) {
          await doc.ref.update({title, updatedAt: FieldValue.serverTimestamp()});
          tasksPatched++;
        }
      } catch (e) {
        errors.push({row: r, error: String(e)});
      }
    }

    res.json({rowsRead, rowsEligible, tasksPatched, errors});
  } catch (err) {
    console.error(err);
    res.status(500).json({error: String(err)});
  }
});
