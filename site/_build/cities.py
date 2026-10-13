"""City and state pages for "internet providers in [city]", from city_data.json.

Every sentence that carries a number comes from that city's own FCC filings, so no two pages
say the same thing. render.py writes the pages; this module builds their HTML.
"""
import html
import json
import math
import os
from datetime import date

DATA = os.path.join(os.path.dirname(__file__), "city_data.json")
TECH = {"fiber": "Fiber", "cable": "Cable", "fixed-wireless": "5G / wireless", "copper": "DSL", "other": "Other"}
ORDER = {"fiber": 0, "cable": 1, "fixed-wireless": 2, "copper": 3, "other": 4}
WIRED = {"fiber", "cable", "copper"}
# FCC brand names → our "why is my [provider] internet slow" guides.
GUIDES = {
    ("Spectrum", None): "why-is-my-spectrum-internet-slow",
    ("Xfinity", None): "why-is-my-xfinity-internet-slow",
    ("AT&T", None): "why-is-my-att-internet-slow",
    ("Verizon", "fiber"): "why-is-my-verizon-fios-internet-slow",
    ("Verizon", "fixed-wireless"): "why-is-my-verizon-5g-home-internet-slow",
    ("T-Mobile", None): "why-is-my-t-mobile-home-internet-slow",
    ("Cox Communications", None): "why-is-my-cox-internet-slow",
    ("Optimum", None): "why-is-my-optimum-internet-slow",
    ("Frontier", None): "why-is-my-frontier-internet-slow",
    ("CenturyLink", None): "why-is-my-centurylink-internet-slow",
    ("Quantum Fiber", None): "why-is-my-centurylink-internet-slow",
    ("Google Fiber", None): "why-is-my-google-fiber-internet-slow",
    ("GFiber", None): "why-is-my-google-fiber-internet-slow",
}


def esc(text):
    return html.escape(str(text), quote=True)


def load():
    if not os.path.exists(DATA):
        return None
    with open(DATA) as handle:
        return json.load(handle)


def as_of(vintage):
    return date.fromisoformat(vintage).strftime("%B %-d, %Y")


def speed(mbps):
    return f"{mbps / 1000:g} Gbps" if mbps >= 1000 else f"{mbps:g} Mbps"


def pct(share):
    value = round(share * 100)
    return "under 1%" if share and value < 1 else f"{value}%"


def names(items):
    items = list(items)
    return items[0] if len(items) == 1 else ", ".join(items[:-1]) + " and " + items[-1]


def city_path(city):
    return f'/internet-providers/{city["state"].lower()}/{city["slug"]}'


def state_path(usps):
    return f"/internet-providers/{usps.lower()}"


def guide_for(provider, tech):
    return GUIDES.get((provider, tech)) or GUIDES.get((provider, None))


def offers(city):
    """One row per provider and technology, sorted by technology, then speed."""
    rows = [{"provider": p, "tech": t, "share": s, "down": d, "up": u} for p, t, s, d, u in city["offers"]]
    return sorted(rows, key=lambda r: (ORDER.get(r["tech"], 9), -r["down"], -r["share"]))


def summary(city, state):
    rows = offers(city)
    fiber = [r for r in rows if r["tech"] == "fiber"]
    cable = [r for r in rows if r["tech"] == "cable"]
    wireless = [r for r in rows if r["tech"] == "fixed-wireless"]
    fastest = max(rows, key=lambda r: (r["down"], r["up"]))
    providers = sorted({r["provider"] for r in rows})
    return {"rows": rows, "fiber": fiber, "cable": cable, "wireless": wireless, "fastest": fastest,
            "providers": providers, "wired": sorted({r["provider"] for r in rows if r["tech"] in WIRED})}


def verdict(city, state, s):
    name = city["name"]
    parts = [f'{name} has {len(s["providers"])} home internet providers in the FCC\'s latest data, '
             f'{len(s["wired"])} of them wired.']
    if s["fiber"]:
        best = max(s["fiber"], key=lambda r: r["share"])
        reach, statewide = city["fiberReach"], state["fiberReach"]
        compare = ("more than" if reach > statewide + 0.05 else "less than" if reach < statewide - 0.05
                   else "about the same as")
        parts.append(f'Fiber reaches at least {pct(reach)} of homes, {compare} {state["name"]} as a whole '
                     f'({pct(statewide)}), led by {best["provider"]} at up to {speed(best["down"])}.')
    else:
        parts.append("No provider reports fiber here yet.")
    if s["cable"]:
        top = max(s["cable"], key=lambda r: r["share"])
        parts.append(f'{top["provider"]} cable covers {pct(top["share"])} of homes, with uploads up to '
                     f'{speed(top["up"])}.')
    return " ".join(parts)


