// Starts the built server over stdio, calls every always-on tool against this Mac, and fails
// if a call that should work errors or a call that should fail doesn't.
// Then checks, against a fake CLI, the exact argv each tool sends and how each CLI outcome comes back,
// with speed and lag tests both off (not registered) and on.
// Run: npm test. SERVER=<path> runs an unpacked .mcpb instead of server/index.mjs.
// The real speed and lag tests are never run here: M-Lab publishes the IP of every speed test.
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const ok = true;
const fails = false;
// [tool, arguments, should work, what a working answer must contain]
const calls = [
  ["connection_status", {}, ok, (text) => JSON.parse(text).verdict?.headline],
  ["connection_history", {}, ok, (text) => JSON.parse(text).since === "24h"],
  ["connection_history", { since: "90m" }, ok, (text) => JSON.parse(text).since === "90m"],
  ["connection_history", { since: "1h30m" }, ok, (text) => JSON.parse(text).since === "1h30m"],
  ["connection_history", { since: "30d" }, ok, (text) => JSON.parse(text).since === "30d"],
  ["connection_history", { since: "31d" }, fails],
  ["connection_history", { since: "0m" }, fails],
  ["connection_history", { since: "1.5h" }, fails],
  ["connection_history", { since: "24H" }, fails],
  ["connection_history", { since: "24h --csv" }, fails],
  ["connection_history", { since: "24h; rm -rf ~" }, fails],
  ["connection_history", { since: 24 }, fails],
  ["isp_report", {}, ok, (text) => text.startsWith("Connection report")],
  ["isp_report", { since: "1d" }, ok, (text) => text.startsWith("Connection report")],
  ["isp_report", { since: "--help" }, fails],
  ["speed_test", { publish_ip_to_mlab: true }, fails],
  ["lag_test", {}, fails],
  ["watch", {}, fails],
];

const NO_MEASUREMENTS =
  "No measurements in this period. WiFi or ISP only measures while it's running: open it from Applications.";
