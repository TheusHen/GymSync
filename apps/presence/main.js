/**
 * GymSync Presence Desktop Client (Cross-platform: Windows, MacOS, Linux)
 * Uses Electron + discord-rpc + Discord OAuth2
 * Includes detailed logging for debugging purposes
 */

require('dotenv').config();
const clientId = "1391871101734223912";

const { app, BrowserWindow, Tray, Menu, dialog, nativeImage } = require("electron");
const prompt = require('electron-prompt');
const DiscordRPC = require("discord-rpc");
const axios = require("axios");
const path = require("path");
const fs = require("fs");
const AutoLaunch = require('auto-launch');
const os = require("os");

// === Configuration ===
const backendUrl = process.env.BACKEND_URL || "https://gymsync-backend-orcin.vercel.app/api/v1/status";
const redirectUri = process.env.REDIRECT_URI || "https://gymsync-backend-orcin.vercel.app/success";
const logFilePath = path.join(app.getPath("userData"), "gymsync-debug.log");

// === Ensure log file ===
function writeLog(message, isError = false) {
  const ts = new Date().toISOString();
  const prefix = isError ? "[ERR]" : "[INFO]";
  const line = `[${ts}]${prefix} ${message}\n`;

  // Console
  isError ? console.error(line) : console.log(line);

  // File
  try {
    fs.appendFileSync(logFilePath, line, { encoding: "utf8" });
  } catch (err) {
    console.error("Failed to write log file:", err);
  }
}
function log(msg) { writeLog(msg, false); }
function logError(msg) { writeLog(msg, true); }

log("==== GymSync Presence App started ====");
log(`Platform: ${process.platform}, Arch: ${process.arch}, Electron version: ${process.versions.electron}`);
log(`Log file created at: ${logFilePath}`);

// === Customizable RPC title ===
let rpcTitle = "GymSync";

let tray = null;
let mainWindow = null;
let discord_id = null;
let access_token = null;
let rpcLoop = null;
let lastPresence = null;

// Timer fix
let localStartTimestamp = null;
let lastActivity = null;

// === Discord RPC Setup ===
DiscordRPC.register(clientId);
const rpc = new DiscordRPC.Client({ transport: 'ipc' });

const activityImageMap = {
  "running": "running",
  "cycling": "cycling",
  "gym": "gym",
  // add more activities here
};

function getImageKeyForActivity(activity) {
  if (!activity || typeof activity !== "string") return "gymsync_logo";
  const key = activity.toLowerCase();
  for (const [name, imageKey] of Object.entries(activityImageMap)) {
    if (key.includes(name)) return imageKey;
  }
  return "gymsync_logo";
}

// === Auto-launch configuration ===
function getExecutablePath() {
  // For development mode
  if (process.env.NODE_ENV === 'development' || !app.isPackaged) {
    return process.execPath;
  }
  
  // For packaged applications
  const appName = "GymSync Presence";
  let exePath = process.execPath;
  
  if (process.platform === "win32") {
    // Windows: Try multiple possible locations
    const possiblePaths = [
      path.join(process.cwd(), `${appName}.exe`),
      path.join(path.dirname(process.execPath), `${appName}.exe`),
      process.execPath
    ];
    
    for (const testPath of possiblePaths) {
      if (fs.existsSync(testPath)) {
        exePath = testPath;
        break;
      }
    }
  } else if (process.platform === "darwin") {
    // macOS: Should be the app bundle
    if (process.execPath.includes(".app")) {
      exePath = process.execPath;
    } else {
      // Fallback: try to find the .app bundle
      const appPath = process.execPath.split(".app")[0] + ".app";
      if (fs.existsSync(appPath)) {
        exePath = appPath;
      }
    }
  } else if (process.platform === "linux") {
    // Linux: Use the actual executable name
    const possiblePaths = [
      path.join(path.dirname(process.execPath), "gymsync-presence"),
      process.execPath
    ];
    
    for (const testPath of possiblePaths) {
      if (fs.existsSync(testPath)) {
        exePath = testPath;
        break;
      }
    }
  }
  
  log(`Auto-launch executable path: ${exePath}`);
  return exePath;
}

const appLauncher = new AutoLaunch({
  name: "GymSync Presence",
  path: getExecutablePath(),
  isHidden: true,
  args: ["--hidden"],
});

