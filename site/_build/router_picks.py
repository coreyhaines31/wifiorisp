"""Router and mesh picks for the wifiorisp.com recommendations page.

Research date: 2026-10-07. Specs come from manufacturer pages and datasheets; real-world
performance comes from independent reviews (RTINGS, Tom's Guide, Tom's Hardware, Dong Knows
Tech, TechRadar, Windows Central). Wirecutter and PCMag could not be fetched during research,
so nothing here is attributed to them.

Prices move constantly (this research ran during Amazon's Prime Big Deal Days), so every price
is approximate and carries the date it was checked. Anything we could not confirm in a source
is marked "UNVERIFIED" in the text and listed in that pick's "unverified" field. Don't drop
those labels when rendering.

Smart-queue policy: only a feature that shapes queues to cut bufferbloat (SQM, fq_codel/cake)
counts. Device-priority QoS (e.g. TP-Link "QoS by Device") is listed as "None (device
priority QoS only)" because it does not fix bufferbloat on its own.

NEEDS fields
  slug, title, summary, picks

PICK fields
  role            "main" | "budget"
  slug, name, maker
  wifi_standard   "Wi-Fi 6" | "Wi-Fi 6E" | "Wi-Fi 7"
  bands           plain text
  mesh            True/False (True = sold as or expandable into a mesh system)
  smart_queue     feature name as the maker labels it, or "None ..."
  price           approximate US price, plain text
  price_checked   ISO date
  why             why it fits this need (one or two sentences)
  downside        one honest downside
  manufacturer_url
  amazon_search   search phrase for Amazon (no ASINs)
  unverified      list of plain-text caveats ([] if none)
  sources         list of URLs backing the claims

GUIDANCE is a list of plain-text buying tips, each ending with its source(s).
"""

CHECKED = "2026-10-07"

# --------------------------------------------------------------------------- sources
RT_BEST_ROUTERS = "https://www.rtings.com/router/reviews/best/wifi-router"
RT_BEST_MESH = "https://www.rtings.com/router/reviews/best/mesh-wifi-system"
RT_BEST_BUDGET = "https://www.rtings.com/router/reviews/best/budget-cheap"
RT_BEST_GAMING = "https://www.rtings.com/router/reviews/best/gaming"
APPLE_WIFI_SPECS = "https://support.apple.com/guide/deployment/dep268652e6c/web"
EERO_SQM = "https://eero.com/support/hc/en-us/articles/360000709886"
EERO_BRIDGE = "https://eero.com/support/articles/what-features-do-i-lose-if-i-put-my-eeros-in-bridge-mode"
EERO_SQM_COMMUNITY = "https://community.eero.com/t/35hytvl/is-smart-queue-management-working-properly-for-bufferbloat"
GL_SQM_DOCS = "https://docs.gl-inet.com/router/en/4/interface_guide/sqm/"
GL_SQM_BLOG = "https://www.gl-inet.com/en-us/blogs/blog/how-to-reduce-bufferbloat-with-sqm-on-glinet-routers"
DECO_AP_MODE = "https://www.tp-link.com/us/support/faq/1842/"
XFINITY_BRIDGE = "https://www.xfinity.com/support/articles/wireless-gateway-enable-disable-bridge-mode"


def _pick(role, slug, name, maker, **kw):
    kw.setdefault("unverified", [])
    kw.setdefault("price_checked", CHECKED)
    return {"role": role, "slug": slug, "name": name, "maker": maker, **kw}


