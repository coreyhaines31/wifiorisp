// In-browser bufferbloat test: latency at idle, then while the connection is saturated
// downloading and uploading. Probes go over TCP (HTTP/1.1), like most traffic that suffers
// from bufferbloat; QUIC can sidestep the queues being measured. Browsers open at most six
// connections per host, so load uses five and the probe keeps the sixth to itself.
(() => {
  const LOAD = "https://speed.cloudflare.com";
  const PROBE = "https://speed.cloudflare.com/__down?bytes=0";
  const PHASE_MS = 10000;
  const RAMP_MS = 2000;
  const PROBE_GAP_MS = 200;

  const $ = (id) => document.getElementById(id);
  const ui = {
    start: $("bb-start"), status: $("bb-status"), bar: $("bb-bar"), live: $("bb-live"),
    result: $("bb-result"), grade: $("bb-grade"), summary: $("bb-summary"),
    idle: $("bb-idle"), down: $("bb-down"), up: $("bb-up"), downRate: $("bb-down-rate"), upRate: $("bb-up-rate"),
  };
  if (!ui.start) return;

  const median = (xs) => {
    if (!xs.length) return null;
    const s = [...xs].sort((a, b) => a - b);
    const m = Math.floor(s.length / 2);
    return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
  };
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const ms = (x) => `${Math.round(x)} ms`;
  const mbps = (bytes, millis) => (bytes * 8) / (millis / 1000) / 1e6;

  // One round trip: request sent to first byte back, minus the time Cloudflare reports spending
  // on the request itself (its Server-Timing header), which is often larger than the round trip.
  async function probe(signal) {
    const url = `${PROBE}&r=${Math.random().toString(36).slice(2)}`;
    const t0 = performance.now();
    try {
      const res = await fetch(url, { cache: "no-store", signal });
      await res.arrayBuffer();
    } catch {
      return null;
    }
    // The timing entry is recorded just after the body finishes, so give it a moment.
    let entry = performance.getEntriesByName(url).pop();
    for (let i = 0; !entry && i < 5; i++) {
      await sleep(20);
      entry = performance.getEntriesByName(url).pop();
    }
    if (performance.getEntriesByType("resource").length > 200) performance.clearResourceTimings();
    if (!entry || !(entry.responseStart > 0)) return performance.now() - t0;
    const server = (entry.serverTiming || [])
      .filter((t) => t.name === "cfSpeedEdge" || t.name === "cfSpeedWorker")
      .reduce((sum, t) => sum + t.duration, 0);
    return Math.max(1, entry.responseStart - entry.requestStart - server);
  }

  async function probeLoop(until, onProbe, signal) {
    while (performance.now() < until && !signal.aborted) {
      const rtt = await probe(signal);
      if (rtt != null) onProbe(rtt);
      await sleep(PROBE_GAP_MS);
    }
  }

  async function downloadStream(counter, signal) {
    while (!signal.aborted) {
      try {
        const res = await fetch(`${LOAD}/__down?bytes=100000000&r=${Math.random()}`, { cache: "no-store", signal });
        const reader = res.body.getReader();
        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;
          counter.bytes += value.length;
        }
      } catch {
        return;
      }
    }
  }

  const chunk = new Blob([new Uint8Array(8 * 1024 * 1024)]);
  async function uploadStream(counter, signal) {
    while (!signal.aborted) {
      try {
        await fetch(`${LOAD}/__up?r=${Math.random()}`, { method: "POST", body: chunk, signal });
        counter.bytes += chunk.size;
      } catch {
        return;
      }
    }
  }

  async function loadedPhase(kind, streams, progressFrom) {
    const controller = new AbortController();
    const counter = { bytes: 0 };
    const start = performance.now();
    const work = Array.from({ length: streams }, () =>
      kind === "down" ? downloadStream(counter, controller.signal) : uploadStream(counter, controller.signal));
    const rtts = [];
    const ticker = setInterval(() => {
      const t = Math.min(1, (performance.now() - start) / PHASE_MS);
      ui.bar.style.width = `${(progressFrom + t * 0.45) * 100}%`;
    }, 100);
    await probeLoop(start + PHASE_MS, (rtt) => {
      ui.live.textContent = ms(rtt);
      if (performance.now() - start > RAMP_MS) rtts.push(rtt);
    }, controller.signal);
    const elapsed = performance.now() - start;
    controller.abort();
    clearInterval(ticker);
    await Promise.allSettled(work);
    return { latency: median(rtts), rate: mbps(counter.bytes, elapsed) };
  }

  function grade(added) {
    if (added <= 5) return ["A+", "No bufferbloat. Calls and games stay smooth even while your connection is maxed out."];
    if (added <= 30) return ["A", "Very little bufferbloat. You'd be hard-pressed to notice it."];
    if (added <= 60) return ["B", "Some bufferbloat. Video calls may hiccup during big downloads or uploads."];
    if (added <= 200) return ["C", "Noticeable bufferbloat. Expect laggy calls and games whenever something else is downloading or uploading."];
    if (added <= 400) return ["D", "Heavy bufferbloat. Anything real-time suffers whenever the connection is busy."];
    return ["F", "Severe bufferbloat. A single upload or download can make everything else nearly unusable."];
  }

  async function run() {
    ui.start.disabled = true;
    ui.result.hidden = true;
    ui.bar.style.width = "0%";
    try {
      ui.status.textContent = "Measuring idle latency…";
      performance.setResourceTimingBufferSize(1000);
      const idleSignal = new AbortController().signal;
      await probe(idleSignal); // warm up the connection
      const idle = [];
      for (let i = 0; i < 10; i++) {
        const rtt = await probe(idleSignal);
        if (rtt != null) { idle.push(rtt); ui.live.textContent = ms(rtt); }
        ui.bar.style.width = `${(i + 1)}%`;
        await sleep(100);
      }
      const idleMs = median(idle);
      if (idleMs == null) throw new Error("no idle probes");

      ui.status.textContent = "Saturating your download…";
      const down = await loadedPhase("down", 5, 0.1);
      ui.status.textContent = "Saturating your upload…";
      const up = await loadedPhase("up", 4, 0.55);
      ui.bar.style.width = "100%";

      const downAdded = Math.max(0, (down.latency ?? idleMs) - idleMs);
      const upAdded = Math.max(0, (up.latency ?? idleMs) - idleMs);
      const [letter, text] = grade(Math.max(downAdded, upAdded));
      ui.grade.textContent = letter;
      ui.grade.dataset.grade = letter[0];
      ui.summary.textContent = text;
      ui.idle.textContent = ms(idleMs);
      ui.down.textContent = down.latency == null ? "–" : `${ms(down.latency)} (+${ms(downAdded)})`;
      ui.up.textContent = up.latency == null ? "–" : `${ms(up.latency)} (+${ms(upAdded)})`;
      ui.downRate.textContent = `${Math.round(down.rate)} Mbps`;
      ui.upRate.textContent = `${Math.round(up.rate)} Mbps`;
      ui.result.hidden = false;
      ui.status.textContent = "Done. Run it again any time.";
    } catch {
      ui.status.textContent = "The test couldn't reach Cloudflare's servers. Check your connection and try again.";
    } finally {
      ui.live.textContent = "";
      ui.start.disabled = false;
      ui.start.textContent = "Run again";
    }
  }

  ui.start.addEventListener("click", run);
})();