def nearby(city, cities, count=6):
    def distance(other):
        dlat = math.radians(other["lat"] - city["lat"])
        dlon = math.radians(other["lon"] - city["lon"]) * math.cos(math.radians(city["lat"]))
        return dlat * dlat + dlon * dlon
    same = [c for c in cities if c["state"] == city["state"] and c is not city]
    return sorted(same, key=distance)[:count]


def card(row):
    guide = guide_for(row["provider"], row["tech"])
    link = (f'<a class="offer-guide" href="/{guide}">Slow {esc(row["provider"])} internet? Fix it</a>'
            if guide else "")
    width = max(2, round(row["share"] * 100))
    return f'''          <article class="offer">
            <div class="offer-top"><span class="tech tech-{row["tech"]}">{TECH.get(row["tech"], row["tech"])}</span></div>
            <h3>{esc(row["provider"])}</h3>
            <p class="offer-speeds"><span><b>{speed(row["down"])}</b> down</span> <span><b>{speed(row["up"])}</b> up</span></p>
            <div class="coverage"><span style="width:{width}%"></span></div>
            <p class="offer-share">Offered to {pct(row["share"])} of homes</p>{link}
          </article>'''


def faqs(city, state, s):
    name, items = f'{city["name"]}, {city["state"]}', []
    if s["fiber"]:
        best = max(s["fiber"], key=lambda r: r["share"])
        items.append((f"What is the best internet provider in {name}?",
                      f'For most homes, fiber from {best["provider"]} if it reaches your street: up to '
                      f'{speed(best["down"])} down and {speed(best["up"])} up, with steady lag. It covers '
                      f'{pct(best["share"])} of homes, so check your address first.'))
        items.append((f"Is fiber internet available in {name}?",
                      f'Yes. {names(sorted({r["provider"] for r in s["fiber"]}))} report fiber in {city["name"]}, '
                      f'reaching at least {pct(city["fiberReach"])} of homes.'))
    else:
        top = max(s["rows"], key=lambda r: (r["tech"] in WIRED, r["share"], r["down"]))
        items.append((f"What is the best internet provider in {name}?",
                      f'With no fiber reported yet, {top["provider"]} ({TECH[top["tech"]].lower()}, up to '
                      f'{speed(top["down"])}) covers the most homes. Compare upload speeds before you choose.'))
        items.append((f"Is fiber internet available in {name}?",
                      f'Not yet: no provider reports fiber in {city["name"]} in the FCC data as of '
                      f'{as_of(DATA_VINTAGE)}.'))
    fastest = s["fastest"]
    items.append((f"What is the fastest internet in {name}?",
                  f'{fastest["provider"]} advertises up to {speed(fastest["down"])} down and '
                  f'{speed(fastest["up"])} up ({TECH[fastest["tech"]].lower()}), offered to {pct(fastest["share"])} '
                  f'of homes.'))
    items.append((f"How many internet providers are in {name}?",
                  f'{len(s["providers"])}: {len(s["wired"])} wired (fiber, cable, or DSL) and '
                  f'{len({r["provider"] for r in s["wireless"]})} 5G or fixed wireless, plus satellite from '
                  f'Starlink, Viasat, and HughesNet, which reaches almost every home.'))
    return items


DATA_VINTAGE = "2025-12-31"


