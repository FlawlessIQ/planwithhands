const modules = [
  "./stripe_functions",
  "./user_functions",
  "./places_functions",
  "./help_functions",
  "./test_email_function",
  "./test_manual_email",
  "./index",
];

const fs = require("fs");
const logPath = "/tmp/functions-module-load-progress.log";
const startedAt = Date.now();

fs.writeFileSync(logPath, "");

function writeLog(payload) {
  fs.appendFileSync(logPath, `${JSON.stringify(payload)}\n`);
}

const timeout = setTimeout(() => {
  const payload = {
    timeout: true,
    elapsedMs: Date.now() - startedAt,
  };
  writeLog(payload);
  console.error(JSON.stringify(payload, null, 2));
  process.exit(1);
}, 20000);

for (const modulePath of modules) {
  const moduleStart = Date.now();
  writeLog({module: modulePath, phase: "before", totalElapsedMs: Date.now() - startedAt});
  try {
    require(modulePath);
    const payload = {
      module: modulePath,
      loaded: true,
      elapsedMs: Date.now() - moduleStart,
      totalElapsedMs: Date.now() - startedAt,
      phase: "after",
    };
    writeLog(payload);
    console.log(JSON.stringify(payload, null, 2));
  } catch (error) {
    clearTimeout(timeout);
    const payload = {
      module: modulePath,
      loaded: false,
      elapsedMs: Date.now() - moduleStart,
      totalElapsedMs: Date.now() - startedAt,
      error: error.stack || error.message,
      phase: "error",
    };
    writeLog(payload);
    console.error(JSON.stringify(payload, null, 2));
    process.exit(1);
  }
}

clearTimeout(timeout);