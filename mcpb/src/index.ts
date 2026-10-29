import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { runWiFiOrISP, sinceSeconds } from "./cli.js";
import { shapeHistory, shapeLag, shapeReport, shapeSpeed, shapeStatus } from "./shape.js";

const VERSION = "0.1.0";
// The manifest's allow_tests setting. Speed and lag tests aren't even registered without it.
const testsAllowed = process.env.WIFIORISP_ALLOW_TESTS === "true";

const OTHER_APPS =
  "Covers the internet connection only: for CPU and memory, use Spare; for disk space, Disk Forecast; for AI " +
  "usage limits, Fuel Gauge; for camera and microphone, Green Room.";

const server = new McpServer(
  { name: "wifiorisp", version: VERSION },
  {
    instructions:
      "WiFi or ISP times this Mac's router and the internet at the same moment, every 5 to 30 seconds, so it " +
      "can say whether slow or dropping internet is the Wi-Fi (or router) or the ISP. Start with " +
      "connection_status. Timestamps are UTC. " +
      (testsAllowed
        ? "speed_test and lag_test each take about 20 seconds; run them only when the person asks for one or " +
          "agrees to it. "
        : "If a next step names speed_test or lag_test, those tools are off: the person can run the test from " +
          "WiFi or ISP's menu, or turn on tests in this extension's settings. ") +
      OTHER_APPS,
  },
);

const readOnly = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
} as const;
// Tests send traffic to outside servers and are logged by the app, but change nothing on the Mac.
const test = { ...readOnly, idempotentHint: false, openWorldHint: true } as const;

const since = (fallback: string) =>
  z
    .string()
    .default(fallback)
    .refine((value) => sinceSeconds(value) !== null, "Use a duration like 90m, 24h, or 7d, up to 30d.")
    .describe(`How far back, like 90m, 24h, or 7d (up to 30d; the app keeps 30 days). Default ${fallback}.`);

function reply(result: { ok: boolean; text: string }) {
  return {
    content: [{ type: "text" as const, text: result.text }],
    ...(result.ok ? {} : { isError: true }),
  };
}

type Extra = {
  _meta?: { progressToken?: string | number };
  sendNotification: (notification: {
    method: "notifications/progress";
    params: { progressToken: string | number; progress: number; message?: string };
  }) => Promise<void>;
};

// Passes the CLI's phase lines ("Download: ...", "Upload: ...") on as progress, when the host asks for it.
function progress(extra: Extra) {
  const token = extra._meta?.progressToken;
  if (token === undefined) return undefined;
  let step = 0;
  return (message: string) => {
    extra.sendNotification({ method: "notifications/progress", params: { progressToken: token, progress: ++step, message } }).catch(() => {});
  };
}

server.registerTool(
  "connection_status",
  {
    title: "Is it my Wi-Fi or my ISP?",
    description:
      "Whether slow or dropping internet is this Mac's Wi-Fi (or router) or the ISP, right now. verdict has " +
      "kind, side ('yours' or 'isp' when one is at fault), a headline, and detail; problem is true when " +
      "something is wrong. router and internet are the latest round trips with a rating. wifi has the signal, " +
      "network name, band, and Wi-Fi generation. nextSteps say what to do (a wifiorisp.com guide, or a tool " +
      "to run), and limits are ceilings no setting fixes. Use for 'is it my Wi-Fi or my ISP?', 'why is my " +
      "internet slow?', 'is my ISP down?', or 'is my Wi-Fi bad?'. Opens WiFi or ISP in the background if it " +
      `isn't running. ${OTHER_APPS}`,
    inputSchema: {},
    annotations: { ...readOnly, title: "Is it my Wi-Fi or my ISP?" },
  },
  async () => {
    const result = await runWiFiOrISP("status");
    return reply(result.ok ? shapeStatus(result.stdout, result.code) : result);
  },
);

server.registerTool(
  "connection_history",
  {
    title: "Connection history",
    description:
      "What WiFi or ISP measured over a period: typical round trips to the router and the internet (ms), the " +
      "share of time slow because of the ISP (ispSlow) or the home network (yourSideSlow), probes lost, and " +
      "events like drops, outages, network changes, and past tests as [time, what happened]. Use for 'has my " +
      "internet been dropping?', 'was it slow last night?', or 'how often is my ISP the problem?'. For right " +
      "now, use connection_status.",
    inputSchema: { since: since("24h") },
    annotations: { ...readOnly, title: "Connection history" },
  },
  async ({ since }) => {
    const result = await runWiFiOrISP("history", { since });
    return reply(result.ok ? shapeHistory(result.stdout, since) : result);
  },
);

server.registerTool(
  "isp_report",
  {
    title: "Report for your ISP",
    description:
      "The plain-text report to send the ISP: outages (and whether the router kept answering through them), " +
      "how much of the time was slow on the ISP's side versus the home network, speed against the plan, and " +
      "how it was measured. Use for 'write up the outages for my ISP' or 'give me proof it's my ISP'. Pass " +
      "the text on as is; it's written in the person's voice.",
    inputSchema: { since: since("7d") },
    annotations: { ...readOnly, title: "Report for your ISP" },
  },
  async ({ since }) => {
    const result = await runWiFiOrISP("report", { since });
    return reply(result.ok ? shapeReport(result.stdout) : result);
  },
);

if (testsAllowed) {
  server.registerTool(
    "speed_test",
    {
      title: "Speed test (M-Lab)",
      description:
        "Measures download and upload speed with M-Lab's NDT7 test (about 20 seconds). PRIVACY: M-Lab " +
        "publishes every result, including this Mac's public IP address, as open data. Run it only when the " +
        "person asks for a speed test or agrees after being told that, and set publish_ip_to_mlab to true to " +
        "confirm. Use for 'how fast is my internet?' or 'am I getting the speed I pay for?'.",
      inputSchema: {
        publish_ip_to_mlab: z
          .literal(true)
          .describe("Must be true: the person agreed that M-Lab publishes the result with their IP address."),
      },
      annotations: { ...test, title: "Speed test (M-Lab)" },
    },
    async (_args, extra) => {
      const result = await runWiFiOrISP("speed", { onProgress: progress(extra as Extra) });
      return reply(result.ok ? shapeSpeed(result.stdout) : result);
    },
  );

  server.registerTool(
    "lag_test",
    {
      title: "Lag under load",
      description:
        "Loads the connection for about 20 seconds (a few hundred MB on a fast connection) and measures how " +
        "much lag builds up, in round trips per minute (rpm, higher is better), and where the queue builds: " +
        "yourSide (Wi-Fi or router) or pastRouter (the ISP). Run it only when the person asks or agrees. Use " +
        "for 'why do video calls stutter when someone's downloading?' or 'do I have bufferbloat?'.",
      inputSchema: {},
      annotations: { ...test, title: "Lag under load" },
    },
    async (_args, extra) => {
      const result = await runWiFiOrISP("lag", { onProgress: progress(extra as Extra) });
      return reply(result.ok ? shapeLag(result.stdout) : result);
    },
  );
}

await server.connect(new StdioServerTransport());
