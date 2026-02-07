/**
 * GymSync Presence Backend (Express API)
 * Fixed: Pause, Resume and Stop now work as expected.
 * Status structure: { activity, startTimestamp, paused, pausedElapsed }
 */
require("dotenv").config();
const express = require("express");
const cors = require("cors");

const API_KEY = process.env.API_KEY || "dev-key";
const PORT = process.env.PORT || 3000;

const app = express();
app.use(cors());
app.use(express.json());

/**
 * In-memory store: Map<discord_id, { activity, startTimestamp, paused, pausedElapsed }>
 * - startTimestamp: timestamp when started (Date.now())
 * - paused: boolean
 * - pausedElapsed: accumulated seconds while paused
 */
const statusMap = new Map();

app.get("/", (req, res) => {
  res.send("✅ GymSync Backend is running!");
});

/**
 * POST /api/v1/status
 * Body: { discord_id, status: { activity: string } }
 * Starts a new activity.
 */
app.post("/api/v1/status", (req, res) => {
  const auth = req.headers.authorization || "";
  const token = auth.split(" ")[1];

  if (token !== API_KEY) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  const { discord_id, status } = req.body;

  if (
    !discord_id ||
    !status ||
    typeof status.activity !== "string"
  ) {
    return res.status(400).json({ error: "Invalid payload" });
  }

  statusMap.set(discord_id, {
    activity: status.activity,
    startTimestamp: Date.now(),
    paused: false,
    pausedElapsed: 0,
  });

  res.json({ ok: true });
});

/**
 * POST /api/v1/status/pause
 * Body: { discord_id }
 * Pauses the current activity, accumulating the elapsed time.
 */
app.post("/api/v1/status/pause", (req, res) => {
  const auth = req.headers.authorization || "";
  const token = auth.split(" ")[1];

  if (token !== API_KEY) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  const { discord_id } = req.body;

  if (!discord_id) {
    return res.status(400).json({ error: "discord_id is required" });
  }
  const data = statusMap.get(discord_id);
  if (!data) {
    return res.status(404).json({ error: "Status not found" });
  }
  if (data.paused) {
    return res.status(400).json({ error: "Already paused" });
  }

  const now = Date.now();
  const elapsed = Math.floor((now - data.startTimestamp) / 1000);
  data.pausedElapsed += elapsed;
  data.paused = true;
  data.startTimestamp = null;
  statusMap.set(discord_id, data);

  res.json({ ok: true });
});

/**
 * POST /api/v1/status/resume
 * Body: { discord_id }
 * Resumes the paused activity.
 */
app.post("/api/v1/status/resume", (req, res) => {
  const auth = req.headers.authorization || "";
  const token = auth.split(" ")[1];

  if (token !== API_KEY) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  const { discord_id } = req.body;

  if (!discord_id) {
    return res.status(400).json({ error: "discord_id is required" });
  }
  const data = statusMap.get(discord_id);
  if (!data || !data.paused) {
    return res.status(404).json({ error: "Nothing to resume" });
  }

  data.paused = false;
  data.startTimestamp = Date.now();
  // pausedElapsed remains the same
  statusMap.set(discord_id, data);

  res.json({ ok: true });
});

/**
 * POST /api/v1/status/heartbeat
 * Body: { discord_id }
 * Keeps the session alive without resetting the timer.
 * Returns current elapsed time.
 */
app.post("/api/v1/status/heartbeat", (req, res) => {
  const auth = req.headers.authorization || "";
  const token = auth.split(" ")[1];

  if (token !== API_KEY) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  const { discord_id } = req.body;

  if (!discord_id) {
    return res.status(400).json({ error: "discord_id is required" });
  }

  const data = statusMap.get(discord_id);
  if (!data) {
    return res.status(404).json({ error: "No active session" });
  }

  // Update lastSeen timestamp
  data.lastSeen = Date.now();
  statusMap.set(discord_id, data);

  if (data.paused) {
    return res.json({
      ok: true,
      activity: data.activity,
      time: data.pausedElapsed,
      paused: true
    });
  } else {
    const now = Date.now();
    const elapsed = Math.floor((now - data.startTimestamp) / 1000) + data.pausedElapsed;
    return res.json({
      ok: true,
      activity: data.activity,
      time: elapsed,
      paused: false
    });
  }
});

/**
 * POST /api/v1/status/stop
 * Body: { discord_id }
 * Remove completamente o status (stop).
 */
app.post("/api/v1/status/stop", (req, res) => {
  const auth = req.headers.authorization || "";
  const token = auth.split(" ")[1];

  if (token !== API_KEY) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  const { discord_id } = req.body;

  if (!discord_id) {
    return res.status(400).json({ error: "discord_id is required" });
  }
  statusMap.delete(discord_id);
  res.json({ ok: true });
});

/**
 * GET /api/v1/status/:discord_id
 * Retorna { activity, time, paused } para o Discord ID.
 * - Se paused: retorna tempo total acumulado.
 * - Se ativo: retorna tempo total corrido (pausedElapsed + tempo desde start).
 * - Se não encontrado: 404.
 */
app.get("/api/v1/status/:discord_id", (req, res) => {
  const discord_id = req.params.discord_id;
  const data = statusMap.get(discord_id);
  if (!data) {
    return res.status(404).json({ error: "Not found" });
  }

  if (data.paused) {
    return res.json({
      activity: data.activity,
      time: data.pausedElapsed,
      paused: true
    });
  } else {
    const now = Date.now();
    const elapsed = Math.floor((now - data.startTimestamp) / 1000) + data.pausedElapsed;
    return res.json({
      activity: data.activity,
      time: elapsed,
      paused: false
    });
  }
});

/**
 * GET /success
 * Página simples para OAuth2.
 */
app.get("/success", (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <title>GymSync OAuth2 Success</title>
      <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 40px; }
        h1 { color: #22c55e; }
      </style>
    </head>
    <body>
      <h1>✅ Connected!</h1>
      <p>You can now close this window and return to GymSync.</p>
    </body>
    </html>
  `);
});

// Only start the server if this file is run directly (not imported)
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`✅ GymSync Backend running on http://localhost:${PORT}`);
  });
}

// Export for testing
module.exports = { app, statusMap };
