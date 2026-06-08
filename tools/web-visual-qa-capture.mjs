import { spawn } from "node:child_process";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import net from "node:net";

const args = new Map();
for (let i = 2; i < process.argv.length; i += 2) {
  args.set(process.argv[i], process.argv[i + 1]);
}

const browser = args.get("--browser");
const url = args.get("--url");
const out = args.get("--out");
const logOut = args.get("--log-out");
const metricsOut = args.get("--metrics-out");
const profile = args.get("--profile");
const width = Number(args.get("--width"));
const height = Number(args.get("--height"));
const waitMs = Number(args.get("--wait-ms") ?? "2500");
const scrollY = Number(args.get("--scroll-y") ?? "0");
const scrollSequence = (args.get("--scroll-sequence") ?? "")
  .split(";")
  .map((item) => item.trim())
  .filter(Boolean)
  .map((item) => {
    const [deltaY, delayAfterMs = 700] = item
      .split(",")
      .map((part) => Number(part.trim()));
    if (!Number.isFinite(deltaY) || !Number.isFinite(delayAfterMs)) {
      throw new Error(`Invalid --scroll-sequence item: ${item}`);
    }
    return { deltaY, delayAfterMs };
  });
const tapX = args.has("--tap-x") ? Number(args.get("--tap-x")) : null;
const tapY = args.has("--tap-y") ? Number(args.get("--tap-y")) : null;
const tapSequence = (args.get("--tap-sequence") ?? "")
  .split(";")
  .map((item) => item.trim())
  .filter(Boolean)
  .map((item) => {
    const [x, y, delayAfterMs = 900] = item
      .split(",")
      .map((part) => Number(part.trim()));
    if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(delayAfterMs)) {
      throw new Error(`Invalid --tap-sequence item: ${item}`);
    }
    return { x, y, delayAfterMs };
  });

if (!browser || !url || !out || !profile || !width || !height) {
  throw new Error("Missing required arguments for web visual QA capture.");
}

async function getFreePort() {
  return await new Promise((resolve, reject) => {
    const server = net.createServer();
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });
}

