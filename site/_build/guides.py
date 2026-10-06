# Guide pages. Keep advice general and true for any router; don't name settings a brand may not have.

BUFFERBLOAT_WIDGET = '''    <section class="tool">
      <div class="wrap narrow">
        <div class="bb-card">
          <div class="bb-run">
            <button class="pill big" id="bb-start" type="button">Start the test</button>
            <span class="bb-live" id="bb-live" aria-live="polite"></span>
          </div>
          <div class="bb-track"><div class="bb-bar" id="bb-bar"></div></div>
          <p class="bb-status" id="bb-status">Takes about 25 seconds. Close other downloads and video first.</p>
          <div class="bb-result" id="bb-result" hidden>
            <div class="bb-grade" id="bb-grade" data-grade="A">A</div>
            <div>
              <p class="bb-summary" id="bb-summary"></p>
              <dl class="bb-numbers">
                <dt>Idle latency</dt><dd id="bb-idle"></dd>
                <dt>While downloading</dt><dd id="bb-down"></dd>
                <dt>While uploading</dt><dd id="bb-up"></dd>
                <dt>Download speed</dt><dd id="bb-down-rate"></dd>
                <dt>Upload speed</dt><dd id="bb-up-rate"></dd>
              </dl>
            </div>
          </div>
          <p class="bb-note">Runs in your browser against Cloudflare's public speed test servers. Nothing is stored. Uses a few hundred MB on a fast connection.</p>
        </div>
      </div>
    </section>
'''

