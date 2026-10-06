#!/usr/bin/env python3
"""Renders the guide and alternative pages from guides.py and alternatives.py,
plus sitemap.xml and the homepage footer links.

    python3 site/_build/render.py
"""
import html
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from alternatives import ALTERNATIVES, HUB  # noqa: E402
from guides import GUIDES  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
SITE = "https://wifiorisp.com"
DOWNLOAD = "https://github.com/coreyhaines31/wifiorisp/releases/latest"
REPO = "https://github.com/coreyhaines31/wifiorisp"
UPDATED = "2026-10-06"
UPDATED_TEXT = "October 6, 2026"
AUTHOR = {"@type": "Person", "name": "Corey Haines", "url": "https://corey.co"}
DOWNLOAD_ICON = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11m-5-5 5 5 5-5M5 20h14"/></svg>'


def esc(text):
    return html.escape(text, quote=True)


def head(title, description, path, scripts=""):
    return f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{esc(title)}</title>
  <meta name="description" content="{esc(description)}">
  <link rel="canonical" href="{SITE}{path}">
  <meta property="og:title" content="{esc(title)}">
  <meta property="og:description" content="{esc(description)}">
  <meta property="og:image" content="{SITE}/images/icon.png">
  <meta property="og:url" content="{SITE}{path}">
  <meta name="theme-color" content="#0b1530">
  <link rel="icon" href="/images/icon.png">
  <link rel="apple-touch-icon" href="/images/icon.png">
  <link rel="stylesheet" href="/site.css">
  <script src="https://cdn.usefathom.com/script.js" data-site="CRTCSZKQ" defer></script>{scripts}
</head>
<body>
  <header class="nav">
    <div class="wrap">
      <a class="brand" href="/"><img src="/images/icon.png" alt=""> WiFi or ISP</a>
      <nav>
        <a href="/#how">How it works</a>
        <a href="/bufferbloat-test">Bufferbloat test</a>
        <a href="{REPO}">GitHub</a>
        <a class="pill" href="{DOWNLOAD}">Download</a>
      </nav>
    </div>
  </header>
'''


def footer_links():
    """Every guide and alternative page, linked from every footer."""
    guides = "".join(f'<a href="/{g["slug"]}">{esc(g["link"])}</a>' for g in GUIDES)
    alts = "".join(f'<a href="/alternatives/{a["slug"]}">{esc(a["competitor"])} alternative</a>' for a in ALTERNATIVES)
    return (f'      <nav class="footer-links" aria-label="Guides">{guides}</nav>\n'
            f'      <nav class="footer-links" aria-label="Alternatives"><a href="/alternatives/">Alternatives</a>{alts}</nav>\n')


def footer():
    return f'''  <footer>
    <div class="wrap">
{footer_links()}      <span>© 2026 Corey Haines · Source available under <a href="{REPO}/blob/main/LICENSE">FSL-1.1-MIT</a></span>
      <span><a href="{REPO}">GitHub</a> · <a href="{REPO}/issues">Report a bug</a> · Also by Corey: <a href="https://midnightoil.app">Midnight Oil</a></span>
    </div>
  </footer>
</body>
</html>
'''


def cta(text):
    return f'''    <section class="cta">
      <div class="wrap">
        <img src="/images/icon.png" alt="" width="96" height="96">
        <h2>{text}</h2>
        <p class="cta-sub">WiFi or ISP is a free Mac menu bar app. It times your router and the internet at the same moment, says which side is slow, and keeps a log you can send your ISP.</p>
        <div class="actions center">
          <a class="pill big" href="{DOWNLOAD}">{DOWNLOAD_ICON}Download free</a>
        </div>
        <p class="fineprint"><code>brew install --cask coreyhaines31/tap/wifiorisp</code></p>
      </div>
    </section>
'''


def faq(items):
    if not items:
        return ""
    rows = "\n".join(f"        <details><summary>{esc(q)}</summary><p>{a}</p></details>" for q, a in items)
    return f'''    <section class="faq">
      <div class="wrap narrow">
        <h2>Questions</h2>
{rows}
      </div>
    </section>
