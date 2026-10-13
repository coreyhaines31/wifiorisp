// Providers at your address, from the FCC's broadband availability data.
// The address goes to the U.S. Census Bureau's geocoder; the location becomes an H3 cell in the
// browser, and only the broad area's file (/data/providers/<res-4 cell>.json) is fetched here.
(() => {
  const $ = (id) => document.getElementById(id);
  const form = $("lookup-form");
  if (!form) return;
  const status = $("lookup-status");
  const results = $("lookup-results");
  const section = $("finder-results");
  const TECH = {
    fiber: ["Fiber", 0],
    cable: ["Cable", 1],
    "fixed-wireless": ["5G / wireless", 2],
    copper: ["DSL", 3],
    other: ["Other", 4],
  };
  let meta = null;
  let last = null;

  const say = (text) => { status.textContent = text; };

  const loadH3 = () => window.h3 ? Promise.resolve(window.h3) : new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = "/vendor/h3-js.umd.js";
    script.onload = () => resolve(window.h3);
    script.onerror = () => reject(new Error("Couldn't load the map grid."));
    document.head.append(script);
  });

  // The Census geocoder doesn't send CORS headers, but it supports JSONP.
  const geocode = (address) => new Promise((resolve, reject) => {
    const callback = `censusGeocode${Date.now()}`;
    const script = document.createElement("script");
    const done = () => { delete window[callback]; script.remove(); };
    const timer = setTimeout(() => { done(); reject(new Error("The address lookup timed out. Try again.")); }, 15000);
    window[callback] = (data) => {
      clearTimeout(timer);
      done();
      const match = data?.result?.addressMatches?.[0];
      if (!match) reject(new Error("Couldn't find that address. Include the street, city, and state, or the ZIP code."));
      else resolve({ lat: match.coordinates.y, lon: match.coordinates.x, label: match.matchedAddress });
    };
    const params = new URLSearchParams({ address, benchmark: "Public_AR_Current", format: "jsonp", callback });
    script.src = `https://geocoding.geo.census.gov/geocoder/locations/onelineaddress?${params}`;
    script.onerror = () => { clearTimeout(timer); done(); reject(new Error("The address lookup didn't answer. Try again.")); };
    document.head.append(script);
  });

  const here = () => new Promise((resolve, reject) => {
    if (!navigator.geolocation) return reject(new Error("This browser can't share your location."));
    navigator.geolocation.getCurrentPosition(
      (position) => resolve({ lat: position.coords.latitude, lon: position.coords.longitude, label: "your location" }),
      () => reject(new Error("Location wasn't shared. Enter your address instead.")),
      { enableHighAccuracy: true, timeout: 15000 },
    );
  });

  // Each area file lists provider names and technologies once; offers refer to them by position.
  const expand = (file) => {
    const cells = {};
    for (const [cell, [homes, offers]] of Object.entries(file.c || {})) {
      cells[cell] = [homes, offers.map(([name, tech, ...rest]) => [file.p[name], file.t[tech], ...rest])];
    }
    return cells;
  };
  const shards = new Map();
  const shard = async (parent) => {
    if (!shards.has(parent)) {
      // A missing file is an area with no homes; a network failure is forgotten so the next search retries.
      const loading = fetch(`/data/providers/${parent}.json`).then((r) => (r.ok ? r.json() : {})).then(expand);
      loading.catch(() => shards.delete(parent));
      shards.set(parent, loading);
    }
    return shards.get(parent);
  };

  // Offers in the location's cell. A cell with no homes (a park, an empty lot) borrows its neighbors'.
  const offersAt = async (h3, point) => {
    meta = meta || await fetch("/data/providers/meta.json")
      .then((r) => (r.ok ? r.json() : Promise.reject()))
      .catch(() => { throw new Error("The provider data didn't load. Try again in a moment."); });
    const cell = h3.latLngToCell(point.lat, point.lon, meta.resolution);
    const own = (await shard(h3.cellToParent(cell, meta.parentResolution)))[cell];
    if (own) return { offers: own[1], homes: own[0], nearby: false };
    const merged = [];
    let homes = 0;
    for (const neighbor of h3.gridDisk(cell, 1)) {
      const entry = (await shard(h3.cellToParent(neighbor, meta.parentResolution)))[neighbor];
      if (entry) { homes += entry[0]; merged.push(...entry[1]); }
    }
    return { offers: merged, homes, nearby: true };
  };

  // One row per provider and technology, keeping the best speeds and the widest coverage.
  const combine = (offers) => {
    const rows = new Map();
    for (const [provider, tech, share, down, up] of offers) {
      const key = `${provider}|${tech}`;
      const row = rows.get(key) || { provider, tech, share: 0, down: 0, up: 0 };
      row.share = Math.max(row.share, share);
      row.down = Math.max(row.down, down);
      row.up = Math.max(row.up, up);
      rows.set(key, row);
    }
    return [...rows.values()];
  };

  const needs = () => ({
    down: parseInt($("n-down")?.textContent, 10) || 0,
    up: parseInt($("n-up")?.textContent, 10) || 0,
  });

  const speed = (mbps) => (mbps >= 1000 ? `${+(mbps / 1000).toFixed(1)}\u00a0Gbps` : `${mbps}\u00a0Mbps`);

  const cell = (tag, text, className) => {
    const element = document.createElement(tag);
    element.textContent = text;
    if (className) element.className = className;
    return element;
  };

  // The Census geocoder answers in capitals: "276 4TH AVE, CHULA VISTA, CA, 91910".
  const tidy = (label) => label.toLowerCase().replace(/\b[a-z]/g, (c) => c.toUpperCase())
    .replace(/(\d)(St|Nd|Rd|Th)\b/g, (_, d, s) => d + s.toLowerCase())
    .replace(/, ([A-Za-z]{2}),/, (_, st) => `, ${st.toUpperCase()},`);

  const card = (row) => {
    const offer = cell("article", "", `offer${row.fits ? " fits" : ""}`);
    const top = cell("div", "", "offer-top");
    top.append(cell("span", TECH[row.tech]?.[0] ?? row.tech, `tech tech-${row.tech}`));
    top.append(cell("span", row.fits ? "Fits your home" : "Too slow for your home", row.fits ? "fit" : "short"));
    const speeds = cell("p", "", "offer-speeds");
    const pair = (mbps, word) => {
      const span = cell("span", "");
      span.append(cell("b", speed(mbps)), ` ${word}`);
      return span;
    };
    speeds.append(pair(row.down, "down"), " ", pair(row.up, "up"));
    const bar = cell("div", "", "coverage");
    const fill = cell("span", "");
    fill.style.width = `${Math.max(2, Math.round(row.share * 100))}%`;
    bar.append(fill);
    const share = Math.round(row.share * 100);
    offer.append(top, cell("h3", row.provider), speeds, bar,
      cell("p", share < 1 ? "Offered to a few homes nearby" : `Offered to ${share}% of homes nearby`, "offer-share"));
    return offer;
  };

  const render = () => {
    if (!last) return;
    const target = needs();
    const rows = combine(last.offers)
      .map((row) => ({ ...row, fits: row.down >= target.down && row.up >= target.up }))
      .sort((a, b) => (b.fits - a.fits) || (TECH[a.tech]?.[1] ?? 9) - (TECH[b.tech]?.[1] ?? 9) || b.down - a.down);
    results.replaceChildren();
    section.hidden = false;

    const fitting = rows.filter((row) => row.fits).length;
    const fiber = rows.filter((row) => row.tech === "fiber");
    const fastest = rows.reduce((best, row) => (row.down > (best?.down ?? 0) ? row : best), null);
    const head = cell("div", "", "results-head");
    head.append(cell("h2", rows.length
      ? `${rows.length} internet ${rows.length === 1 ? "option" : "options"}${last.nearby ? " near" : " at"} ${last.label}`
      : `No wired or 5G home providers listed at ${last.label}`));
    if (rows.length) {
      const facts = cell("ul", "", "results-facts");
      facts.append(
        cell("li", `${fitting} of ${rows.length} fit your home`),
        cell("li", fiber.length ? `Fiber from ${fiber.map((row) => row.provider).join(", ")}` : "No fiber listed here"),
        cell("li", `Fastest: ${speed(fastest.down)} from ${fastest.provider}`),
      );
      head.append(facts);
    }
    results.append(head);

    if (rows.length) {
      const grid = cell("div", "", "offers");
      rows.forEach((row) => grid.append(card(row)));
      results.append(grid);
    }
    const asOf = new Date(`${meta.vintage}T12:00:00`).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
    const note = cell("p", "", "results-note");
    note.append(
      `Satellite (Starlink, Viasat, HughesNet) reaches almost every home and isn't listed. "Homes nearby" means the homes in this `
      + `neighborhood (about a third of a square mile). Data as of ${asOf}, as reported to the FCC; a listing isn't a promise of service, so `,
    );
    const fcc = cell("a", "check your exact address on the FCC map");
    fcc.href = "https://broadbandmap.fcc.gov";
    note.append(fcc, " and with the provider.");
    results.append(note);
  };

  const look = async (find) => {
    try {
      say("Finding your address…");
      const [h3, point] = await Promise.all([loadH3(), find()]);
      say("Looking up providers…");
      const found = await offersAt(h3, point);
      last = { ...found, label: point.label === "your location" ? "your location" : tidy(point.label) };
      say("");
      render();
      section.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
    } catch (error) {
      say(error.message);
    }
  };

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const address = $("lookup-address").value.trim();
    if (address) look(() => geocode(address));
  });
  $("lookup-here").addEventListener("click", () => look(here));
  $("needs-form")?.addEventListener("input", () => setTimeout(render));
})();