def city_page(city, state, cities, vintage):
    s = summary(city, state)
    name, full = city["name"], f'{city["name"]}, {city["state"]}'
    count = len(s["providers"])
    title = f"Internet Providers in {full}: {count} Providers Compared"
    if len(title) > 60:
        title = f"Internet Providers in {full}"
    fiber_note = (f'Fiber reaches {pct(city["fiberReach"])} of homes, up to {speed(max(r["down"] for r in s["fiber"]))}'
                  if s["fiber"] else "No fiber yet")
    description = (f'{count} internet providers serve {name}, {state["name"]}. {fiber_note}. See each provider\'s '
                   f'top speeds and how many homes it reaches, from FCC data.')
    near = nearby(city, cities)
    cards = "\n".join(card(r) for r in s["rows"])
    upload = ""
    if s["cable"] and s["fiber"]:
        cable_up = max(r["up"] for r in s["cable"])
        fiber_up = max(r["up"] for r in s["fiber"])
        upload = (f'<h2>Upload speeds in {esc(name)}</h2><p>Cable plans here top out at {speed(cable_up)} up, against '
                  f'{speed(fiber_up)} on fiber. If you work from home, back up to the cloud, or stream, the upload '
                  f'number matters more than the download. Our <a href="/internet-providers#how-much">speed guide</a> '
                  f'shows how much you need.</p>')
    elif s["cable"]:
        cable_up = max(r["up"] for r in s["cable"])
        upload = (f'<h2>Upload speeds in {esc(name)}</h2><p>Without fiber, cable is the fastest wired option, and its '
                  f'uploads top out at {speed(cable_up)}. That covers video calls for a household, but big uploads '
                  f'will be slow.</p>')
    wireless = ""
    if s["wireless"]:
        five_g = sorted({r["provider"] for r in s["wireless"]})
        wireless = (f'<h2>5G home and fixed wireless</h2><p>{esc(names(five_g))} '
                    f'{"offers" if len(five_g) == 1 else "offer"} wireless home internet in {esc(name)}. It needs no '
                    f'installer and is often cheaper, but speed depends on the signal where you live and on how busy '
                    f'the tower is in the evening.</p>')
    nearby_links = "".join(f'<a href="{city_path(c)}"><b>{esc(c["name"])}</b><span>{len({o[0] for o in c["offers"]})} '
                           f'providers · fiber to {pct(c["fiberReach"])}</span></a>' for c in near)
    state_name = state["name"]
    faq_items = faqs(city, state, s)
    crumbs = [("Internet providers", "/internet-providers"), (state_name, state_path(city["state"])), (name, None)]
    page = {
        "title": title, "description": description, "path": city_path(city), "faqs": faq_items,
        "crumbs": crumbs, "vintage": vintage,
        "main": f'''    <section class="city-hero">
      <div class="wrap">
{breadcrumbs(crumbs)}
        <p class="eyebrow">FCC data as of {as_of(vintage)}</p>
        <h1>Internet providers in {esc(full)}</h1>
        <p class="lede">{esc(verdict(city, state, s))}</p>
        <ul class="city-stats">
          <li><b>{count}</b><span>providers</span></li>
          <li><b>{pct(city["fiberReach"]) if s["fiber"] else "None"}</b><span>of homes can get fiber</span></li>
          <li><b>{speed(s["fastest"]["down"])}</b><span>fastest plan</span></li>
          <li><b>{city["homes"]:,}</b><span>homes in the data</span></li>
        </ul>
      </div>
    </section>
    <section class="city-offers">
      <div class="wrap">
        <div class="city-offers-head">
          <h2>Every provider in {esc(name)}</h2>
          <a class="pill" href="/internet-providers">Check your exact address</a>
        </div>
        <div class="offers">
{cards}
        </div>
        <p class="results-note">"Offered to" is the share of {esc(name)}'s homes each provider says it can serve. Satellite (Starlink, Viasat, HughesNet) reaches almost every home and isn't listed. Data as of {as_of(vintage)}, from the FCC's Broadband Data Collection; a listing isn't a promise of service at every address.</p>
      </div>
    </section>
    <section class="article">
      <div class="wrap prose data-prose">
        {upload}
        {wireless}
        <h2>Before you switch</h2>
        <p>If your internet is slow now, make sure the provider is the problem. The free <a href="/">WiFi or ISP</a> Mac app times your router and the internet at the same moment and tells you which side is slow, and the <a href="/bufferbloat-test">bufferbloat test</a> shows whether calls will stutter when the connection is busy.</p>
        <h2>Nearby cities</h2>
        <div class="related">{nearby_links}</div>
        <p><a href="{state_path(city["state"])}">All cities in {esc(state_name)}</a></p>
      </div>
    </section>
''',
    }
    return page