# --------------------------------------------------------------------------- picks
ARCHER_BE550 = _pick(
    "main", "tp-link-archer-be550", "TP-Link Archer BE550", "TP-Link",
    wifi_standard="Wi-Fi 7",
    bands="Tri-band: 2.4 GHz, 5 GHz, 6 GHz",
    mesh=False,
    smart_queue="None (device priority QoS only: \"QoS by Device\")",
    price="About $170 to $250 (list $249.99; often on sale near $170)",
    manufacturer_url="https://www.tp-link.com/us/home-networking/wifi-router/archer-be550/",
    amazon_search="TP-Link Archer BE550",
    sources=[
        "https://www.tp-link.com/us/home-networking/wifi-router/archer-be550/",
        RT_BEST_ROUTERS,
        "https://www.rtings.com/router/reviews/tp-link/archer-be550",
        "https://www.tomshardware.com/networking/routers/grab-an-usd80-discount-on-this-tp-link-wi-fi-7-router-with-five-2-5g-ethernet-ports-limited-time-deal-on-the-archer-be550-nets-a-tri-band-router-with-fast-speeds-to-upgrade-your-home-network",
    ],
)

ARCHER_AX55 = _pick(
    "budget", "tp-link-archer-ax55", "TP-Link Archer AX55", "TP-Link",
    wifi_standard="Wi-Fi 6",
    bands="Dual-band: 2.4 GHz, 5 GHz",
    mesh=False,
    smart_queue="None (device priority QoS only: \"QoS by Device\")",
    price="About $80 to $110",
    manufacturer_url="https://www.tp-link.com/us/home-networking/wifi-router/archer-ax55/",
    amazon_search="TP-Link Archer AX55",
    sources=[
        "https://www.tp-link.com/us/home-networking/wifi-router/archer-ax55/",
        RT_BEST_BUDGET,
        "https://www.rtings.com/router/reviews/tp-link/archer-ax55",
    ],
)

DECO_BE63 = _pick(
    "main", "tp-link-deco-be63", "TP-Link Deco 7 Pro BE63 (BE10000)", "TP-Link",
    wifi_standard="Wi-Fi 7",
    bands="Tri-band: 2.4 GHz, 5 GHz, 6 GHz",
    mesh=True,
    smart_queue="None (device priority QoS only: \"QoS by Device\" / HomeShield QoS)",
    price="About $330 for a 2-pack (list $399.99 to $449.99 depending on retailer)",
    manufacturer_url="https://www.tp-link.com/us/home-networking/deco/deco-be63/",
    amazon_search="TP-Link Deco BE63 2-pack",
    sources=[
        "https://www.tp-link.com/us/home-networking/deco/deco-be63/",
        RT_BEST_MESH,
        "https://www.tomsguide.com/computing/routers/tp-link-deco-be63-review",
        "https://www.tomshardware.com/networking/routers/tp-link-deco-be63-mesh-router-review",
        "https://www.bhphotovideo.com/c/product/1797739-REG/tp_link_deco_be63_2_pack_deco_be63_whole_home.html",
    ],
)

DECO_XE75 = _pick(
    "budget", "tp-link-deco-xe75", "TP-Link Deco XE75 (AXE5400)", "TP-Link",
    wifi_standard="Wi-Fi 6E",
    bands="Tri-band: 2.4 GHz, 5 GHz, 6 GHz",
    mesh=True,
    smart_queue="None (device priority QoS only: \"QoS by Device\" / HomeShield QoS)",
    price="About $150 to $170 for a 2-pack (list $219.99)",
    manufacturer_url="https://www.tp-link.com/us/home-networking/deco/deco-xe75/",
    amazon_search="TP-Link Deco XE75 2-pack",
    sources=[
        "https://www.tp-link.com/us/home-networking/deco/deco-xe75/",
        RT_BEST_MESH,
        "https://slickdeals.net/f/18987556-149-99-2-pack-tp-link-deco-axe5400-tri-band-wifi-6e-mesh-system-deco-xe75-at-amazon",
    ],
    unverified=[
        "RTINGS tested the Costco-only 3-pack variant (Deco XE5300) and says it is the same system as the XE75; we did not find an RTINGS review of the XE75 retail box itself.",
    ],
)

