"""Programmatic pages built from researched data: "Why is my [ISP] internet slow?" pages,
router login pages by brand and by address, and their hubs. Anything the research marked
UNVERIFIED stays off the page."""
import html
import re

from isp_data import ISPS
from router_data import ADDRESSES, ROUTERS


def esc(text):
    return html.escape(text, quote=True)


def verified(text):
    """Drops UNVERIFIED values, and UNVERIFIED sentences inside longer text."""
    if not text or text.strip().upper().startswith("UNVERIFIED"):
        return ""
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    return " ".join(s for s in sentences if "UNVERIFIED" not in s.upper())


def verified_list(items):
    return [v for v in (verified(i) for i in items or []) if v]


def steps(items, ordered=True):
    items = verified_list(items)
    if not items:
        return ""
    tag = "ol" if ordered else "ul"
    cls = ' class="steps"' if ordered else ""
    rows = "".join(f"<li>{esc(i)}</li>" for i in items)
    return f"<{tag}{cls}>{rows}</{tag}>"


def para(text):
    text = verified(text)
    return f"<p>{esc(text)}</p>" if text else ""


def link(url, label):
    return f'<a href="{esc(url)}">{esc(label)}</a>' if url else ""


def sources(urls):
    rows = "".join(f'<li><a href="{esc(u)}">{esc(u)}</a></li>' for u in urls or [])
    return f'<h2>Sources</h2><ul class="sources">{rows}</ul>' if rows else ""


def callout(text):
    text = verified(text)
    return f'<div class="callout"><p>{esc(text)}</p></div>' if text else ""


# Short names for titles and headings, where the researched display name is long.
SHORT = {
    "verizon-5g-home": "Verizon 5G Home", "t-mobile-home-internet": "T-Mobile Home Internet",
    "centurylink": "CenturyLink", "google-fiber": "Google Fiber",
    "xfinity": "Xfinity", "spectrum": "Spectrum", "att": "AT&T", "verizon-fios": "Verizon Fios", "cox": "Cox",
    "t-mobile": "T-Mobile", "google-nest-wifi": "Google Nest Wifi", "netgear": "NETGEAR", "tp-link": "TP-Link",
    "asus": "ASUS", "linksys": "Linksys", "ubiquiti-unifi": "UniFi", "apple-airport": "AirPort", "eero": "eero",
}


def short(item):
    return SHORT.get(item["slug"], item["name"])


def fit(*options, limit=60):
    """The longest option that fits the limit, else the shortest."""
    fitting = [o for o in options if len(o) <= limit]
    return max(fitting, key=len) if fitting else min(options, key=len)


def internet(name):
    """'Spectrum internet', but 'T-Mobile Home Internet' rather than '... Internet internet'."""
    return name if name.lower().endswith("internet") else f"{name} internet"


# ---------------------------------------------------------------- ISP pages

def isp_slug(isp):
    slug = isp["slug"].removesuffix("-internet")
    return f"why-is-my-{slug}-internet-slow"