def breadcrumbs(crumbs):
    items = " <span aria-hidden=\"true\">›</span> ".join(
        f'<a href="{path}">{esc(label)}</a>' if path else f'<span aria-current="page">{esc(label)}</span>'
        for label, path in crumbs)
    return f'        <nav class="crumbs" aria-label="Breadcrumb">{items}</nav>'


def state_page(usps, state, cities, vintage):
    mine = [c for c in cities if c["state"] == usps]
    rows = "\n".join(
        f'            <tr><td><a href="{city_path(c)}">{esc(c["name"])}</a></td><td>{c["homes"]:,}</td>'
        f'<td>{len({o[0] for o in c["offers"]})}</td><td>{pct(c["fiberReach"]) if c["fiberReach"] else "None"}</td></tr>'
        for c in mine)
    top = "\n".join(
        f'            <tr><td>{esc(p)}</td><td>{TECH.get(t, t)}</td><td>{pct(share)}</td></tr>' for p, t, share in state["top"])
    name = state["name"]
    crumbs = [("Internet providers", "/internet-providers"), (name, None)]
    leader = state["top"][0] if state["top"] else None
    lede = (f'Fiber reaches at least {pct(state["fiberReach"])} of {name}\'s {state["homes"]:,} homes in the FCC\'s '
            f'latest data.' + (f' {leader[0]} {TECH[leader[1]].lower()} is the most widespread wired service, '
                               f'offered to {pct(leader[2])} of homes.' if leader else ""))
    return {
        "title": f"Internet Providers in {name}: Fiber and Cable by City",
        "description": (f"See the internet providers in {len(mine)} {name} cities, with fiber reach and the number of "
                        f"providers in each, from FCC broadband data."),
        "path": state_path(usps), "faqs": [], "crumbs": crumbs, "vintage": vintage,
        "main": f'''    <section class="city-hero">
      <div class="wrap">
{breadcrumbs(crumbs)}
        <p class="eyebrow">FCC data as of {as_of(vintage)}</p>
        <h1>Internet providers in {esc(name)}</h1>
        <p class="lede">{esc(lede)}</p>
        <p><a class="pill" href="/internet-providers">Check your exact address</a></p>
      </div>
    </section>
    <section class="article">
      <div class="wrap prose data-prose">
        <h2>The biggest wired providers in {esc(name)}</h2>
        <div class="table-wrap"><table class="compare">
          <thead><tr><th>Provider</th><th>Type</th><th>Homes covered</th></tr></thead>
          <tbody>
{top}
          </tbody>
        </table></div>
        <h2>Internet providers by city</h2>
        <div class="table-wrap"><table class="compare">
          <thead><tr><th>City</th><th>Homes</th><th>Providers</th><th>Fiber reach</th></tr></thead>
          <tbody>
{rows}
          </tbody>
        </table></div>
      </div>
    </section>
''',
    }


def pages():
    """Every state and city page, as dicts render.py turns into HTML."""
    data = load()
    if not data:
        return []
    global DATA_VINTAGE
    DATA_VINTAGE = data["vintage"]
    cities = data["cities"]
    result = []
    for usps, state in sorted(data["states"].items()):
        if any(c["state"] == usps for c in cities):
            result.append(state_page(usps, state, cities, data["vintage"]))
    for city in cities:
        result.append(city_page(city, data["states"][city["state"]], cities, data["vintage"]))
    return result


def state_links():
    """For the providers hub: every state with city pages, and the biggest cities."""
    data = load()
    if not data:
        return ""
    states = sorted({c["state"] for c in data["cities"]}, key=lambda s: data["states"][s]["name"])
    state_html = "".join(f'<a href="{state_path(s)}">{esc(data["states"][s]["name"])}</a>' for s in states)
    biggest = sorted(data["cities"], key=lambda c: -c["homes"])[:24]
    city_html = "".join(f'<a href="{city_path(c)}">{esc(c["name"])}, {c["state"]}</a>' for c in biggest)
    return f'''
        <h2 id="by-state">Internet providers by state</h2>
        <nav class="link-grid" aria-label="States">{state_html}</nav>
        <h2>Largest cities</h2>
        <nav class="link-grid" aria-label="Largest cities">{city_html}</nav>
'''