// [fake mode, tests on, tool, arguments, should work, argv the CLI must get (null: never spawned), exact answer]
const fakeCalls = [
  [
    "ok", false, "connection_status", {}, ok, "status --json",
    {
      problem: false, time: "2026-10-29T18:22Z", link: "wifi", paused: false, routerMaker: "Calix", provider: "Example Fiber",
      verdict: { kind: "good", problem: false, headline: "Fine: WiFi and ISP both OK", detail: "All good." },
      wifi: {
        signal: "Excellent", network: "Home", band: "6 GHz", channel: 37, generation: "Wi-Fi 6E", linkRateMbps: 2401,
        rssiDBm: -37, noiseDBm: -93,
      },
      router: { ms: 8.6, rating: "Fast" }, internet: { ms: 15, rating: "Fast" },
      nextSteps: [{ title: "Run a speed test", tool: "speed_test" }, { title: "Read this" }],
      limits: [],
    },
  ],
  [
    "problem", false, "connection_status", {}, ok, "status --json",
    {
      problem: true, time: "2026-10-29T18:22Z", link: "wifi", paused: false,
      verdict: { kind: "ispDown", side: "isp", problem: true, headline: "ISP down", detail: "Your router answers but nothing past it does." },
      router: { ms: 4, rating: "Fast" }, internet: { rating: "No answer" },
      nextSteps: [
        { title: "Check for an outage", url: "https://wifiorisp.com/internet-keeps-dropping" },
        { title: "Send your ISP a report", tool: "isp_report" },
      ],
      limits: [{ headline: "Plan ceiling", detail: "Your plan tops out.", url: "https://wifiorisp.com/routers" }],
    },
  ],
  [
    "ok", false, "connection_history", {}, ok, "history --since 24h --json",
    {
      since: "24h", start: "2026-10-28T18:22Z", end: "2026-10-29T18:22Z", measurements: 3311, routerMedianMs: 7.2,
      internetMedianMs: 13.4, internetP95Ms: 51.1, internetLoss: 0.012, ispSlow: 0.05, yourSideSlow: 0,
      networks: ["Home"], events: [["2026-10-29T03:10Z", "Internet dropped for 2m"]],
    },
  ],
  [
    "empty", false, "connection_history", { since: "7d" }, ok, "history --since 7d --json",
    {
      since: "7d", start: "2026-10-28T18:22Z", end: "2026-10-29T18:22Z", measurements: 0, internetLoss: 0, ispSlow: 0,
      yourSideSlow: 0, networks: [], events: [], note: NO_MEASUREMENTS,
    },
  ],
  [
    "many", false, "connection_history", { since: "7d" }, ok, "history --since 7d --json",
    (answer) => answer.events.length === 30 && answer.events[0][1] === "Drop 11" && answer.events.at(-1)[1] === "Drop 40" &&
      answer.eventsShown === "last 30 of 40",
  ],
  ["ok", false, "isp_report", {}, ok, "report --since 7d", "Connection report\n=================\nPeriod: Oct 22 to Oct 29\n\n- Outages: none."],
  ["ok", false, "isp_report", { since: "90m" }, ok, "report --since 90m", "Connection report\n=================\nPeriod: Oct 22 to Oct 29\n\n- Outages: none."],
  ["ok", false, "isp_report", { since: "45d" }, fails, null, null],
  ["ok", false, "speed_test", { publish_ip_to_mlab: true }, fails, null, null],
  ["ok", false, "lag_test", {}, fails, null, null],
  [
    "ok", true, "speed_test", { publish_ip_to_mlab: true }, ok, "speed --json",
    { time: "2026-10-29T18:30Z", downloadMbps: 312.44, uploadMbps: 40.2, minRTTms: 9.1, server: "Los Angeles, US", measuredBy: "M-Lab NDT7" },
  ],
  ["ok", true, "speed_test", {}, fails, null, null],
  ["ok", true, "speed_test", { publish_ip_to_mlab: false }, fails, null, null],
  ["ok", true, "speed_test", { publish_ip_to_mlab: "true" }, fails, null, null],
  [
    "ok", true, "lag_test", {}, ok, "lag --json",
    {
      time: "2026-10-29T18:31Z", rpm: 2900, grade: "High", headline: "Low lag", detail: "Lag stays low.", idleMs: 12, loadedMs: 20,
      routerAddedMs: 1, internetAddedMs: 3, queue: "pastRouter", downloadMbps: 300, uploadMbps: 40,
    },
  ],
  ["garbage", false, "connection_status", {}, fails, "status --json", "Couldn't read WiFi or ISP's verdict."],
  ["garbage", false, "connection_history", {}, fails, "history --since 24h --json", "Couldn't read WiFi or ISP's history."],
  ["garbage", true, "speed_test", { publish_ip_to_mlab: true }, fails, "speed --json", "Couldn't read the speed test result."],
  ["garbage", true, "lag_test", {}, fails, "lag --json", "Couldn't read the lag test result."],
  ["stderr", false, "connection_status", {}, fails, "status --json", "fake stderr error"],
  ["stderr", false, "isp_report", { since: "3d" }, fails, "report --since 3d", "fake stderr error"],
  ["stderr", true, "lag_test", {}, fails, "lag --json", "fake stderr error"],
];
const alwaysOn = ["connection_history", "connection_status", "isp_report"];
const withTests = [...alwaysOn, "lag_test", "speed_test"].sort();
const server = process.env.SERVER ?? new URL("../server/index.mjs", import.meta.url).pathname;
const fakeCli = new URL("./fake-cli.sh", import.meta.url).pathname;
const max = Number(process.env.SMOKE_CHARS ?? 600);
const failures = [];

async function connect(env) {
  const transport = new StdioClientTransport({ command: process.execPath, args: [server], env: { ...process.env, ...env } });
  const client = new Client({ name: "wifiorisp-smoke", version: "0.0.0" });
  await client.connect(transport);
  return client;
}

async function call(client, name, args) {
  let result;
  try {
    result = await client.callTool({ name, arguments: args });
  } catch (error) {
    result = { isError: true, content: [{ type: "text", text: `protocol error: ${error.message}` }] };
  }
  return { isError: Boolean(result.isError), text: result.content.map((c) => c.text).join("\n") };
}