function ensureAutoLaunch() {
  appLauncher.isEnabled().then((isEnabled) => {
    if (!isEnabled) {
      appLauncher.enable()
          .then(() => log("Auto-launch enabled: the app will start with the system."))
          .catch((err) => logError("Error enabling auto-launch: " + err));
    } else {
      log("Auto-launch is already enabled.");
    }
  }).catch((err) => logError("Error checking auto-launch: " + err));
}

function getTrayIconPath() {
  if (process.platform === "darwin") {
    return path.join(__dirname, "assets", "tray-icon-mac.png");
  }
  return path.join(__dirname, "assets", "tray-icon.png");
}

function createTray() {
  try {
    let iconPath = getTrayIconPath();
    let trayIcon = nativeImage.createFromPath(iconPath);

    if (trayIcon.isEmpty()) {
      logError("Tray icon not found at " + iconPath);
      trayIcon = nativeImage.createEmpty();
    } else if (process.platform === "darwin") {
      trayIcon = trayIcon.resize({ width: 18, height: 18 });
      trayIcon.setTemplateImage(true);
    }

    tray = new Tray(trayIcon);
    const trayMenu = Menu.buildFromTemplate([
      {
        label: "Show Window",
        click: () => {
          // Show dock icon on macOS when showing window
          if (process.platform === "darwin" && app.dock) {
            app.dock.show();
          }
          
          if (mainWindow) {
            mainWindow.show();
          } else {
            createOAuthWindow();
          }
        }
      },
      {
        label: "Set RPC Title...",
        click: async () => {
          setCustomRPCTitle();
        }
      },
      { type: "separator" },
      {
        label: "Quit",
        click: () => {
          app.quit();
        }
      }
    ]);
    tray.setToolTip("GymSync Presence");
    tray.setContextMenu(trayMenu);

    if (process.platform === "darwin") {
      tray.on("click", () => {
        // Show dock icon on macOS when showing window
        if (app.dock) {
          app.dock.show();
        }
        
        if (mainWindow) {
          mainWindow.show();
        } else {
          createOAuthWindow();
        }
      });
    }
    log("Tray created successfully.");
  } catch (err) {
    logError("Error creating tray: " + err);
  }
}

// === Startup behavior ===
const shouldStartHidden = process.argv.includes('--hidden') || 
                         process.argv.includes('--startup') ||
                         app.getLoginItemSettings().wasOpenedAsHidden;

app.whenReady().then(() => {
  log("Electron app ready event fired.");
  log(`Should start hidden: ${shouldStartHidden}`);
  
  // Hide dock icon on macOS for background mode
  if (shouldStartHidden && process.platform === "darwin") {
    app.dock.hide();
  }
  
  ensureAutoLaunch();
  createTray();
  
  // Only create OAuth window if not starting hidden
  if (!shouldStartHidden) {
    createOAuthWindow();
  } else {
    log("Starting in background mode - OAuth window not created initially.");
  }
});

// === Prompt for RPC title ===
async function setCustomRPCTitle() {
  const win = mainWindow || BrowserWindow.getFocusedWindow();
  const result = await prompt({
    title: "Set RPC Title",
    label: "Enter a custom RPC title (default: GymSync):",
    value: rpcTitle,
    inputAttrs: { type: "text" },
    type: "input",
    resizable: false,
    width: 400,
    height: 150,
    alwaysOnTop: true,
    parent: win
  }, win);

  if (result !== null && typeof result === "string") {
    rpcTitle = result.trim() || "GymSync";
    log(`RPC Title set to: ${rpcTitle}`);
  }
}