async function fetchJsonWithRetry(endpoint, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(endpoint);
      if (response.ok) {
        return await response.json();
      }
      lastError = new Error(`${endpoint} returned HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw lastError ?? new Error(`Timed out fetching ${endpoint}`);
}

function openWebSocket(wsUrl) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(wsUrl);
    socket.addEventListener("open", () => resolve(socket), { once: true });
    socket.addEventListener("error", (event) => reject(event.error ?? new Error("WebSocket open failed")), {
      once: true,
    });
  });
}

async function captureWithCdp(wsUrl) {
  const socket = await openWebSocket(wsUrl);
  let nextId = 1;
  const pending = new Map();
  const loadEvents = [];
  const browserEvents = [];

  function remoteObjectText(arg) {
    if (!arg) return "";
    if (typeof arg.value !== "undefined") return String(arg.value);
    if (arg.description) return String(arg.description);
    return JSON.stringify(arg);
  }

  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) {
        reject(new Error(message.error.message ?? JSON.stringify(message.error)));
      } else {
        resolve(message.result ?? {});
      }
      return;
    }
    if (message.method === "Page.loadEventFired") {
      for (const resolve of loadEvents.splice(0)) {
        resolve();
      }
    } else if (message.method === "Runtime.consoleAPICalled") {
      const type = message.params?.type ?? "log";
      browserEvents.push({
        source: "console",
        level: type,
        text: (message.params?.args ?? []).map(remoteObjectText).join(" "),
        url: message.params?.stackTrace?.callFrames?.[0]?.url ?? "",
        line: message.params?.stackTrace?.callFrames?.[0]?.lineNumber ?? null,
      });
    } else if (message.method === "Runtime.exceptionThrown") {
      const details = message.params?.exceptionDetails ?? {};
      const stackTrace = details.stackTrace?.callFrames?.map((frame) => ({
        functionName: frame.functionName ?? "",
        url: frame.url ?? "",
        line: frame.lineNumber ?? null,
        column: frame.columnNumber ?? null,
      })) ?? [];
      browserEvents.push({
        source: "runtime",
        level: "error",
        text: details.exception?.description ?? details.exception?.value ?? details.text ?? "Runtime exception",
        url: details.url ?? "",
        line: details.lineNumber ?? null,
        exceptionId: details.exceptionId ?? null,
        stackTrace,
      });
    } else if (message.method === "Log.entryAdded") {
      const entry = message.params?.entry ?? {};
      browserEvents.push({
        source: entry.source ?? "log",
        level: entry.level ?? "info",
        text: entry.text ?? "",
        url: entry.url ?? "",
        line: entry.lineNumber ?? null,
      });
    }
  });

  function send(method, params = {}) {
    const id = nextId++;
    socket.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
  }

  await send("Page.enable");
  await send("Runtime.enable");
  await send("Log.enable");
  await send("Performance.enable");
  await send("Emulation.setDeviceMetricsOverride", {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: false,
  });

  const loadPromise = new Promise((resolve) => loadEvents.push(resolve));
  await send("Page.navigate", { url });
  await Promise.race([
    loadPromise,
    new Promise((resolve) => setTimeout(resolve, 12000)),
  ]);
  await new Promise((resolve) => setTimeout(resolve, waitMs));
  async function tapAt(x, y) {
    await send("Input.dispatchMouseEvent", {
      type: "mousePressed",
      x,
      y,
      button: "left",
      clickCount: 1,
    });
    await send("Input.dispatchMouseEvent", {
      type: "mouseReleased",
      x,
      y,
      button: "left",
      clickCount: 1,
    });
  }

  if (tapX !== null && tapY !== null) {
    await tapAt(tapX, tapY);
    await new Promise((resolve) => setTimeout(resolve, 900));
  }
  for (const tap of tapSequence) {
    await tapAt(tap.x, tap.y);
    await new Promise((resolve) => setTimeout(resolve, tap.delayAfterMs));
  }
  async function scrollBy(deltaY) {
    if (deltaY === 0) return;
    const steps = Math.max(1, Math.ceil(Math.abs(deltaY) / 240));
    const stepDeltaY = deltaY / steps;
    for (let i = 0; i < steps; i++) {
      await send("Input.dispatchMouseEvent", {
        type: "mouseWheel",
        x: Math.floor(width / 2),
        y: Math.floor(height / 2),
        deltaX: 0,
        deltaY: stepDeltaY,
      });
      await new Promise((resolve) => setTimeout(resolve, 120));
    }
  }
  if (scrollY !== 0) {
    await scrollBy(scrollY);
    await new Promise((resolve) => setTimeout(resolve, 700));
  }
  for (const scroll of scrollSequence) {
    await scrollBy(scroll.deltaY);
    await new Promise((resolve) => setTimeout(resolve, scroll.delayAfterMs));
  }

  const frameMetrics = await measureFrameCadence(send);
  const performanceMetrics = await readPerformanceMetrics(send);
  const result = await send("Page.captureScreenshot", {
    format: "png",
    fromSurface: true,
    captureBeyondViewport: false,
  });
  socket.close();
  return {
    png: Buffer.from(result.data, "base64"),
    browserEvents,
    metrics: {
      frameMetrics,
      performanceMetrics,
    },
  };
}

async function measureFrameCadence(send, durationMs = 900) {
  const expression = `new Promise((resolve) => {
    const intervals = [];
    let last;
    const startedAt = performance.now();
    function step(timestamp) {
      if (typeof last === "number") intervals.push(timestamp - last);
      last = timestamp;
      if (timestamp - startedAt < ${durationMs}) {
        requestAnimationFrame(step);
        return;
      }
      const sorted = [...intervals].sort((a, b) => a - b);
      const sum = intervals.reduce((total, value) => total + value, 0);
      const percentile = (p) => {
        if (sorted.length === 0) return 0;
        const index = Math.min(sorted.length - 1, Math.ceil(sorted.length * p) - 1);
        return sorted[index];
      };
      resolve({
        sampleCount: intervals.length,
        avgFrameIntervalMs: intervals.length ? sum / intervals.length : 0,
        maxFrameIntervalMs: intervals.length ? Math.max(...intervals) : 0,
        p95FrameIntervalMs: percentile(0.95)
      });
    }
    requestAnimationFrame(step);
  })`;
  const response = await send("Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true,
  });
  return response.result?.value ?? {};
}

async function readPerformanceMetrics(send) {
  const response = await send("Performance.getMetrics");
  const metrics = {};
  for (const metric of response.metrics ?? []) {
    metrics[metric.name] = metric.value;
  }
  return metrics;
}

await mkdir(dirname(out), { recursive: true });
await mkdir(profile, { recursive: true });

const port = await getFreePort();
const browserArgs = [
  "--headless=new",
  "--disable-gpu",
  "--hide-scrollbars",
  "--no-first-run",
  "--no-default-browser-check",
  `--user-data-dir=${profile}`,
  `--remote-debugging-port=${port}`,
  `--window-size=${width},${height}`,
  "about:blank",
];

const child = spawn(browser, browserArgs, {
  stdio: ["ignore", "ignore", "pipe"],
  windowsHide: true,
});

let stderr = "";
child.stderr.on("data", (chunk) => {
  stderr += chunk.toString();
});

try {
  const pages = await fetchJsonWithRetry(`http://127.0.0.1:${port}/json/list`);
  const page = pages.find((entry) => entry.type === "page" && entry.webSocketDebuggerUrl);
  if (!page) {
    throw new Error("No debuggable page target found.");
  }
  const { png, browserEvents, metrics } = await captureWithCdp(page.webSocketDebuggerUrl);
  await writeFile(out, png);
  if (logOut) {
    await writeFile(logOut, `${JSON.stringify(browserEvents, null, 2)}\n`);
  }
  if (metricsOut) {
    await writeFile(metricsOut, `${JSON.stringify(metrics, null, 2)}\n`);
  }
  const severeEvents = browserEvents.filter((entry) => {
    const level = String(entry.level ?? "").toLowerCase();
    return level === "error" || level === "assert";
  });
  if (severeEvents.length > 0) {
    const summary = severeEvents
      .slice(0, 5)
      .map((entry) => `${entry.source}:${entry.level}: ${entry.text}`)
      .join("\n");
    throw new Error(`Browser console/runtime errors detected:\n${summary}`);
  }
} catch (error) {
  const detail = stderr.trim();
  throw new Error(detail ? `${error.message}\nBrowser stderr:\n${detail}` : error.message);
} finally {
  child.kill();
  setTimeout(() => child.kill("SIGKILL"), 1000).unref();
}