GUIDES = [
    # ------------------------------------------------------------------ Bufferbloat test
    {
        "slug": "bufferbloat-test",
        "link": "Bufferbloat test",
        "title": "Bufferbloat Test — Free, in Your Browser",
        "description": "Test your connection for bufferbloat: how much lag builds up while it's busy. Free, runs in your browser in 25 seconds, with a grade and how to fix it.",
        "eyebrow": "Free bufferbloat test",
        "h1": "Bufferbloat test",
        "lede": "Speed tests tell you how fast your connection goes. This one tells you how laggy it gets while it's busy, which is why video calls stutter when someone starts a download.",
        "scripts": '\n  <script src="/bufferbloat.js" defer></script>',
        "widget": BUFFERBLOAT_WIDGET,
        "body": '''
        <h2>What is bufferbloat?</h2>
        <p>Every router and modem holds packets in a queue when more arrives than the line can carry. A small queue smooths out bursts. A big one fills up whenever something saturates your connection, like a cloud backup, a game update, or a 4K stream, and every other packet waits in line behind it.</p>
        <p>That wait is <strong>bufferbloat</strong>. Your speed test still looks great, but a video call that needed a reply in 30 ms now waits 300 ms, and it freezes, talks over people, or drops.</p>

        <h2>How to read your grade</h2>
        <p>The grade is based on how much latency rises under load, in whichever direction is worse:</p>
        <ul>
          <li><strong>A+ or A</strong> (under 30 ms added): you won't notice it.</li>
          <li><strong>B</strong> (30 to 60 ms): calls may hiccup during big transfers.</li>
          <li><strong>C</strong> (60 to 200 ms): noticeable lag whenever the connection is busy.</li>
          <li><strong>D or F</strong> (over 200 ms): real-time anything suffers during uploads and downloads.</li>
        </ul>
        <p>Upload bufferbloat is the most common kind on cable and DSL, because upload speeds are smaller and the modem's queue fills faster.</p>

        <h2>How to fix bufferbloat</h2>
        <ol class="steps">
          <li><b>Turn on smart queueing in your router.</b> Look for Smart Queue Management (SQM), “Smart Queues”, or adaptive QoS in its settings. It keeps the queue short by sending traffic slightly slower than your line's maximum.</li>
          <li><b>Set the limits a bit below your real speed.</b> Most SQM settings ask for your download and upload speeds. Use about 90% of what a speed test shows, so the queue forms in your router (where it's managed) instead of in the modem.</li>
          <li><b>No such setting? Your router may be the bottleneck.</b> Many ISP-supplied routers have none. A router with SQM, or one that runs OpenWrt with <code>cake</code>, usually takes a C or D to an A.</li>
          <li><b>Still bad with SQM on? Show your ISP.</b> If the queue is past your equipment, it's theirs to fix. Bring the numbers.</li>
        </ol>

        <h2>Is the queue in your Wi-Fi or past your router?</h2>
        <p>A browser can't see your router, so this test can only say how much lag builds up, not where. The queue can sit in your Wi-Fi (a busy channel or your Mac's own upload), in your router, or in the modem and the ISP's network, and each one has a different fix.</p>
        <p><a href="/">WiFi or ISP</a> for Mac runs the same kind of test, and while the connection is loaded it also times your router and the internet side by side. If the router slows down as much as the internet does, the queue is on your side. If the router stays quick, it's past it.</p>

        <h2>How this test works</h2>
        <p>It measures round trips to Cloudflare at idle, then fills your download with five parallel streams for 10 seconds, then your upload with four, timing round trips over a separate TCP connection the whole time. Cloudflare reports how long it spent on each reply, and that time is subtracted, so the numbers are network round trips. The first two seconds of each phase are skipped while the streams ramp up. Latency is the median, so one slow probe doesn't decide your grade.</p>
''',
        "faqs": [
            ("Is this a speed test?", "Partly. It reports the speeds it reached while loading the connection, but the point is the lag under load. A connection can be fast and still badly bloated."),
            ("Why is my upload grade worse than my download?", "Upload is usually the smaller pipe, so its queue fills sooner. It's also where your own devices queue packets before they reach the router."),
            ("Does Wi-Fi cause bufferbloat?", "It can. A busy Wi-Fi channel or a weak signal adds its own queue between your device and the router. Test on a cable to compare, or use WiFi or ISP, which checks the router and the internet separately."),
            ("How is this different from Apple's networkQuality?", "Both measure responsiveness under load. Apple's tool reports round trips per minute (RPM), and this page reports added milliseconds. WiFi or ISP uses the same IETF method as Apple and adds router probes to show where the queue is."),
        ],
        "cta": "Find out where the lag comes from.",
    },
    # ------------------------------------------------------------------ Why is my Wi-Fi so slow
    {
        "slug": "why-is-my-wifi-so-slow",
        "link": "Why is my Wi-Fi so slow?",
        "title": "Why Is My Wi-Fi So Slow? How to Tell If It's Wi-Fi or Your ISP",
        "description": "Slow Wi-Fi has three usual causes: a weak signal, a busy router, or your ISP. Here's a two-minute way to tell which one it is on a Mac, and the fix for each.",
        "eyebrow": "Guide",
        "h1": "Why is my Wi-Fi so slow?",
        "lede": "Slow internet has three usual suspects: a weak signal, a busy router, or your ISP. They feel exactly the same in a browser. Here's how to tell them apart in two minutes, and what fixes each one.",
        "tldr": "Time a round trip to your router and one to the internet. If the router is slow too, the problem is your Wi-Fi or router. If the router is quick and the internet isn't, it's your ISP.",
        "body": '''
        <h2>First, find out which side is slow</h2>
        <p>Your router is the border. Everything between your device and the router is yours: the signal, the air, the router itself. Everything past it belongs to your ISP. So the fastest diagnosis is to time both sides at the same moment.</p>
        <h3>On a Mac, in Terminal</h3>
        <ol class="steps">
          <li><b>Find your router's address.</b> System Settings → Wi-Fi → Details… next to your network → TCP/IP. It's the number next to Router, often <code>192.168.1.1</code> or <code>10.0.0.1</code>.</li>
          <li><b>Time the router.</b> Run <code>ping -c 20 192.168.1.1</code> (with your router's address). On Wi-Fi it should answer in a few milliseconds, with nothing lost.</li>
          <li><b>Time the internet.</b> Run <code>ping -c 20 1.1.1.1</code>. Under about 50 ms is typical.</li>
          <li><b>Check your signal.</b> Hold Option and click the Wi-Fi icon in the menu bar. RSSI is signal strength: −30 to −60 is strong, −70 is getting weak, −80 is barely usable.</li>
        </ol>
        <h3>What the numbers mean</h3>
        <ul>
          <li><strong>Router slow or losing packets, weak signal:</strong> your Wi-Fi signal.</li>
          <li><strong>Router slow or losing packets, strong signal:</strong> your router or a crowded channel.</li>
          <li><strong>Router fast, internet slow:</strong> your ISP (or your modem).</li>
          <li><strong>Everything fast, still feels slow:</strong> it's probably bufferbloat, lag that only appears while something else uses the connection. <a href="/bufferbloat-test">Test for it here.</a></li>
        </ul>

        <h2>If it's your Wi-Fi signal</h2>
        <ul>
          <li>Move closer, or get walls, floors, and big appliances out of the line between you and the router.</li>
          <li>Put the router up high and near the middle of your home, not in a cabinet or a corner.</li>
          <li>Prefer 5 GHz or 6 GHz when you're close: they're much faster. 2.4 GHz reaches farther but is slower and more crowded.</li>
          <li>For a big or multi-floor home, add a mesh point or a second access point rather than a range extender.</li>
        </ul>

        <h2>If it's your router</h2>
        <ul>
          <li>Restart it. Routers leak memory like any computer, and a restart clears it.</li>
          <li>Change the Wi-Fi channel. In apartments, neighbors' networks crowd the same channels, especially in the evening.</li>
          <li>Update its firmware.</li>
          <li>If it's more than five or six years old, it may simply not keep up with today's speeds and device counts.</li>
        </ul>

        <h2>If it's your ISP</h2>
        <ul>
          <li>Restart the modem (unplug it for 30 seconds).</li>
          <li>Check your ISP's outage page or app.</li>
          <li>Plug a computer straight into the modem with a cable. If it's still slow, you've ruled out your Wi-Fi and router completely.</li>
          <li>Keep a record before you call: when it was slow, for how long, and proof your own network was fine. Support will start with “restart your router” unless you show them that.</li>
        </ul>

        <h2>Slow at certain times of day?</h2>
        <p>Slowdowns every evening usually mean congestion: either your ISP's neighborhood network or the Wi-Fi channels around you. The router-versus-internet test tells you which. Run it when it's slow, not the next morning when everything's fine, or let an app run it in the background so you catch it when it happens.</p>
''',
        "faqs": [
            ("Why is my Wi-Fi slow on one device but fine on others?", "Usually that device's signal: it's farther away, behind a wall, or stuck on 2.4 GHz. Older devices also top out at slower Wi-Fi standards. Check its signal strength first."),
            ("Why is my Wi-Fi slow but the speed test is fine?", "Speed tests measure peak throughput, not lag. If pages and calls feel slow but speed looks fine, check for bufferbloat and for drops, which a 20-second test can easily miss."),
            ("Does restarting the router really help?", "Often, for a while. If you need to do it every few days, the router is struggling (age, firmware, or too many devices) and that's worth fixing for good."),
            ("Will a faster internet plan fix slow Wi-Fi?", "Not if the problem is your signal or your router. A faster plan only helps when the slowdown is past your router. Find out which side it is first."),
        ],
        "cta": "Let your Mac tell you which side it is.",
    },
    # ------------------------------------------------------------------ Internet keeps dropping
    {
        "slug": "internet-keeps-dropping",
        "link": "Internet keeps dropping?",
        "title": "Internet Keeps Dropping? How to Find Out Whose Fault It Is",
        "description": "Internet keeps dropping? Check if your router stays reachable while it's down. How to check on a Mac, fix your side, and get your ISP to fix theirs.",
        "eyebrow": "Guide",
        "h1": "Internet keeps dropping?",
        "lede": "Drops are maddening because they never happen while you're looking, or while your ISP is on the phone. One question settles whose problem it is: while the internet is down, can you still reach your router?",
        "tldr": "If your router keeps answering while the internet is gone, the outage is your ISP's (or your modem's). If the router disappears too, it's your Wi-Fi or router. Catching that needs a log, because drops come and go.",
        "body": '''
        <h2>The one test that settles it</h2>
        <p>Next time it drops, open Terminal and run <code>ping 192.168.1.1</code> (your router's address, from System Settings → Wi-Fi → Details… → TCP/IP), and in a second window <code>ping 1.1.1.1</code>.</p>
        <ul>
          <li><strong>Router answers, internet doesn't:</strong> your home network is fine. The outage is past it, at the modem or the ISP.</li>
          <li><strong>Neither answers:</strong> your Mac lost the router. That's your Wi-Fi signal, interference, or the router itself.</li>
        </ul>
        <p>The catch: you have to be watching when it happens. Drops that last 40 seconds at 2 AM, or every afternoon for a week, need something that checks all the time and writes it down.</p>

        <h2>If your Mac loses the router</h2>
        <ul>
          <li><strong>Weak signal.</strong> At the edge of range, Wi-Fi drops and reconnects. Check signal strength (Option-click the Wi-Fi icon; RSSI below −75 is weak) and move closer or add an access point.</li>
          <li><strong>Roaming between access points.</strong> In mesh or multi-AP homes, a Mac can hop to a farther access point and struggle there. Turning Wi-Fi off and on often moves it back.</li>
          <li><strong>Interference on 2.4 GHz.</strong> Microwaves, Bluetooth, baby monitors, and neighbors all share it. Use 5 or 6 GHz if you can.</li>
          <li><strong>An overheating or overloaded router.</strong> If drops hit every device at once, restart it, give it airflow, and update its firmware.</li>
        </ul>

        <h2>If the router stays up and the internet goes</h2>
        <ul>
          <li>Look at the modem's lights during a drop. A blinking or orange online light means it lost the line.</li>
          <li>Check that coax or phone connections are finger-tight, and that there's no splitter you don't need.</li>
          <li>Restart the modem, and check your ISP's outage page.</li>
          <li>If it keeps happening, it's a line or network problem only your ISP can fix. Get the evidence together first.</li>
        </ul>

        <h2>How to get your ISP to actually fix it</h2>
        <p>Support scripts start with “restart your router” and end with “it's working now.” What moves a ticket forward is a record: the date and time of each drop, how long it lasted, and proof your router was reachable the whole time. Five drops with timestamps get a technician sent out. “It keeps dropping” doesn't.</p>
''',
        "faqs": [
            ("Why does my internet drop at the same time every day?", "Regular drops point to something scheduled or periodic: heavy neighborhood use in the evening, a device on your network that syncs at that hour, or the ISP's equipment. Log a few days to see the pattern."),
            ("Why does only my Mac lose the connection?", "Then it's the Mac's Wi-Fi link, not the internet: its signal, roaming, or the band it's on. Other devices staying online rules out the ISP."),
            ("Is it my modem or my router?", "If the router stays reachable but nothing past it is, look at the modem's lights. A modem that loses its online light is losing the ISP's line."),
        ],
        "cta": "Catch every drop, and who caused it.",
    },
]