EERO_7 = _pick(
    "main", "eero-7", "eero 7", "eero (Amazon)",
    wifi_standard="Wi-Fi 7",
    bands="Dual-band: 2.4 GHz, 5 GHz (no 6 GHz)",
    mesh=True,
    smart_queue="SQM (eero app: Settings > Advanced networking > SQM; formerly called \"Optimize for Conferencing and Gaming\")",
    price="$169.99 single, $284.99 2-pack, $399.99 3-pack list (single was $144.49 on sale)",
    manufacturer_url="https://eero.com/shop/eero-7",
    amazon_search="eero 7",
    sources=[
        "https://eero.com/shop/eero-7",
        EERO_SQM,
        "https://www.rtings.com/router/reviews/eero/7",
        "https://dongknows.com/eero-7-vs-eero-pro-7-entry-level-wi-fi-7-routers/",
    ],
)

EERO_PRO_7 = _pick(
    "main", "eero-pro-7", "eero Pro 7", "eero (Amazon)",
    wifi_standard="Wi-Fi 7",
    bands="Tri-band: 2.4 GHz, 5 GHz, 6 GHz",
    mesh=True,
    smart_queue="SQM in router mode (not available in bridge mode)",
    price="$299.99 single, $549.99 2-pack, $799.99 3-pack list (single was $224.99 on sale)",
    manufacturer_url="https://eero.com/shop/eero-pro-7",
    amazon_search="eero Pro 7",
    sources=[
        "https://eero.com/shop/eero-pro-7",
        EERO_BRIDGE,
        EERO_SQM,
        "https://www.rtings.com/router/reviews/eero/pro-7",
        "https://dongknows.com/eero-7-vs-eero-pro-7-entry-level-wi-fi-7-routers/",
    ],
)

EERO_6 = _pick(
    "budget", "eero-6", "eero 6", "eero (Amazon)",
    wifi_standard="Wi-Fi 6",
    bands="Dual-band: 2.4 GHz, 5 GHz",
    mesh=True,
    smart_queue="SQM (eero app: Settings > Advanced networking > SQM)",
    price="$89.99 single, $99.99 2-pack (2 routers)",
    manufacturer_url="https://eero.com/shop/eero-6",
    amazon_search="eero 6 mesh wifi",
    sources=[
        "https://eero.com/shop/eero-6",
        EERO_SQM,
        RT_BEST_BUDGET,
        RT_BEST_MESH,
        EERO_SQM_COMMUNITY,
    ],
    unverified=[
        "We found no current independent bufferbloat test of eero's SQM. Older eero community reports (about 2020) said it helped downloads more than uploads.",
    ],
)

FLINT_2 = _pick(
    "main", "gl-inet-flint-2", "GL.iNet Flint 2 (GL-MT6000)", "GL.iNet",
    wifi_standard="Wi-Fi 6",
    bands="Dual-band: 2.4 GHz, 5 GHz",
    mesh=False,
    smart_queue="SQM (web Admin Panel: FLOW CONTROL > SQM, firmware 4.9 or newer; cake queue discipline)",
    price="$169.99 at GL.iNet's US store; often less on sale",
    manufacturer_url="https://www.gl-inet.com/products/gl-mt6000/",
    amazon_search="GL.iNet Flint 2 GL-MT6000",
    sources=[
        "https://www.gl-inet.com/products/gl-mt6000/",
        "https://store-us.gl-inet.com/products/flint-2-gl-mt6000-wi-fi-6-high-performance-home-router",
        GL_SQM_DOCS,
        GL_SQM_BLOG,
        RT_BEST_ROUTERS,
        RT_BEST_GAMING,
        "https://www.rtings.com/router/reviews/gl-inet/flint-2-gl-mt6000",
        "https://forum.gl-inet.com/t/sqm-on-mt6000-flint-2/36314",
    ],
    unverified=[
        "The exact top speed the Flint 2 can shape with SQM on is not published by GL.iNet; forum users report it falls short of multi-gig plans.",
    ],
)

