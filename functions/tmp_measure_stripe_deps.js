const fs = require("fs");
const logPath = "/tmp/stripe-deps-load-progress.log";
const startedAt = Date.now();

const modules = [
  "firebase-functions",
  "./firebase_config",
  "@sendgrid/mail",
  "./stripe_functions",
];

fs.writeFileSync(logPath, "");

function writeLog(payload) {
  fs.appendFileSync(logPath, `${JSON.stringify(payload)}\n`);
}

const timeout = setTimeout(() => {
  const payload = {timeout: true, elapsedMs: Date.now() - startedAt};
  writeLog(payload);
  console.error(JSON.stringify(payload, null, 2));
  process.exit(1);
}, 20000);

for (const modulePath of modules) {
  writeLog({module: modulePath, phase: "before", totalElapsedMs: Date.now() - startedAt});
  const moduleStart = Date.now();
  try {
    require(modulePath);
    const payload = {
      module: modulePath,
      phase: "after",
      elapsedMs: Date.now() - moduleStart,
      totalElapsedMs: Date.now() - startedAt,
    };
    writeLog(payload);
    console.log(JSON.stringify(payload, null, 2));
  } catch (error) {
    const payload = {
      module: modulePath,
      phase: "error",
      elapsedMs: Date.now() - moduleStart,
      totalElapsedMs: Date.now() - startedAt,
      error: error.stack || error.message,
    };
    writeLog(payload);
    console.error(JSON.stringify(payload, null, 2));
    clearTimeout(timeout);
    process.exit(1);
  }
}

clearTimeout(timeout);