'''


def structured_data(page, path):
    """Article plus FAQ schema, as JSON-LD."""
    graph = [{
        "@type": "Article",
        "headline": html.unescape(page["title"]),
        "description": page["description"],
        "url": f"{SITE}{path}",
        "dateModified": UPDATED,
        "author": AUTHOR,
        "publisher": {"@type": "Organization", "name": "WiFi or ISP", "logo": f"{SITE}/images/icon.png"},
    }]
    if page.get("faqs"):
        graph.append({
            "@type": "FAQPage",
            "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}}
                           for q, a in page["faqs"]],
        })
    data = json.dumps({"@context": "https://schema.org", "@graph": graph}, ensure_ascii=False)
    return f'\n  <script type="application/ld+json">{data}</script>'


def article(page, path):
    tldr = f'<div class="tldr"><h2>The short answer</h2><p>{page["tldr"]}</p></div>' if page.get("tldr") else ""
    scripts = page.get("scripts", "") + structured_data(page, path)
    return (head(page["title"], page["description"], path, scripts)
            + f'''  <main>
    <section class="sub-hero">
      <div class="wrap narrow">
        <p class="eyebrow">{esc(page["eyebrow"])}</p>
        <h1>{page["h1"]}</h1>
        <p class="lede">{page["lede"]}</p>
        <p class="byline">By <a href="https://corey.co">Corey Haines</a>, maker of WiFi or ISP · Updated {UPDATED_TEXT}</p>
        {tldr}
      </div>
    </section>
{page.get("widget", "")}    <section class="article">
      <div class="wrap narrow prose">
{page["body"]}
      </div>
    </section>
{faq(page.get("faqs", []))}{cta(page["cta"])}  </main>
''' + footer())


def table(rows, competitor):
    body = "\n".join(
        f"            <tr><td>{esc(label)}</td><td>{ours}</td><td>{theirs}</td></tr>" for label, ours, theirs in rows)
    return f'''        <div class="table-wrap"><table class="compare">
          <thead><tr><th></th><th>WiFi or ISP</th><th>{esc(competitor)}</th></tr></thead>
          <tbody>
{body}
          </tbody>
        </table></div>'''


def alternative_page(alt):
    page = dict(alt)
    page["body"] = alt["body"].replace("{{TABLE}}", table(alt["table"], alt["competitor"]))
    return article(page, f'/alternatives/{alt["slug"]}')


def hub_page():
    cards = "\n".join(
        f'          <a href="/alternatives/{a["slug"]}"><b>{esc(a["competitor"])}</b><span>{esc(a["card"])}</span></a>'
        for a in ALTERNATIVES)
    page = dict(HUB)
    page["body"] = HUB["body"].replace("{{CARDS}}", f'        <div class="related">\n{cards}\n        </div>')
    return article(page, "/alternatives/")


def write(relative, content):
    path = os.path.join(ROOT, relative)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)


def update_homepage_footer():
    """The homepage is hand-written; keep its footer links between the markers in sync."""
    path = os.path.join(ROOT, "index.html")
    with open(path) as f:
        page = f.read()
    start, end = "<!-- links -->\n", "<!-- /links -->"
    i, j = page.index(start) + len(start), page.index(end)
    with open(path, "w") as f:
        f.write(page[:i] + footer_links() + "      " + page[j:])


def sitemap(paths):
    urls = "\n".join(f"  <url><loc>{SITE}{p}</loc><lastmod>{UPDATED}</lastmod></url>" for p in paths)
    return f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{urls}\n</urlset>\n'


def main():
    paths = ["/"]
    for guide in GUIDES:
        write(f'{guide["slug"]}.html', article(guide, f'/{guide["slug"]}'))
        paths.append(f'/{guide["slug"]}')
    for alt in ALTERNATIVES:
        write(f'alternatives/{alt["slug"]}.html', alternative_page(alt))
        paths.append(f'/alternatives/{alt["slug"]}')
    write("alternatives/index.html", hub_page())
    paths.append("/alternatives/")
    write("sitemap.xml", sitemap(paths))
    write("robots.txt", f"User-agent: *\nAllow: /\nSitemap: {SITE}/sitemap.xml\n")
    update_homepage_footer()
    print(f"Rendered {len(paths) - 1} pages")


if __name__ == "__main__":
    main()