// === OAuth Window ===
function createOAuthWindow() {
  if (mainWindow) {
    mainWindow.show();
    return;
  }

  log("Creating OAuth window...");

  mainWindow = new BrowserWindow({
    width: 600,
    height: 700,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      webSecurity: false,
      sandbox: false,
    },
    show: false,
    title: "GymSync Presence",
  });

  mainWindow.on("close", (event) => {
    if (!app.isQuitting) {
      event.preventDefault();
      mainWindow.hide();
      log("Main window hidden instead of closed.");
    }
  });

  mainWindow.on("closed", () => {
    log("Main window destroyed.");
    mainWindow = null;
  });

  mainWindow.once("ready-to-show", () => {
    mainWindow.show();
    log("OAuth window displayed.");
  });

  const scope = "identify";
  const responseType = "token";
  const oauthUrl = `https://discord.com/api/oauth2/authorize?client_id=${clientId}&redirect_uri=${encodeURIComponent(
      redirectUri
  )}&response_type=${responseType}&scope=${scope}`;

  log("Loading OAuth URL: " + oauthUrl);
  mainWindow.loadURL(oauthUrl);

  const wc = mainWindow.webContents;
  const tryHandle = url => handleOAuthRedirect(url);

  wc.on("will-redirect", (e, url) => tryHandle(url));
  wc.on("did-navigate-in-page", (e, url) => tryHandle(url));
  wc.on("will-navigate", (e, url) => tryHandle(url));
  wc.on("did-redirect-navigation", (e, url) => tryHandle(url));
  wc.on("did-fail-load", (e, code, desc, url) => {
    logError(`Failed to load page: ${code} - ${desc} (${url})`);
  });
}

async function handleOAuthRedirect(url) {
  if (!url.startsWith(redirectUri)) return;
  log("OAuth redirect received: " + url);

  const fragment = url.split("#")[1];
  if (!fragment) {
    logError("No token fragment in redirect URL.");
    return;
  }

  const params = new URLSearchParams(fragment);
  access_token = params.get("access_token");
  if (!access_token) {
    logError("Access token not found.");
    return;
  }

  try {
    const user = await axios.get("https://discord.com/api/users/@me", {
      headers: { Authorization: `Bearer ${access_token}` },
    });
    discord_id = user.data.id;
    log(`Authenticated Discord ID: ${discord_id} (${user.data.username}#${user.data.discriminator})`);
    startRPCOnce();
    setTimeout(() => {
      if (mainWindow) mainWindow.hide();
    }, 1500);
  } catch (err) {
    logError("Error getting Discord user data: " + err?.message);
  }
}

function startRPCOnce() {
  if (startRPCOnce.started) return;
  startRPCOnce.started = true;
  rpc.login({ clientId })
      .then(() => {
        log("Discord RPC logged in.");
        startRPC();
      })
      .catch(err => logError("RPC login error: " + err));
}
startRPCOnce.started = false;

function clearPresence() {
  if (lastPresence) {
    rpc.clearActivity().catch(() => {});
    log("Discord presence cleared.");
    lastPresence = null;
  }
  lastActivity = null;
  localStartTimestamp = null;
}

function startRPC() {
  if (rpcLoop) clearInterval(rpcLoop);

  rpcLoop = setInterval(async () => {
    if (!discord_id) return;
    log(`RPC tick - checking backend: ${backendUrl}/${discord_id}`);

    try {
      const res = await axios.get(`${backendUrl}/${discord_id}`);
      const status = res.data;

      if (!status || !status.activity || typeof status.time !== "number") {
        clearPresence();
        return;
      }

      let activity = status.activity;
      let detail = activity;
      if (status.paused) detail = `[⏸️ Paused] ${activity}`;

      // Timer fix
      if (lastActivity !== activity || localStartTimestamp === null) {
        localStartTimestamp = Math.floor(Date.now() / 1000) - status.time;
        lastActivity = activity;
      }
      const startTimestamp = status.paused ? undefined : localStartTimestamp;
      const largeImageKey = getImageKeyForActivity(activity);

      await rpc.setActivity({
        state: rpcTitle,
        details: detail,
        startTimestamp,
        largeImageKey,
        partyId: "gymsync-party-" + discord_id,
        partySize: 1,
        partyMax: 1,
        instance: false,
        buttons: [
          { label: "Check GymSync", url: "https://github.com/TheusHen/GymSync" }
        ],
      });

      lastPresence = true;
      log(`Presence updated: ${rpcTitle} | ${detail} | image: ${largeImageKey}`);
    } catch (err) {
      if (err.response && err.response.status === 404) {
        clearPresence();
        return;
      }
      logError("Error updating backend status: " + (err?.message || err));
    }
  }, 1000);
}

app.on("activate", () => {
  if (mainWindow) {
    mainWindow.show();
  } else {
    createOAuthWindow();
  }
});

app.on("before-quit", () => {
  app.isQuitting = true;
  if (rpcLoop) clearInterval(rpcLoop);
  tray?.destroy();
  log("App quitting...");
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});