FLINT_3 = _pick(
    "budget", "gl-inet-flint-3", "GL.iNet Flint 3 (GL-BE9300)", "GL.iNet",
    wifi_standard="Wi-Fi 7",
    bands="Tri-band: 2.4 GHz, 5 GHz, 6 GHz",
    mesh=False,
    smart_queue="SQM (web Admin Panel: FLOW CONTROL > SQM, firmware 4.9 or newer)",
    price="$209.99 at GL.iNet's US store",
    manufacturer_url="https://www.gl-inet.com/products/gl-be9300/",
    amazon_search="GL.iNet Flint 3 GL-BE9300",
    sources=[
        "https://www.gl-inet.com/products/gl-be9300/",
        "https://store-us.gl-inet.com/products/flint-3-gl-be9300-tri-band-wi-fi-7-home-router",
        GL_SQM_DOCS,
        "https://www.rtings.com/router/reviews/gl-inet/flint-3-gl-be9300",
        RT_BEST_ROUTERS,
        "https://www.techradar.com/pro/phone-communications/gl-inet-flint-3-wi-fi-7-router-review",
    ],
)

ROAMII_BE_PRO = _pick(
    "main", "msi-roamii-be-pro", "MSI Roamii BE Pro", "MSI",
    wifi_standard="Wi-Fi 7",
    bands="Tri-band: 2.4 GHz, 5 GHz, 6 GHz",
    mesh=True,
    smart_queue="UNVERIFIED (MSI's datasheet lists no SQM or QoS feature)",
    price="About $300 for a 2-pack (list $349.99; $299.99 at Amazon)",
    manufacturer_url="https://us.msi.com/Networking/Roamii-BE-Pro-Mesh-System",
    amazon_search="MSI Roamii BE Pro mesh",
    sources=[
        "https://storage-asset.msi.com/datasheet/networking/uk/Roamii-BE-Pro-Mesh-System-EU.pdf",
        "https://www.tomsguide.com/computing/routers/msi-roamii-be-pro-review",
        "https://dongknows.com/best-wi-fi-7-mesh-systems/",
    ],
    unverified=[
        "The US product page (us.msi.com) blocked automated fetches; specs come from MSI's published datasheet (EU edition).",
        "Whether the Roamii BE Pro offers any QoS or smart-queue setting.",
    ],
)

DECO_X55 = _pick(
    "main", "tp-link-deco-x55", "TP-Link Deco X55 (AX3000) 3-pack", "TP-Link",
    wifi_standard="Wi-Fi 6",
    bands="Dual-band: 2.4 GHz, 5 GHz",
    mesh=True,
    smart_queue="None (device priority QoS only)",
    price="About $150 for a 3-pack (Amazon; recent range about $133 to $170)",
    manufacturer_url="https://www.tp-link.com/us/home-networking/deco/deco-x55/",
    amazon_search="TP-Link Deco X55 3-pack",
    sources=[
        "https://www.tp-link.com/us/home-networking/deco/deco-x55/",
        "https://www.windowscentral.com/tp-link-deco-x55-mesh-system-review",
        "https://www.techradar.com/pro/this-tp-link-deco-x55-wi-fi-6-mesh-system-is-a-usd150-dead-zone-eliminator-if-youre-upgrading-your-home-office",
        "https://camelcamelcamel.com/product/B09PRB1MZM",
    ],
    unverified=[
        "None of RTINGS, Tom's Guide, or Dong Knows Tech had a review of the Deco X55 we could find; performance claims rest on Windows Central and Consumer NZ.",
    ],
)

ARCHER_AX10 = _pick(
    "budget", "tp-link-archer-ax10", "TP-Link Archer AX10 (AX1500)", "TP-Link",
    wifi_standard="Wi-Fi 6",
    bands="Dual-band: 2.4 GHz, 5 GHz",
    mesh=False,
    smart_queue="None (device priority QoS only: \"QoS by Device\")",
    price="About $60 to $75 (UNVERIFIED: current US price not confirmed)",
    manufacturer_url="https://www.tp-link.com/us/home-networking/wifi-router/archer-ax10/",
    amazon_search="TP-Link Archer AX10",
    sources=[
        "https://www.tp-link.com/us/home-networking/wifi-router/archer-ax10/",
        RT_BEST_BUDGET,
        "https://www.rtings.com/router/reviews/tp-link/archer-ax10",
    ],
    unverified=["Current US street price."],
)