def isp_page(isp):
    name = short(isp)
    net = internet(name)
    kinds = ", ".join(isp["connection_types"])
    outage = ""
    if isp.get("outage_url") or verified(isp.get("outage_notes")):
        outage = (f'<h2>Check for a {esc(name)} outage</h2>'
                  + (f'<p>{link(isp["outage_url"], name + " outage page")}</p>' if isp.get("outage_url") else "")
                  + para(isp.get("outage_notes")))
    equipment = "".join(filter(None, [
        para(isp.get("gateway")),
        f'<p><strong>Admin page:</strong> {esc(verified(isp["admin_address"]))}</p>' if verified(isp.get("admin_address")) else "",
        f'<p><strong>App:</strong> {esc(isp["app"])}</p>' if isp.get("app") else "",
        f'<p><strong>Bridge mode:</strong> {esc(verified(isp["bridge_mode"]))}</p>' if verified(isp.get("bridge_mode")) else "",
        f'<p><strong>Your own equipment:</strong> {esc(verified(isp["own_equipment"]))}</p>' if verified(isp.get("own_equipment")) else "",
    ]))
    before_call = steps(isp.get("recommended_steps"))
    help_links = " · ".join(filter(None, [
        link(isp.get("slow_speed_help_url"), f"{name}'s slow-speed help"),
        link(isp.get("speed_test_url"), f"{name} speed test"),
        link(isp.get("support_url"), f"Contact {name}"),
    ]))
    asymmetry = verified(isp.get("asymmetry"))
    body = f'''
        {callout(isp.get("notes"))}
        <h2>First, rule out your Wi-Fi</h2>
        <p>A slow {esc(name)} connection and a slow Wi-Fi network feel identical. Time a round trip to your router and one to the internet at the same moment. If your router answers quickly and the internet doesn't, the slowdown is on {esc(name)}'s side. If even your router is slow, it's your Wi-Fi or router, and {esc(name)} can't fix it. <a href="/why-is-my-wifi-so-slow">Here's how to check on a Mac.</a></p>

        <h2>What usually slows down {esc(name)}</h2>
        <p>{esc(name)} delivers internet over {esc(kinds)}. The usual causes:</p>
        {steps(isp.get("slowdown_causes"), ordered=False)}
        {f"<h3>Upload versus download</h3><p>{esc(asymmetry)} When an upload fills that smaller pipe, everything else lags, which is called bufferbloat. <a href='/bufferbloat-test'>Test for it.</a></p>" if asymmetry else ""}
        {outage}
        <h2>Restart your {esc(name)} equipment</h2>
        {steps(isp.get("restart_steps"))}
        {f"<h2>Your {esc(name)} equipment</h2>{equipment}" if equipment else ""}
        {f"<h2>Before you call {esc(name)}</h2><p>{esc(name)} recommends these steps:</p>{before_call}" if before_call else ""}
        <p>When you do call, bring a record: when it was slow, for how long, and proof your router answered normally the whole time. That moves a ticket past “restart your router.”</p>
        {f"<p>{help_links}</p>" if help_links else ""}
        {sources(isp.get("sources"))}
'''
    title_net = net[:1].upper() + net[1:]
    return {
        "slug": isp_slug(isp),
        "title": fit(f"Why Is My {title_net.replace(' internet', ' Internet')} Slow? Wi-Fi or {name}?",
                     f"Why Is My {title_net.replace(' internet', ' Internet')} Slow?"),
        "description": fit(
            f"Is slow {net} your Wi-Fi or {name}? How to tell, what slows {name} down, outages, restarting, and what to do before you call.",
            f"Is slow {net} your Wi-Fi or {name}? How to tell, typical causes, outages, and what to do before you call.",
            limit=160),
        "eyebrow": f"{name}",
        "h1": f"Why is my {esc(net)} slow?",
        "lede": f"Slow {esc(net)} has two possible sources: your home Wi-Fi, or {esc(name)}'s network. Here's how to tell them apart, the slowdowns typical of {esc(name)}, and the fixes that work.",
        "tldr": f"Compare your router with the internet. If the router is quick and the internet is slow, it's {esc(name)}. Check for an outage, restart your equipment in the right order, and if it keeps happening, log it and contact {esc(name)} with the evidence.",
        "body": body,
        "faqs": [],
        "cta": f"Find out if it's your Wi-Fi or {esc(name)}.",
    }


def isp_hub():
    cards = "".join(
        f'<a href="/{isp_slug(i)}"><b>{esc(short(i))}</b><span>{esc(", ".join(i["connection_types"]))}</span></a>'
        for i in ISPS)
    return {
        "slug": "slow-internet",
        "title": "Why Is My Internet Slow? Guides for Every Major ISP",
        "description": "Slow internet on Spectrum, Xfinity, AT&T, Verizon, T-Mobile, Cox, Optimum, Frontier, CenturyLink, or Starlink? Find out if it's Wi-Fi or your ISP.",
        "eyebrow": "By provider",
        "h1": "Why is my internet slow?",
        "lede": "Pick your provider for its typical slowdowns, outage page, equipment, and the steps to try before you call. Every guide starts the same way: finding out whether it's your Wi-Fi or your ISP.",
        "body": f'<div class="related">{cards}</div>',
        "faqs": [],
        "cta": "Know whose fault it is.",
    }


# ---------------------------------------------------------------- Router login pages

def router_page(router):
    full = router["name"]
    name = short(router)
    addresses = router.get("addresses") or []
    if router.get("login") == "app_only":
        login = f'<p>{esc(name)} has no web admin page. You manage it in the {esc(router.get("app") or "app")}.</p>'
    else:
        address_list = ", ".join(f"<code>{esc(a)}</code>" for a in addresses)
        login = (f'<ol class="steps"><li><b>Connect to its network</b> over Wi-Fi or a cable.</li>'
                 f'<li><b>Open a browser and go to</b> {address_list or "its address"}.</li>'
                 f'<li><b>Sign in</b> with the admin password (see below).</li></ol>')
    qos = router.get("qos") or {}
    qos_html = ""
    if qos.get("available") and verified(qos.get("name")):
        qos_html = f'<h2>Smart queueing (fixes lag under load)</h2><p><strong>{esc(qos["name"])}.</strong> {esc(verified(qos.get("note")))}</p><p><a href="/bufferbloat-test">Test for bufferbloat</a> before and after turning it on.</p>'
    elif verified(qos.get("note")):
        qos_html = f'<h2>Smart queueing</h2>{para(qos.get("note"))}'
    find = ADDRESSES[0]["find_steps"]["macos"]
    body = f'''
        <h2>How to log in</h2>
        {login}
        {para(router.get("login_note"))}
        <h2>Username and password</h2>
        {para(router.get("credentials"))}
        <h2>Change the Wi-Fi channel</h2>
        {steps(router.get("channel_steps"))}
        {para(router.get("channel_note"))}
        <p>Not sure which channel? <a href="/how-to-change-wifi-channel">Here's how to pick a quiet one.</a></p>
        <h2>Restart it</h2>
        {steps(router.get("restart_steps"))}
        {qos_html}
        {f"<h2>Firmware updates</h2>{para(router.get('firmware'))}" if verified(router.get("firmware")) else ""}
        <h2>Find your router's address on a Mac</h2>
        {steps(find)}
        {sources(router.get("sources"))}
'''
    return {
        "slug": f'router-login/{router["slug"]}',
        "title": fit(f"{name} Router Login: Address, Password, and Settings", f"{name} Router Login: Address and Password",
                     f"{name} Router Login"),
        "description": fit(
            f"How to log in to your {name} router, find its password, change the Wi-Fi channel, restart it, and turn on smart queueing.",
            f"How to log in to your {name} router, find its password, change the Wi-Fi channel, and restart it.",
            limit=160),
        "eyebrow": "Router login",
        "h1": f"{esc(name)} router login",
        "lede": f"How to get into your {esc(full)} settings, and the three settings that fix most slow Wi-Fi: the channel, a restart, and smart queueing.",
        "body": body,
        "faqs": [],
        "cta": "See if your router is the slow part.",
    }


