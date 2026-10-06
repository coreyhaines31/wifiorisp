# Comparison pages. Every factual claim about a competitor traces to
# competitor-profiles/<slug>.md (researched 2026-10-06 from primary sources). Keep it honest:
# say what they do better, and never claim something the profile marks UNVERIFIED.

OURS = "Free, source on GitHub"


def _alt(slug, competitor, **page):
    page.update(slug=slug, competitor=competitor, eyebrow=f"{competitor} alternative")
    return page


ALTERNATIVES = [
    _alt(
        "netspot", "NetSpot",
        card="A pro site-survey and heatmap tool. Great for planning, not for watching your connection.",
        title="NetSpot Alternative for Mac: Is It Wi-Fi or Your ISP?",
        description="NetSpot maps Wi-Fi coverage with heatmaps. WiFi or ISP watches your connection and says if a slowdown is Wi-Fi or your ISP. Here's which you need.",
        h1="NetSpot draws your Wi-Fi.<br>WiFi or ISP watches it.",
        lede="NetSpot is a professional site-survey tool: walk your home or office, and it paints a heatmap of where the signal is strong and weak. WiFi or ISP answers a different question: right now, and over the last month, was the slowdown your Wi-Fi or your ISP?",
        tldr="Planning where to put access points? NetSpot is the better tool. Trying to figure out why the internet keeps getting slow, and prove it to your ISP? That's what WiFi or ISP is for, and it's free.",
        table=[
            ("Price", OURS, "Free tier; Pro $389 lifetime or $189/year direct"),
            ("Main job", "Is it Wi-Fi or the ISP?", "Wi-Fi site surveys and heatmaps"),
            ("Runs in the background", "Yes, from the menu bar", "No, it's a windowed app you run"),
            ("Router vs internet, timed together", "Yes", "No; its FAQ suggests a wired test by hand"),
            ("Drop and slowdown history", "Yes, up to 90 days", "Survey projects, not a monitor"),
            ("Report for your ISP", "Yes", "Survey reports and CSV"),
            ("Bufferbloat test", "Yes (IETF responsiveness)", "No"),
            ("Heatmaps and AP planning", "No", "Yes, its specialty"),
            ("Scans nearby networks", "No", "Yes"),
        ],
        body='''
        <h2>At a glance</h2>
        {{TABLE}}
        <p class="source-note">NetSpot details from netspotapp.com and its Mac App Store listing (version 6.0.1, October 2026).</p>

        <h2>What NetSpot does better</h2>
        <p>Heatmaps. Walk through a building and NetSpot shows exactly where coverage drops, and its planning mode predicts where to place access points across multiple floors. It also scans every nearby network, so you can see channel conflicts. If you're designing or fixing Wi-Fi coverage for a space, it's the right tool, and its full features are priced for professionals.</p>

        <h2>What WiFi or ISP does better</h2>
        <p>It never stops watching. From the menu bar, it times your router and the internet at the same moment, every few seconds, and tells you which side is slow. When the internet drops at 2 AM, it writes down when, for how long, and whether your router kept answering, which is the evidence an ISP needs. It also runs a speed test and a bufferbloat test, and it's free.</p>

        <h2>Which one do you need?</h2>
        <ul>
          <li><strong>“The Wi-Fi is bad in the back bedroom.”</strong> NetSpot.</li>
          <li><strong>“The internet keeps getting slow and I don't know why.”</strong> WiFi or ISP.</li>
          <li><strong>Both?</strong> They don't overlap much. Plenty of people would use NetSpot once to place an access point, and WiFi or ISP every day.</li>
        </ul>
''',
        faqs=[
            ("Is NetSpot free?", "There's a free version, and its real-time Inspector mode is free. Heatmaps and full surveys need a paid edition: Pro is $389 lifetime or $189 a year from NetSpot's site."),
            ("Can NetSpot tell if my ISP is the problem?", "Not directly. NetSpot's own guidance is to run a wired baseline over Ethernet and compare. WiFi or ISP does that comparison automatically by timing your router and the internet together."),
            ("Do I need Location access for either app?", "NetSpot requires it for its Inspector and Survey modes. WiFi or ISP only uses it to show your network's name, and works without it."),
        ],
        cta="See whether it's Wi-Fi or your ISP.",
    ),
    _alt(
        "pingkit", "PingKit",
        card="The closest app to ours: router and internet latency in the menu bar, with a subscription for the extras.",
        title="PingKit Alternative for Mac: WiFi or ISP Compared",
        description="PingKit and WiFi or ISP both time your router and the internet from the Mac menu bar. An honest comparison of price, macOS support, and bufferbloat tests.",
        h1="PingKit vs WiFi or ISP",
        lede="These two are the closest apps around. Both live in the menu bar, read your Wi-Fi signal, and time your router against the internet. They differ on price, privacy, which Macs they run on, and how they measure lag under load.",
        tldr="PingKit does more beyond Wi-Fi: network device discovery, an iPhone companion, and cloud uptime checks, with key extras behind a subscription. WiFi or ISP is focused, free, source-available, runs on macOS 14, and adds an IETF bufferbloat test with router probes.",
        table=[
            ("Price", OURS, "Free; Guardian $24.99/yr, Guardian Plus $39.99/yr on Mac"),
            ("Minimum macOS", "macOS 14 Sonoma", "macOS 15 Sequoia"),
            ("Router vs internet latency", "Yes, with a plain-language verdict", "Yes, side by side"),
            ("Bufferbloat test", "Yes, IETF responsiveness with router probes", "Lag under load on iPhone with Guardian"),
            ("Speed test", "M-Lab NDT7, on demand", "Yes, including scheduled tests"),
            ("Alerts for 2.4 GHz and weaker roams", "Yes", "Not found"),
            ("Report for your ISP", "Plain-text report and CSV", "PDF report"),
            ("Device discovery on your network", "No", "Yes"),
            ("iPhone companion", "No", "Yes"),
            ("Source code", "Public on GitHub", "Not public"),
            ("Data leaving your Mac", "Only tests you start", "Uptime Watch targets on PingKit's servers; usage counters"),
        ],
        body='''
        <h2>At a glance</h2>
        {{TABLE}}
        <p class="source-note">PingKit details from pingkit.app and the Mac App Store (PingKit Agent 3.1.0, September 2026).</p>

        <h2>What PingKit does better</h2>
        <p>Breadth. PingKit finds and fingerprints the devices on your network and alerts you when a new one joins. It has an iPhone app that can show your Mac's dashboard, scheduled speed tests, uptime checks that keep running from PingKit's servers when your Mac is off, and a toolkit of traceroute, port scans, DNS lookups, and more. If you want a whole home-network dashboard on your phone, PingKit is built for that.</p>

        <h2>What WiFi or ISP does better</h2>
        <ul>
          <li><strong>It runs on macOS 14.</strong> PingKit's Mac Agent needs macOS 15 or later.</li>
          <li><strong>Lag under load on the Mac.</strong> WiFi or ISP runs the IETF responsiveness test and times your router and the internet during it, so it can say whether the lag builds up in your Wi-Fi or past your router.</li>
          <li><strong>Wi-Fi alerts.</strong> It tells you when your Mac falls back to 2.4 GHz or roams to a weaker access point.</li>
          <li><strong>No subscription.</strong> Everything is free, and the source is on GitHub.</li>
          <li><strong>Nothing leaves your Mac</strong> unless you start a test.</li>
        </ul>
''',
        faqs=[
            ("Is PingKit free?", "The Mac Agent is free, including monitoring and alerts. Guardian ($24.99/year) puts your Mac's data on your iPhone and adds history and trends; Guardian Plus ($39.99/year on Mac) adds email and webhook alerts, branded reports, and 90 days of history."),
            ("Does PingKit work on macOS 14?", "No. The PingKit Agent requires macOS 15 Sequoia or later. WiFi or ISP works on macOS 14 Sonoma and later."),
            ("Can I use both?", "Yes. They don't conflict, though running two monitors that both probe your router every few seconds is redundant."),
        ],
        cta="Try the free, focused one.",
    ),
    _alt(
        "istat-menus", "iStat Menus",
        card="A whole-system monitor for the menu bar. It watches your Mac; WiFi or ISP watches your connection.",
        title="iStat Menus Alternative for Wi-Fi: Is It Wi-Fi or ISP?",
        description="iStat Menus monitors your whole Mac. WiFi or ISP tells you whether slow internet is your Wi-Fi or your ISP. How they compare, and why to run both.",
        h1="iStat Menus watches your Mac.<br>WiFi or ISP watches your connection.",
        lede="iStat Menus is the classic menu bar monitor: CPU, memory, disks, sensors, bandwidth, weather. It can ping and alert you when the internet goes down. What it doesn't do is tell you whose fault a slowdown is.",
        tldr="Keep iStat Menus for your Mac's vitals. Add WiFi or ISP for the question iStat Menus doesn't answer: is the slowdown your Wi-Fi or your ISP? It's free, and it adds a speed test, a bufferbloat test, and a report for your ISP.",
        table=[
            ("Price", OURS, "$11.99 one-time (also on Setapp)"),
            ("Main job", "Is it Wi-Fi or the ISP?", "Whole-Mac monitoring"),
            ("CPU, memory, disks, sensors", "No", "Yes"),
            ("Per-app bandwidth", "No", "Yes"),
            ("Router vs internet, timed together", "Yes", "No; pings one address"),
            ("Internet-down alerts", "Yes", "Yes"),
            ("2.4 GHz and weaker-roam alerts", "Yes", "Not found"),
            ("Speed test", "Yes (M-Lab)", "No"),
            ("Bufferbloat test", "Yes", "No"),
            ("Report for your ISP", "Yes", "No"),
        ],
        body='''
        <h2>At a glance</h2>
        {{TABLE}}
        <p class="source-note">iStat Menus details from bjango.com and the Mac App Store (iStat Menus 7.5, September 2026).</p>

        <h2>What iStat Menus does better</h2>
        <p>Everything about your Mac itself. CPU and GPU load, memory pressure, disk health, temperatures and fans, battery, per-app bandwidth with 28 days of history, and a rules engine that can alert you on almost any of it. It's polished, long-established, and cheap.</p>

        <h2>What WiFi or ISP does better</h2>
        <p>Diagnosis. iStat Menus can ping an address and tell you the internet is down. WiFi or ISP times your router and the internet at the same moment, so it can tell you <em>why</em>: weak signal, a struggling router, or your ISP. It keeps a history of drops with that answer attached, exports it as a report for your ISP, and tests for bufferbloat.</p>

        <h2>Run both</h2>
        <p>They're complementary. iStat Menus for the Mac, WiFi or ISP for the connection. WiFi or ISP takes up one small router icon in the menu bar, and shows a word only when something is wrong.</p>
''',
        faqs=[
            ("Does iStat Menus show Wi-Fi signal strength?", "It shows Wi-Fi connection details in its network menu. WiFi or ISP shows signal in plain words (Excellent to Weak) with the raw dBm a glance away, and logs it over time."),
            ("Is iStat Menus free?", "No. It's $11.99 one-time from Bjango, with a free trial, or included with Setapp. WiFi or ISP is free."),
        ],
        cta="Add the missing diagnosis.",
    ),
    _alt(
        "wifi-explorer", "WiFi Explorer",
        card="A scanner for nearby networks and channels. It sees the airwaves, not your internet.",
        title="WiFi Explorer Alternative: Diagnose Slow Internet",
        description="WiFi Explorer scans nearby networks and channels. WiFi or ISP tells you if slow internet is your Wi-Fi or your ISP, and logs it. How they compare.",
        h1="WiFi Explorer scans the air.<br>WiFi or ISP follows your connection.",
        lede="WiFi Explorer is one of the best tools for seeing every Wi-Fi network around you: channels, widths, overlaps, and configuration problems. It looks at the radio environment. It doesn't look at your internet.",
        tldr="Picking a channel or debugging an access point's configuration? WiFi Explorer. Figuring out why your internet gets slow, and whether it's your Wi-Fi or your ISP? WiFi or ISP, which is free and runs in the background.",
        table=[
            ("Price", OURS, "$19.99; Pro $129.99 direct"),
            ("Scans nearby networks and channels", "No", "Yes, in depth"),
            ("Your own signal and noise", "Yes, logged over time", "Yes, for every network"),
            ("Runs in the background", "Yes, from the menu bar", "No, it's a windowed scanner"),
            ("Router vs internet latency", "Yes", "No"),
            ("Speed test", "Yes", "No"),
            ("Bufferbloat test", "Yes", "No"),
            ("Drop alerts and ISP report", "Yes", "No"),
        ],
        body='''
        <h2>At a glance</h2>
        {{TABLE}}
        <p class="source-note">WiFi Explorer details from intuitibits.com and the Mac App Store (WiFi Explorer 3.6.10, September 2026).</p>

        <h2>What WiFi Explorer does better</h2>
        <p>Seeing the airwaves. It lists every nearby network with its channel, band, width, security, and vendor, graphs the spectrum so you can spot overlap, decodes the details access points broadcast, and flags configuration issues. When the answer to slow Wi-Fi is “move to a quieter channel,” WiFi Explorer shows you which one.</p>

        <h2>What WiFi or ISP does better</h2>
        <p>Your connection, end to end, over time. It times your router and the internet together to say which side is slow, logs drops and slowdowns in the background, alerts you when they happen, and tests speed and bufferbloat. If WiFi or ISP says “WiFi or router,” WiFi Explorer is a great next step for finding a better channel.</p>
''',
        faqs=[
            ("Is WiFi Explorer free?", "No. WiFi Explorer is $19.99 with a short free trial, and WiFi Explorer Pro 3 is $129.99 direct. WiFi or ISP is free."),
            ("Do they work together?", "Yes. Use WiFi or ISP to find out whether the problem is on your side, and WiFi Explorer to pick a less crowded channel if it is."),
        ],
        cta="Find out which side is slow.",
    ),
    _alt(
        "wifi-signal", "WiFi Signal",
        card="A detailed Wi-Fi signal readout for the menu bar. It covers the radio link, not the internet.",
        title="WiFi Signal Alternative for Mac: Signal Plus Is It Your ISP?",
        description="WiFi Signal shows Wi-Fi stats in the menu bar. WiFi or ISP adds router and internet timing, so you know if slow internet is your Wi-Fi or your ISP.",
        h1="WiFi Signal shows your signal.<br>WiFi or ISP shows whose fault it is.",
        lede="WiFi Signal is a well-made menu bar readout of your Wi-Fi link: signal, noise, SNR, data rate, and which access point you're on. It's great at the radio. But a perfect signal doesn't help when the problem is past your router.",
        tldr="WiFi Signal goes deeper on radio stats. WiFi or ISP adds what it can't do: timing your router and the internet to say whether slow internet is your Wi-Fi or your ISP, plus speed and bufferbloat tests and an ISP report. And it's free.",
        table=[
            ("Price", OURS, "$4.99, Mac App Store"),
            ("Signal, noise, SNR in the menu bar", "Yes, in plain words with dBm a glance away", "Yes, highly customizable"),
            ("MCS index and access point names", "No", "Yes"),
            ("Event history", "Signal, latency, drops, roams", "30 days of Wi-Fi events"),
            ("Router vs internet latency", "Yes", "No"),
            ("Is it Wi-Fi or the ISP?", "Yes", "No, Wi-Fi only"),
            ("Speed test", "Yes", "No"),
            ("Bufferbloat test", "Yes", "No"),
        ],
        body='''
        <h2>At a glance</h2>
        {{TABLE}}
        <p class="source-note">WiFi Signal details from intuitibits.com and the Mac App Store (WiFi Signal 4.5.3, September 2026).</p>

        <h2>What WiFi Signal does better</h2>
        <p>Radio detail. It graphs signal, noise, SNR, data rate, and MCS index in real time, lets you design a multi-line menu bar readout, names the access point you're on for major enterprise brands, and alerts you on roams, channel changes, and weak signal. For Wi-Fi professionals, it's a precise instrument.</p>

        <h2>What WiFi or ISP does better</h2>
        <p>It covers the whole path, not just the first hop. A great signal and a slow internet look identical in WiFi Signal. WiFi or ISP times your router and the internet together, says which side is slow in plain language, logs drops with that verdict attached, and gives you a report to send your ISP.</p>
''',
        faqs=[
            ("Can WiFi Signal tell if my ISP is slow?", "No. It only measures the Wi-Fi link between your Mac and the access point. It has no ping, speed test, or internet measurement."),
            ("Is WiFi Signal free?", "No, it's $4.99 on the Mac App Store. WiFi or ISP is free."),
        ],
        cta="See the whole path, free.",
    ),
]

HUB = {
    "title": "WiFi or ISP Alternatives: How It Compares With Mac Wi-Fi Apps",
    "description": "Honest comparisons of WiFi or ISP with NetSpot, PingKit, iStat Menus, WiFi Explorer, and WiFi Signal, including what each does better.",
    "eyebrow": "Compare",
    "h1": "How WiFi or ISP compares",
    "lede": "Most Mac Wi-Fi apps answer one part of the question: how strong is my signal, what's on my channel, how fast is my Mac. WiFi or ISP answers the whole thing, which side is slow, and these pages say honestly where each app is the better choice.",
    "body": '''
        <h2>Comparisons</h2>
{{CARDS}}
        <h2>Why another Wi-Fi app?</h2>
        <p>Because none of the free options answer the question people actually have when the internet gets slow: is this my Wi-Fi, or my ISP? Scanners see the airwaves, signal meters see the first hop, system monitors see the Mac. WiFi or ISP times both sides of your router at the same moment, keeps the history, and hands you the evidence.</p>
''',
    "cta": "Try it free.",
}