def _with(pick, **overrides):
    return {**pick, **overrides}


NEEDS = [
    {
        "slug": "apartment",
        "title": "Apartment or small home",
        "summary": (
            "One good router in a central spot covers most apartments. Your neighbors' Wi-Fi is "
            "the bigger problem than distance, so a router that can use the less crowded DFS "
            "channels and, ideally, the 6 GHz band helps more than raw range."
        ),
        "picks": [
            _with(
                ARCHER_BE550,
                why=(
                    "RTINGS' mid-range pick: a tri-band Wi-Fi 7 router whose 6 GHz band sidesteps "
                    "crowded apartment channels, with all five Ethernet ports at 2.5 Gbps. It is easy "
                    "to set up from TP-Link's app or a web page."
                ),
                downside=(
                    "Its 5 GHz range is its weak spot, per RTINGS; fine for an apartment, but a "
                    "bigger home may need a mesh add-on."
                ),
            ),
            _with(
                ARCHER_AX55,
                why=(
                    "RTINGS' best budget router: it can fill a plan up to about 750 Mbps up close and "
                    "holds speed out to nearly 100 feet, which is plenty for most apartments."
                ),
                downside=(
                    "Wi-Fi 6 only, so a Mac with Wi-Fi 6E or 7 can't use the faster, less crowded "
                    "6 GHz band."
                ),
            ),
        ],
    },
    {
        "slug": "large-home",
        "title": "Large or multi-floor home",
        "summary": (
            "If one router leaves dead zones, a mesh system puts a second (or third) unit closer "
            "to you. Start with two units and add one only if a room is still weak. Wire the units "
            "together with Ethernet if you can."
        ),
        "picks": [
            _with(
                DECO_BE63,
                why=(
                    "RTINGS' best mesh system: tri-band Wi-Fi 7 that kept gigabit-class speeds out to "
                    "about 100 feet in its testing, with four 2.5 Gbps Ethernet ports per unit for "
                    "wired backhaul."
                ),
                downside=(
                    "Device time limits and network antivirus need a paid TP-Link HomeShield "
                    "subscription, and the web interface is too limited to replace the app (RTINGS)."
                ),
            ),
            _with(
                DECO_XE75,
                why=(
                    "RTINGS' value pick for bigger homes: tri-band Wi-Fi 6E with a 6 GHz band, "
                    "impressive range, and speeds up to about 900 Mbps, often for $150 to $170 a pair."
                ),
                downside=(
                    "Each unit has only 1 Gbps Ethernet ports, so it can't pass along a multi-gig "
                    "internet plan."
                ),
            ),
        ],
    },
    {
        "slug": "calls-and-gaming",
        "title": "Video calls and gaming",
        "summary": (
            "Choppy calls and lag spikes while someone else is uploading or streaming are usually "
            "bufferbloat, not slow internet. The fix is Smart Queue Management (SQM), which keeps "
            "your router's queues short. Most routers' \"QoS\" just ranks devices and doesn't fix "
            "it. For competitive gaming, plug in with Ethernet; no router makes Wi-Fi as steady as "
            "a cable."
        ),
        "picks": [
            _with(
                FLINT_2,
                why=(
                    "GL.iNet's firmware has real SQM with the cake algorithm in the regular web "
                    "admin panel, where you set your own speeds, the approach that best fixes "
                    "bufferbloat. RTINGS also rates it a strong all-around and gaming router."
                ),
                downside=(
                    "Turning SQM on turns off hardware acceleration, which lowers top speed, so it "
                    "suits plans under roughly a gigabit better than multi-gig ones. It's also big "
                    "and more technical than an eero."
                ),
            ),
            _with(
                EERO_6,
                why=(
                    "eero's SQM is a single toggle in the app, so it's the easiest way to try smart "
                    "queuing, and a 2-pack costs about $100."
                ),
                downside=(
                    "eero picks the shaping speeds for you, and we found no current independent test "
                    "proving how well it fixes upload bufferbloat (UNVERIFIED). Wireless speeds top "
                    "out around 500 Mbps."
                ),
            ),
        ],
    },
    {
        "slug": "budget",
        "title": "Budget (under about $150)",
        "summary": (
            "Under $150 you're buying Wi-Fi 6, which is still plenty for plans under a gigabit. "
            "Spend on coverage first: a cheap mesh beats a fast router that doesn't reach your "
            "desk."
        ),
        "picks": [
            _with(
                DECO_X55,
                why=(
                    "Three mesh units for about $150 covers a big house that one budget router "
                    "can't, and TP-Link's app makes setup easy. It also supports wired backhaul."
                ),
                downside=(
                    "Wi-Fi 6 with only gigabit ports and no 6 GHz band, and the big outlets we "
                    "rely on haven't tested it (UNVERIFIED performance beyond Windows Central's review)."
                ),
            ),
            _with(
                ARCHER_AX10,
                why=(
                    "RTINGS' best cheap router: about 600 Mbps up close and solid out to about 100 "
                    "feet, fine for an apartment or single-story home."
                ),
                downside=(
                    "No DFS support, so in a crowded apartment building it can't move to the less "
                    "congested channels (RTINGS)."
                ),
            ),
        ],
    },
    {
        "slug": "keep-isp-gateway",
        "title": "Keep your ISP's gateway",
        "summary": (
            "If your ISP requires its own modem-router (or you just don't want to change it), add a "
            "mesh system in bridge or access point mode. The ISP box keeps doing the routing; the "
            "mesh just does the Wi-Fi. Turn off the gateway's own Wi-Fi so the two don't fight."
        ),
        "picks": [
            _with(
                EERO_PRO_7,
                why=(
                    "eero documents a bridge mode in which its TrueMesh Wi-Fi still works, and the "
                    "Pro 7's tri-band Wi-Fi 7 delivered impressive speed and very good range in "
                    "RTINGS' testing."
                ),
                downside=(
                    "In bridge mode you lose SQM, profiles, device blocking, port forwarding, and "
                    "most eero Plus features (eero's own list), so the gateway's limits still apply."
                ),
            ),
            _with(
                EERO_7,
                role="budget",
                why=(
                    "Same bridge-mode support as the Pro 7 at a lower price, with two 2.5 Gbps "
                    "ports and a simple app."
                ),
                downside=(
                    "Dual-band only, with no 6 GHz band; RTINGS found it delivers about 1 Gbps in "
                    "practice despite its 2.5 Gbps ports."
                ),
            ),
        ],
    },
    {
        "slug": "wifi-7-6ghz",
        "title": "Wi-Fi 7 and 6 GHz for newer Macs",
        "summary": (
            "6 GHz is the fast, uncrowded band, but only devices with Wi-Fi 6E or 7 can use it. "
            "Per Apple, that includes MacBook Air from M3 (2024), MacBook Pro 14/16-inch from the "
            "2023 M2 models, MacBook Neo, and recent Mac mini, Mac Studio, and iMac. Wi-Fi 7 is on "
            "the M5 MacBook Air (2026), the M5 Pro/Max MacBook Pro (2026), and the 2026 Mac mini. "
            "Every Mac tops out at 160 MHz channels, so a router's 320 MHz mode won't speed up a Mac. "
            "Check that a \"Wi-Fi 7\" router actually has a 6 GHz band; some don't."
        ),
        "picks": [
            _with(
                ROAMII_BE_PRO,
                why=(
                    "One of the least expensive tri-band Wi-Fi 7 mesh systems, with a 6 GHz band and "
                    "four 2.5 Gbps ports per unit. It's a Tom's Guide Editor's Choice and in Dong "
                    "Knows Tech's top five Wi-Fi 7 mesh systems."
                ),
                downside=(
                    "Sold only as a 2-pack (no single or 3-pack), and it lacks AFC, the feature that "
                    "lets 6 GHz run at higher power for more range (Tom's Guide)."
                ),
            ),
            _with(
                FLINT_3,
                why=(
                    "A tri-band Wi-Fi 7 single router with 6 GHz, five 2.5 Gbps ports, and SQM, for "
                    "about $210. RTINGS rates it good for speeds up to about 2 Gbps."
                ),
                downside=(
                    "Large and bulky, and RTINGS says it's less user-friendly than TP-Link's "
                    "equivalent, with weaker mesh support."
                ),
            ),
        ],
    },
]


