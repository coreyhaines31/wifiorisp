// Ping and jitter test: 40 round trips to Cloudflare over TCP, one every quarter second.
(() => {
  const COUNT = 40;
  const GAP_MS = 250;
  const $ = (id) => document.getElementById(id);
  const ui = {
    start: $("pt-start"), status: $("pt-status"), bar: $("pt-bar"), live: $("pt-live"), spark: $("pt-spark"),
    result: $("pt-result"), rating: $("pt-rating"), summary: $("pt-summary"),
    ping: $("pt-ping"), jitter: $("pt-jitter"), range: $("pt-range"), lost: $("pt-lost"),
  };
  if (!ui.start) return;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const ms = (x) => `${Math.round(x)} ms`;
  const median = (xs) => {
    const s = [...xs].sort((a, b) => a - b);
    const m = Math.floor(s.length / 2);
    return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
  };

  function rate(ping, jitter) {
    const score = ping + 2 * jitter;
    if (score <= 40) return ["Excellent", "Great for everything, including competitive gaming and video calls."];
    if (score <= 90) return ["Good", "Smooth video calls and gaming."];
    if (score <= 160) return ["OK", "Fine for browsing and streaming. Calls may have a slight delay."];
    return ["Slow", "Expect noticeable delay or choppiness in calls and games."];
  }

  function drawSpark(values) {
    const max = Math.max(50, ...values) * 1.1;
    const w = 300, h = 60;
    const points = values.map((v, i) => `${(i / (COUNT - 1)) * w},${h - (v / max) * h}`).join(" ");
    ui.spark.innerHTML = `<polyline points="${points}" />`;
  }

  async function run() {
    ui.start.disabled = true;
    ui.result.hidden = true;
    ui.status.textContent = "Measuring…";
    const rtts = [];
    let lost = 0;
    await window.wifiProbe(new AbortController().signal); // warm up the connection
    for (let i = 0; i < COUNT; i++) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 2000);
      const rtt = await window.wifiProbe(controller.signal);
      clearTimeout(timeout);
      if (rtt == null) lost++; else { rtts.push(rtt); ui.live.textContent = ms(rtt); drawSpark(rtts); }
      ui.bar.style.width = `${((i + 1) / COUNT) * 100}%`;
      await sleep(GAP_MS);
    }
    ui.live.textContent = "";
    if (rtts.length < 5) {
      ui.status.textContent = "Too few round trips came back. Check your connection and try again.";
    } else {
      const ping = median(rtts);
      const diffs = rtts.slice(1).map((v, i) => Math.abs(v - rtts[i]));
      const jitter = diffs.reduce((a, b) => a + b, 0) / diffs.length;
      const [label, text] = rate(ping, jitter);
      ui.rating.textContent = label;
      ui.rating.dataset.rating = label;
      ui.summary.textContent = text;
      ui.ping.textContent = ms(ping);
      ui.jitter.textContent = ms(jitter);
      ui.range.textContent = `${ms(Math.min(...rtts))} to ${ms(Math.max(...rtts))}`;
      ui.lost.textContent = `${lost} of ${COUNT}`;
      ui.result.hidden = false;
      ui.status.textContent = "Done. Ping is the median round trip; jitter is how much it moves between round trips.";
    }
    ui.start.disabled = false;
    ui.start.textContent = "Run again";
  }
  ui.start.addEventListener("click", run);
})();
