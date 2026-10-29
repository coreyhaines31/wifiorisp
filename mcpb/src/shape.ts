// Turns the CLI's JSON into short answers for Claude. Only the listed fields pass through, so nothing
// the CLI might add later (or anything unexpected) reaches the conversation by accident.
//
// What the CLI's JSON never carries, and this keeps out: the public IP, the access point's MAC address
// (BSSID), the router's MAC address, and where the Mac is. Kept on purpose: the network name (it answers
// "which network was that?"), the router's maker, and the provider, which the CLI already reduces to names.

type Shaped = { ok: true; text: string } | { ok: false; text: string };
type Json = Record<string, unknown>;
type Value = string | number | boolean;

const SITE = "https://wifiorisp.com/";
const MAX_EVENTS = 30;
const MAX_REPORT_CHARS = 20_000;
// What the status's next steps would run, as this extension's tools.
const STEP_TOOLS: Record<string, string> = {
  "wifiorisp speed": "speed_test",
  "wifiorisp lag": "lag_test",
  "wifiorisp report": "isp_report",
};

function isObject(value: unknown): value is Json {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

// "2026-10-29T17:25:53Z" -> "2026-10-29T17:25Z": seconds don't matter here.
function minute(value: string): string {
  return value.replace(/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}):\d{2}(?:\.\d+)?Z$/, "$1Z");
}

function clean(value: unknown): Value | undefined {
  if (typeof value === "number" && Number.isFinite(value)) return Math.round(value * 1000) / 1000;
  if (typeof value === "boolean") return value;
  if (typeof value === "string") return minute(value.replace(/[\u0000-\u001f\u007f]/g, " ").slice(0, 300));
  return undefined;
}

function pick(source: unknown, fields: readonly string[]): Json | undefined {
  if (!isObject(source)) return undefined;
  const out: Json = {};
  for (const field of fields) {
    const value = clean(source[field]);
    if (value !== undefined) out[field] = value;
  }
  return out;
}

function siteUrl(value: unknown): string | undefined {
  return typeof value === "string" && value.startsWith(SITE) && value.length < 200 ? value : undefined;
}

function parse(stdout: string): Json | null {
  try {
    const parsed: unknown = JSON.parse(stdout);
    return isObject(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

const VERDICT_FIELDS = ["kind", "side", "problem", "headline", "detail"] as const;
const WIFI_FIELDS = ["signal", "network", "band", "channel", "generation", "linkRateMbps", "rssiDBm", "noiseDBm"] as const;
const TIMING_FIELDS = ["ms", "rating"] as const;

export function shapeStatus(stdout: string, code: 0 | 2): Shaped {
  const status = parse(stdout);
  if (!status || !isObject(status.verdict)) return { ok: false, text: "Couldn't read WiFi or ISP's verdict." };

  const answer: Json = { problem: code === 2 };
  for (const field of ["time", "link", "paused", "routerMaker", "provider"] as const) {
    const value = clean(status[field]);
    if (value !== undefined) answer[field] = value;
  }
  answer.verdict = pick(status.verdict, VERDICT_FIELDS);
  const wifi = pick(status.wifi, WIFI_FIELDS);
  if (wifi) answer.wifi = wifi;
  for (const field of ["router", "internet"] as const) {
    const timing = pick(status[field], TIMING_FIELDS);
    if (timing) answer[field] = timing;
  }

  const steps = Array.isArray(status.nextSteps) ? status.nextSteps : [];
  answer.nextSteps = steps.filter(isObject).slice(0, 10).map((step) => {
    const out: Json = {};
    const title = clean(step.title);
    if (typeof title === "string") out.title = title;
    const url = siteUrl(step.url);
    if (url) out.url = url;
    const tool = typeof step.command === "string" ? STEP_TOOLS[step.command] : undefined;
    if (tool) out.tool = tool;
    return out;
  });
  const limits = Array.isArray(status.limits) ? status.limits : [];
  answer.limits = limits.filter(isObject).slice(0, 10).map((limit) => {
    const out = pick(limit, ["headline", "detail"]) ?? {};
    const url = siteUrl(limit.url);
    if (url) out.url = url;
    return out;
  });
  return { ok: true, text: JSON.stringify(answer) };
}

const HISTORY_FIELDS = [
  "start",
  "end",
  "measurements",
  "routerMedianMs",
  "internetMedianMs",
  "internetP95Ms",
  "internetLoss",
  "ispSlow",
  "yourSideSlow",
] as const;

export const NO_MEASUREMENTS =
  "No measurements in this period. WiFi or ISP only measures while it's running: open it from Applications.";

export function shapeHistory(stdout: string, since: string): Shaped {
  const history = parse(stdout);
  if (!history) return { ok: false, text: "Couldn't read WiFi or ISP's history." };

  const answer: Json = { since, ...pick(history, HISTORY_FIELDS) };
  const networks = Array.isArray(history.networks) ? history.networks : [];
  answer.networks = networks.map(clean).filter((name) => typeof name === "string").slice(0, 10);
  const events = (Array.isArray(history.events) ? history.events : [])
    .filter(isObject)
    .map((event) => {
      const time = clean(event.time);
      const text = clean(event.text);
      return typeof time === "string" && typeof text === "string" ? [time, text] : null;
    })
    .filter((event) => event !== null);
  // events are [time, what happened], newest last
  answer.events = events.slice(-MAX_EVENTS);
  if (events.length > MAX_EVENTS) answer.eventsShown = `last ${MAX_EVENTS} of ${events.length}`;
  if (!answer.measurements) answer.note = NO_MEASUREMENTS;
  return { ok: true, text: JSON.stringify(answer) };
}

// The report is the CLI's plain text, meant to be pasted into a message to the ISP, so it passes through
// as text. It's built from the same summary as history, plus the Mac's time zone (like America/Los_Angeles),
// which the report needs so its local times mean something to the ISP.
export function shapeReport(stdout: string): Shaped {
  const text = stdout.replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "").trim();
  if (!text) return { ok: false, text: "WiFi or ISP's report came back empty." };
  if (text.length <= MAX_REPORT_CHARS) return { ok: true, text };
  return { ok: true, text: `${text.slice(0, MAX_REPORT_CHARS)}\n… (report cut short; use a shorter since)` };
}

const SPEED_FIELDS = ["time", "downloadMbps", "uploadMbps", "minRTTms", "server"] as const;
const LAG_FIELDS = [
  "time",
  "rpm",
  "grade",
  "headline",
  "detail",
  "idleMs",
  "loadedMs",
  "routerAddedMs",
  "internetAddedMs",
  "queue",
  "downloadMbps",
  "uploadMbps",
] as const;

export function shapeSpeed(stdout: string): Shaped {
  const speed = parse(stdout);
  if (!speed || typeof speed.downloadMbps !== "number") return { ok: false, text: "Couldn't read the speed test result." };
  return { ok: true, text: JSON.stringify({ ...pick(speed, SPEED_FIELDS), measuredBy: "M-Lab NDT7" }) };
}

export function shapeLag(stdout: string): Shaped {
  const lag = parse(stdout);
  if (!lag || typeof lag.rpm !== "number") return { ok: false, text: "Couldn't read the lag test result." };
  return { ok: true, text: JSON.stringify(pick(lag, LAG_FIELDS)) };
}
