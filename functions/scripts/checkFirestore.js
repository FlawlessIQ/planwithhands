const {execFileSync} = require("child_process");

// Allow overriding project via env var or CLI arg; default to the original project id
const PROJECT = process.env.FIREBASE_PROJECT || process.argv[2] || "plan-with-hands";

function runFirebaseList(useJson = true) {
  const args = ["firestore:databases:list", "--project", PROJECT];
  if (useJson) args.push("--format=json");
  try {
    return execFileSync("firebase", args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (err) {
    // bubble up error to caller with details
    const stderr = err.stderr ? err.stderr.toString() : "";
    const stdout = err.stdout ? err.stdout.toString() : "";
    const message = (stderr || stdout || err.message || String(err)).toString();
    const e = new Error(message);
    e._orig = err;
    throw e;
  }
}

function parseJsonOutput(output) {
  try {
    const json = JSON.parse(output);
    return Array.isArray(json) ? json : json.databases || [];
  } catch (err) {
    return null;
  }
}

function parseTextOutputForDefault(output) {
  // Look for a line containing projects/<project>/databases/(default)
  const needle = `projects/${PROJECT}/databases/(default)`;
  const lines = output.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  for (const line of lines) {
    if (line.includes(needle)) {
      return true; // treat as present (assume native for older CLI output)
    }
  }
  return false;
}

function validateJsonList(list) {
  if (!list || list.length === 0) return false;
  const found = list.find((d) => {
    const name = (d.name || d.database || "").toString();
    return name.endsWith("/databases/(default)") || name.endsWith("/(default)");
  });
  if (!found) return false;
  const type = (found.type || found.databaseMode || "").toString();
  return type === "FIRESTORE_NATIVE" || type === "FIRESTORE_NATIVE_MODE" || type.toUpperCase().includes("NATIVE");
}

function main() {
  // First try JSON output (preferred)
  try {
    const out = runFirebaseList(true);
    const list = parseJsonOutput(out);
    if (list === null) {
      console.error("Failed to parse JSON output from Firebase CLI.");
      process.exit(1);
    }
    if (validateJsonList(list)) {
      console.log("✅ Firestore default database detected — proceeding with deploy");
      process.exit(0);
    }
    // If JSON present but no native default, fail with clear message
    console.error("❌ No Firestore Native default database detected — deploy aborted");
    console.error("Detected JSON output (truncated):", JSON.stringify(list).slice(0, 400));
    process.exit(1);
  } catch (err) {
    const msg = err.message || String(err);
    // Detect case where the Firebase CLI doesn't support --format=json for this command
    if (/unknown option|unknown flag|unrecognized option/i.test(msg)) {
      console.warn("Firebase CLI does not support --format=json for this command on this version; falling back to text parsing.");
      try {
        const out = runFirebaseList(false);
        const ok = parseTextOutputForDefault(out.toString());
        if (ok) {
          console.log("✅ Firestore default database detected — proceeding with deploy");
          process.exit(0);
        }
        console.error("❌ No Firestore default database detected — deploy aborted");
        console.error("Detected CLI output (truncated):", out.toString().slice(0, 400));
        process.exit(1);
      } catch (err2) {
        console.error("Failed to run fallback CLI command:", err2.message || String(err2));
        process.exit(1);
      }
    }

    console.error("Failed to run `firebase firestore:databases:list`: ", msg);
    process.exit(1);
  }
}

main();
