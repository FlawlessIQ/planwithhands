const fs = require("fs");
const path = require("path");

// Simple repo scan for string patterns that indicate expiresAt being written to permanent collections
const repoRoot = path.resolve(__dirname, "..", "..");
const permCollections = ["users", "locations", "checklist_templates", "shifts", "jobTypes", "training_", "subscriptions"];

function walk(dir, cb) {
  const files = fs.readdirSync(dir);
  for (const f of files) {
    const full = path.join(dir, f);
    const stat = fs.statSync(full);
    if (stat.isDirectory()) {
      walk(full, cb);
    } else {
      cb(full);
    }
  }
}

const violations = [];
walk(repoRoot, (file) => {
  if (!file.endsWith(".dart") && !file.endsWith(".ts") && !file.endsWith(".js")) return;
  if (file.includes("node_modules")) return;
  const txt = fs.readFileSync(file, "utf8");
  for (const col of permCollections) {
    const pattern = new RegExp(`${col}.*\\{[^}]*expiresAt`, "s");
    if (pattern.test(txt)) {
      violations.push({file, col});
    }
  }
});

if (violations.length > 0) {
  console.error("Found potential expiresAt writes into permanent collections:");
  for (const v of violations) {
    console.error(` - ${v.file} (collection match: ${v.col})`);
  }
  process.exit(1);
}
console.log("No obvious permanent-collection expiresAt writes found.");
