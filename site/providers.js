// Providers at your address, from the FCC's broadband availability data.
// The address goes to the U.S. Census Bureau's geocoder; the location becomes an H3 cell in the
// browser, and only the broad area's file (/data/providers/<res-4 cell>.json) is fetched here.
(() => {
  const $ = (id) => document.getElementById(id);
  const form = $("lookup-form");
  if (!form) return;
  const status = $("lookup-status");
  const results = $("lookup-results");
  const TECH = {
    fiber: ["Fiber", 0],
    cable: ["Cable", 1],
    "fixed-wireless": ["Fixed wireless or 5G home", 2],
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

  const shards = new Map();
  const shard = async (parent) => {
    if (!shards.has(parent)) {
      shards.set(parent, fetch(`/data/providers/${parent}.json`).then((r) => (r.ok ? r.json() : {})));
    }
    return shards.get(parent);
  };

  // Offers in the location's cell. A cell with no homes (a park, an empty lot) borrows its neighbors'.
  const offersAt = async (h3, point) => {
    meta = meta || await fetch("/data/providers/meta.json").then((r) => r.json());
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

  const render = () => {
    if (!last) return;
    const target = needs();
    const rows = combine(last.offers)
      .map((row) => ({ ...row, fits: row.down >= target.down && row.up >= target.up }))
      .sort((a, b) => (b.fits - a.fits) || (TECH[a.tech]?.[1] ?? 9) - (TECH[b.tech]?.[1] ?? 9) || b.down - a.down);
    results.replaceChildren();
    results.hidden = false;

    const fitting = rows.filter((row) => row.fits).length;
    results.append(cell("p", rows.length
      ? `${rows.length} home internet options${last.nearby ? " near" : " at"} ${last.label}. `
        + `${fitting ? `${fitting} meet` : "None meet"} what your home needs (${target.down} down, ${target.up} up).`
      : `The FCC data lists no wired or fixed wireless providers at ${last.label}.`, "lookup-summary"));

    if (rows.length) {
      const table = document.createElement("table");
      table.className = "compare lookup-table";
      const head = table.createTHead().insertRow();
      ["Provider", "Type", "Up to (down / up)", "Nearby homes", "Fits your home"].forEach((label) => head.append(cell("th", label)));
      const body = table.createTBody();
      for (const row of rows) {
        const tr = body.insertRow();
        tr.append(
          cell("td", row.provider),
          cell("td", TECH[row.tech]?.[0] ?? row.tech),
          cell("td", `${speed(row.down)} / ${speed(row.up)}`, "speeds"),
          cell("td", `${Math.round(row.share * 100)}%`),
          cell("td", row.fits ? "✓ Yes" : "No", row.fits ? "fits" : "short"),
        );
      }
      const wrap = cell("div", "", "table-wrap");
      wrap.append(table);
      results.append(wrap);
    }
    const note = cell("p", "", "bb-note");
    note.append(
      `Satellite (Starlink, Viasat, HughesNet) is available almost everywhere and isn't listed. "Nearby homes" is the share of homes in this `
      + `neighborhood-sized area (about a third of a square mile) each provider says it can serve. Data as of ${new Date(`${meta.vintage}T12:00:00`).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })}, as reported to the FCC; a listing isn't a promise of service, so `,
    );
    const fcc = cell("a", "check your exact address on the FCC map");
    fcc.href = "https://broadbandmap.fcc.gov";
    note.append(fcc, " and with the provider.");
    results.append(note);
  };

  const look = async (find) => {
    results.hidden = true;
    try {
      say("Finding your location…");
      const [h3, point] = await Promise.all([loadH3(), find()]);
      say("Looking up providers…");
      const found = await offersAt(h3, point);
      last = { ...found, label: point.label };
      say("");
      render();
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
