import { execFile } from "node:child_process";
import { accessSync, constants } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export const INSTALL_MESSAGE =
  "WiFi or ISP isn't installed on this Mac, so there's nothing to read yet. " +
  "Install the free WiFi or ISP app from https://wifiorisp.com (or `brew install --cask coreyhaines31/tap/wifiorisp`), " +
  "open it once, then try again.";

const BUNDLE_ID = "app.wifiorisp.WiFiOrISP";
const APP_BINARY = "Contents/MacOS/wifiorisp";

// The only commands that can ever be spawned, and how long each may take. status waits up to 60 seconds
// for the app's first reading after it opens; speed and lag give the app 120 seconds. history and report
// only read the log on disk. watch streams until Ctrl-C, so it isn't here.
const TIMEOUTS_MS = {
  status: 75_000,
  history: 30_000,
  report: 30_000,
  speed: 150_000,
  lag: 150_000,
} as const;
export type Command = keyof typeof TIMEOUTS_MS;

// "90m", "24h", "7d", or combinations like "1h30m", the format the CLI's --since accepts.
const DURATION = /^(?:[1-9][0-9]{0,4}[mhd]){1,3}$/;
const UNIT_SECONDS: Record<string, number> = { m: 60, h: 3600, d: 86_400 };
// The app keeps 30 days of log.
export const MAX_SINCE_SECONDS = 30 * 86_400;

export function sinceSeconds(text: string): number | null {
  if (!DURATION.test(text)) return null;
  let total = 0;
  for (const [, value, unit] of text.matchAll(/([0-9]+)([mhd])/g)) total += Number(value) * UNIT_SECONDS[unit];
  return total > 0 && total <= MAX_SINCE_SECONDS ? total : null;
}

// The CLI exits 0 on success, 2 when `status` finds a problem (it still prints the verdict), and 1 on any
// error, with "wifiorisp: <message>" on stderr.
export type RunResult = { ok: true; code: 0 | 2; stdout: string } | { ok: false; text: string };

function isExecutable(path: string): boolean {
  try {
    accessSync(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function spotlightAppPaths(): Promise<string[]> {
  return new Promise((resolve) => {
    try {
      execFile(
        "/usr/bin/mdfind",
        [`kMDItemCFBundleIdentifier == '${BUNDLE_ID}'`],
        { timeout: 5_000 },
        (error, stdout) => {
          if (error) return resolve([]);
          const apps = stdout.split("\n").map((line) => line.trim()).filter(Boolean);
          resolve(apps.filter((app) => !app.includes("/.Trash/")));
        },
      );
    } catch {
      resolve([]);
    }
  });
}

export async function locateCli(): Promise<string | null> {
  const fromEnv = process.env.WIFIORISP_CLI?.trim();
  if (fromEnv && isExecutable(fromEnv)) return fromEnv;

  const candidates = [
    join("/Applications/WiFi or ISP.app", APP_BINARY),
    join(homedir(), "Applications/WiFi or ISP.app", APP_BINARY),
    "/opt/homebrew/bin/wifiorisp",
    "/usr/local/bin/wifiorisp",
  ];
  for (const path of candidates) {
    if (isExecutable(path)) return path;
  }

  for (const app of await spotlightAppPaths()) {
    const path = join(app, APP_BINARY);
    if (isExecutable(path)) return path;
  }
  return null;
}

function argv(command: Command, since?: string): string[] | null {
  switch (command) {
    case "status":
    case "speed":
    case "lag":
      return since === undefined ? [command, "--json"] : null;
    case "history":
      return since !== undefined && sinceSeconds(since) ? ["history", "--since", since, "--json"] : null;
    case "report":
      return since !== undefined && sinceSeconds(since) ? ["report", "--since", since] : null;
    default:
      return null;
  }
}

// The CLI's error line, not a progress line printed before it.
function errorMessage(stderr: string): string | undefined {
  const lines = stderr.split("\n").map((line) => line.trim()).filter(Boolean);
  const error = lines.find((line) => line.startsWith("wifiorisp: "));
  return (error ?? lines.at(-1))?.replace(/^wifiorisp: /, "").slice(0, 300);
}

export async function runWiFiOrISP(
  command: Command,
  options: { since?: string; onProgress?: (line: string) => void } = {},
): Promise<RunResult> {
  const args = argv(command, options.since);
  if (!args) return { ok: false, text: `Not allowed: ${String(command)}` };
  if (process.platform !== "darwin") {
    return { ok: false, text: "WiFi or ISP only runs on macOS." };
  }
  const cli = await locateCli();
  if (!cli) return { ok: false, text: INSTALL_MESSAGE };
  const timeout = TIMEOUTS_MS[command];

  return new Promise((resolve) => {
    try {
      const child = execFile(cli, args, { timeout, maxBuffer: 20 * 1024 * 1024 }, (error, stdout, stderr) => {
        const code = error ? (typeof error.code === "number" ? error.code : null) : 0;
        if (code === 0 || code === 2) return resolve({ ok: true, code, stdout });

        if (error?.killed) {
          return resolve({ ok: false, text: `WiFi or ISP didn't answer within ${timeout / 1000} seconds.` });
        }
        const message = errorMessage(stderr);
        if (message) return resolve({ ok: false, text: message });
        resolve({ ok: false, text: `WiFi or ISP's command line tool failed: ${error?.message ?? "unknown error"}` });
      });
      // Without a terminal, the CLI prints a line on stderr each time a test changes phase.
      if (options.onProgress) {
        child.stderr?.on("data", (chunk: Buffer) => {
          for (const line of chunk.toString().split("\n")) {
            if (line.trim() && !line.startsWith("wifiorisp: ")) options.onProgress?.(line.trim().slice(0, 200));
          }
        });
      }
    } catch (error) {
      resolve({ ok: false, text: `Couldn't start WiFi or ISP's command line tool at ${cli}: ${(error as Error).message}` });
    }
  });
}
