// One network round trip to Cloudflare over TCP, shared by the site's tests.
(() => {
  const PROBE = "https://speed.cloudflare.com/__down?bytes=0";
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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

  window.wifiProbe = probe;
})();