function show(label, { isError, text }) {
  const shown = text.length > max ? `${text.slice(0, max)}\n… (${text.length} chars)` : text;
  console.log(`\n### ${label}${isError ? " [isError]" : ""}\n${shown}`);
}

async function checkTools(client, expected, label) {
  const { tools } = await client.listTools();
  const names = tools.map((t) => t.name).sort();
  console.log(`tools (${label}): ${names.join(", ")}`);
  if (names.join() !== expected.join()) failures.push(`${label}: expected exactly ${expected.join(", ")}`);
  for (const tool of tools) {
    if (!tool.annotations?.readOnlyHint || tool.annotations?.destructiveHint !== false) {
      failures.push(`${tool.name} is not annotated read-only`);
    }
    const isTest = tool.name.endsWith("_test");
    if (Boolean(tool.annotations?.openWorldHint) !== isTest) failures.push(`${tool.name} openWorldHint`);
  }
  const speed = tools.find((t) => t.name === "speed_test");
  if (speed && !/publishes every result, including this Mac's public IP address/.test(speed.description)) {
    failures.push("speed_test description lacks the M-Lab IP disclosure");
  }
}

// Tests stay off unless WIFIORISP_ALLOW_TESTS is exactly "true", as the manifest sets it.
const client = await connect({ WIFIORISP_CLI: process.env.WIFIORISP_CLI ?? "", WIFIORISP_ALLOW_TESTS: "false" });
await checkTools(client, alwaysOn, "tests off");
for (const [name, args, shouldWork, check] of calls) {
  const label = `${name} ${JSON.stringify(args)}`;
  const result = await call(client, name, args);
  show(label, result);
  if (result.isError === shouldWork) failures.push(label);
  else if (shouldWork) {
    let good = false;
    try {
      good = Boolean(check(result.text));
    } catch {
      good = false;
    }
    if (!good) failures.push(`${label} (unexpected output)`);
  }
}
await client.close();

const scratch = mkdtempSync(join(tmpdir(), "wifiorisp-smoke-"));
const argvLog = join(scratch, "argv");
for (const allow of ["", "1", "TRUE"]) {
  const other = await connect({ WIFIORISP_CLI: fakeCli, WIFIORISP_ALLOW_TESTS: allow });
  await checkTools(other, alwaysOn, `WIFIORISP_ALLOW_TESTS="${allow}"`);
  await other.close();
}
const on = await connect({ WIFIORISP_CLI: fakeCli, WIFIORISP_ALLOW_TESTS: "true" });
await checkTools(on, withTests, "tests on");
await on.close();

for (const [mode, tests, name, args, shouldWork, argv, expected] of fakeCalls) {
  const label = `fake CLI (${mode}, tests ${tests ? "on" : "off"}) ${name} ${JSON.stringify(args)}`;
  rmSync(argvLog, { force: true });
  const fake = await connect({
    WIFIORISP_CLI: fakeCli, WIFIORISP_ALLOW_TESTS: String(tests), FAKE_MODE: mode, FAKE_ARGV_LOG: argvLog,
  });
  const result = await call(fake, name, args);
  await fake.close();
  show(label, result);
  let sent = null;
  try {
    sent = readFileSync(argvLog, "utf8");
  } catch {
    sent = null;
  }
  if (sent !== argv) failures.push(`${label} (sent "${sent}", expected "${argv}")`);
  if (result.isError === shouldWork) failures.push(label);
  else if (expected === null) continue;
  else if (typeof expected === "function") {
    if (!expected(JSON.parse(result.text))) failures.push(label);
  } else if (result.text !== (typeof expected === "string" ? expected : JSON.stringify(expected))) failures.push(label);
}
rmSync(scratch, { recursive: true, force: true });

if (failures.length) {
  console.error(`\nFAILED: ${failures.join("; ")}`);
  process.exit(1);
}
console.log(`\nAll ${calls.length + fakeCalls.length} calls behaved as expected.`);