def address_page(address):
    by_slug = {r["slug"]: r for r in ROUTERS}
    notes = verified_list(address.get("brand_notes"))
    brand_links = "".join(
        f'<li><a href="/router-login/{s}">{esc(by_slug[s]["name"])}</a></li>' for s in address.get("brands", []) if s in by_slug)
    finds = address["find_steps"]
    ip = address["address"]
    body = f'''
        <h2>How to log in at {esc(ip)}</h2>
        <ol class="steps">
          <li><b>Connect to your router's network</b> over Wi-Fi or a cable. The address only works from inside your network.</li>
          <li><b>Type <code>http://{esc(ip)}</code></b> into your browser's address bar (not the search box).</li>
          <li><b>Sign in</b> with the admin username and password, usually printed on a sticker on the router.</li>
        </ol>
        {para(address.get("notes"))}
        <h2>Routers that use {esc(ip)}</h2>
        {"<ul>" + "".join(f"<li>{esc(n)}</li>" for n in notes) + "</ul>" if notes else ""}
        {f"<p>Brand guides:</p><ul>{brand_links}</ul>" if brand_links else ""}
        <h2>Not loading? Find your router's real address</h2>
        <h3>On a Mac</h3>{steps(finds.get("macos"))}
        <h3>On Windows</h3>{steps(finds.get("windows"))}
        <h3>On an iPhone</h3>{steps(finds.get("iphone"))}
        {sources(address.get("sources"))}
'''
    return {
        "slug": f'router-login/{address["slug"]}',
        "title": f"{ip} Router Login: What It Is and How to Log In",
        "description": f"{ip} is a common router admin address. How to log in, which routers use it, and how to find your router's real address on a Mac, Windows PC, or iPhone.",
        "eyebrow": "Router login",
        "h1": f"{esc(ip)}",
        "lede": f"{esc(ip)} is a private address many routers use for their settings page. Here's how to log in, which routers use it, and what to do if it doesn't load.",
        "body": body,
        "faqs": [],
        "cta": "See your router's address and speed, live.",
    }


def router_hub():
    cards = "".join(
        f'<a href="/router-login/{r["slug"]}"><b>{esc(r["name"])}</b><span>{"App only" if r.get("login") == "app_only" else esc(", ".join(r.get("addresses") or []) or "Web admin")}</span></a>'
        for r in ROUTERS)
    addr = "".join(f'<a href="/router-login/{a["slug"]}"><b>{esc(a["address"])}</b><span>Common admin address</span></a>' for a in ADDRESSES)
    return {
        "slug": "router-login",
        "title": "Router Login Guides: Addresses and Passwords by Brand",
        "description": "How to log in to your router: admin addresses and passwords for Xfinity, Spectrum, AT&T, Verizon, eero, Netgear, TP-Link, Asus, Linksys, and common IPs.",
        "eyebrow": "Router login",
        "h1": "How to log in to your router",
        "lede": "Find your router's admin page, where its password lives, and how to change the settings that fix most slow Wi-Fi.",
        "body": f'<h2>By brand</h2><div class="related">{cards}</div><h2>By address</h2><div class="related">{addr}</div>',
        "faqs": [],
        "cta": "See if your router is the slow part.",
    }


def channel_brands():
    blocks = []
    for r in ROUTERS:
        body = steps(r.get("channel_steps"))
        if body:
            blocks.append(f'<h3><a href="/router-login/{r["slug"]}">{esc(r["name"])}</a></h3>{body}{para(r.get("channel_note"))}')
    return "\n".join(blocks)


def restart_brands():
    blocks = []
    for i in ISPS:
        body = steps(i.get("restart_steps"))
        if body:
            blocks.append(f'<h3><a href="/{isp_slug(i)}">{esc(short(i))}</a></h3>{body}')
    return "\n".join(blocks)


def pages():
    return ([isp_page(i) for i in ISPS] + [isp_hub()]
            + [router_page(r) for r in ROUTERS] + [address_page(a) for a in ADDRESSES] + [router_hub()])
