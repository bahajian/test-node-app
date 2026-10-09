const express = require("express");
const app = express();

// --- Config (from ConfigMap: test-node-config) ---
const GREETING = process.env.GREETING || "hello";
const LOG_LEVEL = process.env.LOG_LEVEL || "info";

// --- Secrets (from Secret: test-node-secret, synced from Vault by ESO) ---
const API_KEY = process.env.API_KEY || null;
const DB_PASSWORD = process.env.DB_PASSWORD || null;

app.get("/", (req, res) => {
  res.json({
    app: "test-node-app",
    pod: process.env.HOSTNAME,
    image: "nexus.ibstorm.com/test-node-app",
    config: { GREETING, LOG_LEVEL },          // from ConfigMap
    secretsLoaded: Boolean(API_KEY && DB_PASSWORD),
    // previews only, to prove the wiring without dumping full secrets:
    apiKeyPreview: API_KEY ? API_KEY.slice(0, 3) + "***" : null,
    dbPasswordLen: DB_PASSWORD ? DB_PASSWORD.length : 0,
  });
});

app.get("/healthz", (req, res) => res.json({ status: "ok" }));

const port = process.env.PORT || 8080;
app.listen(port, () =>
  console.log(`test-node-app listening on :${port} (level=${LOG_LEVEL})`)
);