GUIDANCE = [
    (
        "Find out where the slowdown is before you buy. If the delay is on your ISP's side, a new "
        "router won't fix it, and a router can never be faster than your internet plan. "
        f"Source: {RT_BEST_ROUTERS}"
    ),
    (
        "Wi-Fi 6E and Wi-Fi 7 only help devices that support them. On a Mac, check Apple's list: "
        "6 GHz arrived on the 2023 M2 MacBook Pro 14/16-inch and the M3 MacBook Air (2024); Wi-Fi 7 "
        "on the M5 MacBook Air and M5 Pro/Max MacBook Pro (2026). Older Macs, including the M1 and "
        f"M2 MacBook Air, stop at Wi-Fi 6 on 5 GHz. Source: {APPLE_WIFI_SPECS}"
    ),
    (
        "Every Mac, even the Wi-Fi 7 ones, uses channels up to 160 MHz, so a router's 320 MHz "
        f"marketing numbers don't apply to Macs. Source: {APPLE_WIFI_SPECS}"
    ),
    (
        "A \"Wi-Fi 7\" label doesn't guarantee a 6 GHz band. Dual-band Wi-Fi 7 routers such as the "
        "eero 7 have only 2.4 and 5 GHz. Sources: https://www.rtings.com/router/reviews/eero/7 , "
        "https://dongknows.com/eero-7-vs-eero-pro-7-entry-level-wi-fi-7-routers/"
    ),
    (
        "Single router or mesh: an apartment or small home usually needs one well-placed router. "
        "Large or multi-floor homes do better with mesh; start with two units and add a third only "
        "if a room stays weak. Each wireless hop between mesh units adds latency, so wire the units "
        f"together with Ethernet when you can. Sources: {RT_BEST_MESH} , {RT_BEST_GAMING}"
    ),
    (
        "For gaming and video calls, a cable beats any router. RTINGS found no Wi-Fi router "
        f"matches a wired connection for latency. Source: {RT_BEST_GAMING}"
    ),
    (
        "Bufferbloat (lag spikes when the connection is busy) is fixed by Smart Queue Management "
        "(SQM), not by ordinary device-priority QoS. SQM works by capping your speed slightly below "
        "your plan (GL.iNet suggests about 90 percent) and can lower peak throughput, especially on "
        f"fast plans. Sources: {GL_SQM_DOCS} , {GL_SQM_BLOG} , {EERO_SQM}"
    ),
    (
        "Check what your ISP allows. Some require their own gateway; in that case, either put the "
        "gateway in bridge mode (Xfinity, for example, documents this, though it disables xFi Pods) "
        "or keep the gateway routing and run your mesh in bridge/access point mode. Don't run two "
        f"routers both doing routing (\"double NAT\"). Sources: {XFINITY_BRIDGE} , {EERO_BRIDGE} , {DECO_AP_MODE}"
    ),
    (
        "Bridge and access point modes switch off features: eero loses SQM, profiles, and most "
        "eero Plus features; Deco loses antivirus, parental controls, port forwarding, and address "
        f"reservation. Sources: {EERO_BRIDGE} , {DECO_AP_MODE}"
    ),
    (
        "Watch for subscriptions. eero locks parental controls and other features behind eero Plus, "
        "and TP-Link Deco puts time limits and antivirus behind HomeShield. Sources: "
        f"https://www.rtings.com/router/reviews/eero/7 , {RT_BEST_MESH}"
    ),
    (
        f"Router prices swing a lot during sales. Prices here were checked on {CHECKED} (during "
        "Amazon's Prime Big Deal Days) and are approximate."
    ),
]
