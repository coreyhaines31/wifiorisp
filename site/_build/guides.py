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
        "scripts": '\n  <script src="/probe.js" defer></script>\n  <script src="/bufferbloat.js" defer></script>',
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

GUIDES += [
    # ------------------------------------------------------------------ Change Wi-Fi channel
    {
        "slug": "how-to-change-wifi-channel",
        "link": "How to change your Wi-Fi channel",
        "title": "How to Change Your Wi-Fi Channel (and Pick the Best One)",
        "description": "Step-by-step: find a less crowded Wi-Fi channel on a Mac, then change it on Xfinity, Spectrum, AT&T, Verizon, Netgear, TP-Link, Asus, Linksys, and more.",
        "eyebrow": "Guide",
        "h1": "How to change your Wi-Fi channel",
        "lede": "When your signal is strong but Wi-Fi is still slow, a crowded channel is a common culprit, especially in apartments. Here's how to find a quieter one and switch to it on the router you have.",
        "tldr": "On 2.4 GHz, use channel 1, 6, or 11. On 5 GHz, pick the channel your Mac's Wireless Diagnostics scan recommends. Then change it in your router's app or admin page; some routers, like eero and newer Spectrum models, only pick channels automatically.",
        "body": '''
        <h2>When changing the channel helps</h2>
        <p>Wi-Fi networks on the same channel take turns talking. If a dozen neighbors share yours, your router waits, and everything feels slow even with full bars. Signs it's the channel: a strong signal, a slow router response, and slowdowns that get worse in the evening when everyone's home. <a href="/why-is-my-wifi-so-slow">Here's how to check which side is slow first.</a></p>

        <h2>Find the least crowded channel on a Mac</h2>
        <ol class="steps">
          <li><b>Open Wireless Diagnostics.</b> Hold Option, click the Wi-Fi icon in the menu bar, and choose Open Wireless Diagnostics. Skip the assistant that appears.</li>
          <li><b>Scan.</b> From the Window menu, choose Scan, then click Scan Now. You'll see every network around you with its channel.</li>
          <li><b>Read the recommendation.</b> The summary on the left lists the best 2.4 GHz and 5 GHz channels for where you're sitting.</li>
        </ol>

        <h2>Which channel to pick</h2>
        <ul>
          <li><strong>2.4 GHz:</strong> only 1, 6, and 11 don't overlap each other in the US. Use whichever of those three is least busy. Anything in between overlaps two of them.</li>
          <li><strong>5 GHz:</strong> there are many more channels. 36 to 48 and 149 to 165 work with every device. The DFS channels in between are often empty, but the router has to move off them if it detects radar.</li>
          <li><strong>6 GHz:</strong> if your router and Mac both support Wi-Fi 6E or 7, 6 GHz is wide open and rarely crowded.</li>
          <li><strong>Automatic</strong> is fine on most modern routers. Switch to a manual channel only if automatic keeps landing somewhere crowded.</li>
        </ul>

        <h2>How to change it on your router</h2>
        <p>Steps from each maker's own documentation. If yours isn't listed, look for “Wireless,” “Wi-Fi settings,” or “Radio settings” in the admin page or app.</p>
{{CHANNEL_BRANDS}}
        <h2>After you change it</h2>
        <p>Devices reconnect within a few seconds. Give it a day: if slowdowns stop at the times they used to happen, the channel was the problem. If your router keeps answering slowly with a strong signal, the router itself may be overloaded or too old.</p>
''',
        "faqs": [
            ("Is 2.4 GHz or 5 GHz better?", "5 GHz is much faster and less crowded, but it doesn't reach as far through walls. Use 5 GHz (or 6 GHz) when you're reasonably close to the router, and 2.4 GHz only for range."),
            ("Why can't I change the channel on my router?", "Some routers choose channels automatically and don't offer a manual setting, including eero and Spectrum's newer routers, and Cox's Panoramic gateways. They're designed to move to quieter channels on their own; restarting them can prompt a fresh pick."),
            ("Will changing the channel disconnect my devices?", "Briefly. Devices reconnect to the new channel on their own within a few seconds."),
        ],
        "cta": "Know when the channel is the problem.",
    },
    # ------------------------------------------------------------------ Restart router
    {
        "slug": "how-to-restart-router",
        "link": "How to restart your router",
        "title": "How to Restart Your Router and Modem (the Right Way)",
        "description": "The right order to restart a modem and router, how long to wait, how to do it from your ISP's app, and what it means when a restart doesn't fix slow internet.",
        "eyebrow": "Guide",
        "h1": "How to restart your router (the right way)",
        "lede": "Restarting fixes more internet problems than anything else, but the order matters when you have a separate modem and router. Here's how to do it properly, and what to do when it doesn't help.",
        "tldr": "Unplug the modem and the router. Wait a minute. Plug in the modem first and wait two minutes until its lights settle, then plug in the router. If you have a single gateway box, just unplug it for a minute.",
        "body": '''
        <h2>The order that works</h2>
        <ol class="steps">
          <li><b>Unplug both</b> the modem (the box your ISP's cable, fiber, or phone line goes into) and the Wi-Fi router. If it's one combined gateway, unplug that.</li>
          <li><b>Wait at least 60 seconds.</b> It lets the modem drop its session with your ISP so it starts fresh.</li>
          <li><b>Plug in the modem first.</b> Wait about two minutes, until its online or internet light is steady.</li>
          <li><b>Then plug in the router.</b> Give it another two minutes to start Wi-Fi.</li>
          <li><b>Check.</b> Load a few different websites. Better: check that your router <em>and</em> the internet both answer quickly.</li>
        </ol>
        <p>Fiber users: don't touch the fiber cable or the back of the fiber terminal. Restart from power only.</p>

        <h2>Restart from your phone instead</h2>
        <p>Most ISPs let you restart their equipment from an app or your online account, which also runs their own line checks. Steps from each company's documentation:</p>
{{RESTART_BRANDS}}
        <h2>When a restart doesn't fix it</h2>
        <ul>
          <li><strong>Slow again within days:</strong> the router may be overheating, out of date, or overloaded. Update its firmware, give it airflow, or replace it if it's more than five or six years old.</li>
          <li><strong>Still slow right after a restart:</strong> find out which side is slow. If your router answers quickly and the internet doesn't, the problem is past your home, and only your ISP can fix it. <a href="/why-is-my-wifi-so-slow">Here's how to tell.</a></li>
          <li><strong>The internet keeps dropping:</strong> <a href="/internet-keeps-dropping">log the drops</a>, so your ISP can see when and how long.</li>
        </ul>
''',
        "faqs": [
            ("How long should I unplug my router?", "At least 60 seconds. Shorter restarts may not clear the modem's connection with your ISP."),
            ("Is restarting the same as resetting?", "No. Restarting just turns it off and on. Resetting (usually holding a recessed button for several seconds) erases your Wi-Fi name, password, and settings. Don't reset unless support tells you to."),
            ("How often should I restart my router?", "Only when something's wrong. If you need to restart it every few days, that's a sign of a deeper problem worth fixing."),
        ],
        "cta": "Check that the restart actually worked.",
    },
    # ------------------------------------------------------------------ Wi-Fi keeps disconnecting
    {
        "slug": "why-does-my-wifi-keep-disconnecting",
        "link": "Why does my Wi-Fi keep disconnecting?",
        "title": "Why Does My Wi-Fi Keep Disconnecting? 8 Causes and Fixes",
        "description": "Wi-Fi that keeps disconnecting is usually signal, interference, roaming, or the router. Here's how to tell which, and fix it, starting with one quick test.",
        "eyebrow": "Guide",
        "h1": "Why does my Wi-Fi keep disconnecting?",
        "lede": "Wi-Fi that drops and reconnects is different from an internet outage: your device is losing its link to the router itself. That narrows the cause to your side of the line, which is good news, because you can fix it.",
        "tldr": "If your device loses the router itself, it's signal, interference, roaming, or the router. If the router stays connected and the internet goes, it's your ISP. Check which one first.",
        "body": '''
        <h2>First: is it the Wi-Fi or the internet?</h2>
        <p>When it drops, does the Wi-Fi icon lose its bars (or show an exclamation mark), or do the bars stay full while pages stop loading? Lost bars mean the Wi-Fi link. Full bars and no internet usually mean the outage is past your router, and <a href="/internet-keeps-dropping">this guide covers that</a>.</p>

        <h2>The usual causes on your side</h2>
        <h3>1. Weak signal at the edge of range</h3>
        <p>Below about −75 dBm, Wi-Fi gets unreliable and drops under load. Move closer, or add a mesh point or access point. <a href="/wifi-signal-strength">What counts as a good signal.</a></p>
        <h3>2. Interference on 2.4 GHz</h3>
        <p>Microwaves, Bluetooth, baby monitors, and wireless cameras all share 2.4 GHz. If drops line up with the microwave running, that's it. Use 5 or 6 GHz.</p>
        <h3>3. A crowded channel</h3>
        <p>In apartments, too many networks on one channel cause timeouts that look like drops. <a href="/how-to-change-wifi-channel">Switch to a quieter channel.</a></p>
        <h3>4. Roaming between access points</h3>
        <p>With mesh or multiple access points, devices sometimes hop to a farther one with a worse signal, or hop back and forth. Turning Wi-Fi off and on usually lands you on the nearest one.</p>
        <h3>5. Band steering</h3>
        <p>Routers that use one name for 2.4 and 5 GHz move devices between bands. If that causes drops, some routers let you split them into two names.</p>
        <h3>6. The router itself</h3>
        <p>If every device drops at once, the router is the common factor: restart it, update its firmware, and make sure it isn't overheating in a closed cabinet.</p>
        <h3>7. Power saving</h3>
        <p>Some devices put Wi-Fi to sleep aggressively. On a Mac, sleep settings and networks that don't handle sleeping clients well can cause disconnects after the screen turns off.</p>
        <h3>8. Too many devices</h3>
        <p>Older or ISP-supplied routers can struggle with dozens of smart-home devices. If drops started when you added devices, that's a clue.</p>

        <h2>Catch the pattern</h2>
        <p>Drops are hard to fix when you can't see them. A log of when your device lost the router, what the signal was, and whether it had just roamed usually points straight at the cause.</p>
''',
        "faqs": [
            ("Why does my Wi-Fi disconnect at night?", "Often interference or congestion: neighbors' networks are busiest in the evening, and some devices (like a microwave or streaming boxes) are used more. Check whether the drops line up with a weak signal or a busy channel."),
            ("Why does only one device keep disconnecting?", "Then it's that device: its distance from the router, its Wi-Fi hardware, its power-saving settings, or an out-of-date driver or system."),
        ],
        "cta": "See every drop, and why it happened.",
    },
    # ------------------------------------------------------------------ Signal strength
    {
        "slug": "wifi-signal-strength",
        "link": "Wi-Fi signal strength chart",
        "title": "Wi-Fi Signal Strength: What's a Good dBm? (Chart)",
        "description": "What Wi-Fi signal strength numbers mean: a dBm chart from excellent (−30) to unusable (−90), what SNR is, and how to check your signal on a Mac.",
        "eyebrow": "Guide",
        "h1": "Wi-Fi signal strength: what's a good dBm?",
        "lede": "Wi-Fi signal is measured in dBm, a negative number where closer to zero is stronger. Here's what the numbers mean, in plain words.",
        "tldr": "−30 to −55 dBm is excellent, −55 to −67 is good, −67 to −75 is fair, and below −75 dBm is weak enough to cause slowdowns and drops.",
        "body": '''
        <h2>The chart</h2>
        <div class="table-wrap"><table class="compare">
          <thead><tr><th>Signal (dBm)</th><th>In plain words</th><th>What to expect</th></tr></thead>
          <tbody>
            <tr><td>−30 to −55</td><td>Excellent</td><td>Full speed. You're close to the router.</td></tr>
            <tr><td>−55 to −67</td><td>Good</td><td>Fast and reliable for video calls and streaming.</td></tr>
            <tr><td>−67 to −75</td><td>Fair</td><td>Fine for browsing; video calls may stutter.</td></tr>
            <tr><td>−75 to −85</td><td>Weak</td><td>Slow, with dropouts. Time to move closer or add an access point.</td></tr>
            <tr><td>Below −85</td><td>Unusable</td><td>Barely connects, if at all.</td></tr>
          </tbody>
        </table></div>
        <p>The scale is logarithmic: every 3 dB is half (or double) the power, so −70 is a much weaker signal than −60, not a slightly weaker one.</p>

        <h2>Signal isn't the whole story: noise and SNR</h2>
        <p>Your router's signal competes with background radio noise, usually around −90 dBm. What matters is how far the signal rises above it, the signal-to-noise ratio (SNR). Above 25 dB is good; below 15 dB is poor even if the signal number looks fine.</p>

        <h2>How to check your signal on a Mac</h2>
        <ol class="steps">
          <li><b>Hold Option and click the Wi-Fi icon</b> in the menu bar.</li>
          <li><b>Read RSSI and Noise</b> under your network. RSSI is the signal in dBm; subtract Noise from it to get SNR.</li>
        </ol>
        <p>That's a snapshot. Signal changes as you move, as doors close, and as your Mac switches access points, so a log over a day tells you more than one reading.</p>

        <h2>How to improve a weak signal</h2>
        <ul>
          <li>Move the router up high and toward the middle of your home.</li>
          <li>Keep it out of cabinets and away from metal, mirrors, and fish tanks.</li>
          <li>Add a mesh point or access point for distant rooms.</li>
          <li>Use 5 or 6 GHz when you're close; 2.4 GHz reaches farther but is slower.</li>
        </ul>
        <p>A strong signal and slow internet anyway? Then the problem is the router or your ISP. <a href="/why-is-my-wifi-so-slow">Here's how to tell.</a></p>
''',
        "faqs": [
            ("Is −50 dBm good Wi-Fi signal?", "Yes, −50 dBm is excellent. You'll get full speed."),
            ("Is −70 dBm good?", "It's fair: fine for browsing and most streaming, but at the edge for video calls. Below −75 dBm, expect problems."),
            ("Why is my signal strong but Wi-Fi slow?", "A strong signal only covers the link to your router. A crowded channel, a struggling router, or your ISP can still make things slow."),
        ],
        "cta": "Your signal, in plain words, all day.",
    },
    # ------------------------------------------------------------------ Good ping
    {
        "slug": "what-is-a-good-ping",
        "link": "What is a good ping?",
        "title": "What Is a Good Ping? Latency Explained, With a Chart",
        "description": "What a good ping is for browsing, video calls, and gaming, why your router's ping matters, and what jitter and lag under load mean. Plus how to test yours.",
        "eyebrow": "Guide",
        "h1": "What is a good ping?",
        "lede": "Ping, or latency, is how long a round trip takes from your device to a server and back, in milliseconds. Lower is better, and steady matters as much as low.",
        "tldr": "Under 20 ms is excellent, 20 to 50 ms is good, 50 to 100 ms is fine for most things, and over 100 ms is noticeable in calls and games. Your router itself should answer in under 10 ms.",
        "body": '''
        <h2>The chart</h2>
        <div class="table-wrap"><table class="compare">
          <thead><tr><th>Ping to the internet</th><th>Rating</th><th>Good for</th></tr></thead>
          <tbody>
            <tr><td>Under 20 ms</td><td>Excellent</td><td>Everything, including competitive gaming</td></tr>
            <tr><td>20–50 ms</td><td>Good</td><td>Video calls, gaming, streaming</td></tr>
            <tr><td>50–100 ms</td><td>OK</td><td>Browsing and streaming; calls are fine</td></tr>
            <tr><td>100–200 ms</td><td>Slow</td><td>Noticeable delay in calls; games feel laggy</td></tr>
            <tr><td>Over 200 ms</td><td>Poor</td><td>Calls talk over each other; real-time games suffer</td></tr>
          </tbody>
        </table></div>
        <p>Satellite connections are the exception: older geostationary satellite service is around 600 ms by physics, and Starlink is usually much lower.</p>

        <h2>Ping your router, too</h2>
        <p>A round trip to your own router should take a few milliseconds on Wi-Fi, and under 1 ms on a cable. If even your router is slow, the problem is your Wi-Fi or router, and a faster internet plan won't help. If the router is fast and the internet is slow, it's past your home. That one comparison is the fastest way to know <a href="/why-is-my-wifi-so-slow">whether it's your Wi-Fi or your ISP</a>.</p>

        <h2>Jitter: when ping won't sit still</h2>
        <p>Jitter is how much ping varies from one round trip to the next. A steady 60 ms is better for a call than one that bounces between 15 and 150. Under 30 ms of jitter is fine for calls.</p>

        <h2>Lag under load</h2>
        <p>Many connections have a great ping when idle and a terrible one while something's uploading or downloading. That's bufferbloat, and it's why calls stutter during a backup. <a href="/bufferbloat-test">Test it here.</a></p>

        <h2>How to check your ping on a Mac</h2>
        <p>Open Terminal and run <code>ping -c 20 1.1.1.1</code>. The summary line at the end shows the minimum, average, and maximum, plus standard deviation, a rough measure of jitter.</p>
''',
        "faqs": [
            ("Is 30 ms ping good?", "Yes. 30 ms is good for everything, including video calls and most gaming."),
            ("Is 100 ms ping bad?", "It's noticeable in fast games and you may see a slight delay in calls, but browsing and streaming are fine."),
            ("Does Wi-Fi add ping?", "A little, usually a few milliseconds. A weak signal or crowded channel can add much more, and that shows up as a slow ping to your own router."),
        ],
        "cta": "Watch your ping to the router and the internet.",
    },
    # ------------------------------------------------------------------ Mac keeps disconnecting
    {
        "slug": "mac-keeps-disconnecting-from-wifi",
        "link": "Mac keeps disconnecting from Wi-Fi",
        "title": "Mac Keeps Disconnecting From Wi-Fi? How to Fix It",
        "description": "Your Mac keeps dropping Wi-Fi? Check whether it's the Mac or the network, then try these macOS fixes: forget and rejoin, renew DHCP, private address, and more.",
        "eyebrow": "Guide",
        "h1": "Mac keeps disconnecting from Wi-Fi?",
        "lede": "If your Mac drops Wi-Fi while your phone stays connected, the problem is between that Mac and the router. Start with the quick checks, then work through the macOS-specific fixes.",
        "tldr": "Check the signal first (Option-click the Wi-Fi icon). Then forget and rejoin the network, renew its DHCP lease, and try turning off the private Wi-Fi address for that network. If other devices drop too, it's the router or the network, not the Mac.",
        "body": '''
        <h2>Is it the Mac or the network?</h2>
        <p>If your phone and other devices drop at the same moment, it's the router or your internet. <a href="/why-does-my-wifi-keep-disconnecting">Start here instead.</a> If only the Mac drops, keep going.</p>

        <h2>Fixes, in order</h2>
        <ol class="steps">
          <li><b>Check the signal.</b> Option-click the Wi-Fi icon. RSSI weaker than about −75 dBm means the Mac is at the edge of range. Move closer or add an access point.</li>
          <li><b>Forget and rejoin.</b> System Settings → Wi-Fi → the ⋯ button or Details next to the network → Forget This Network. Then join it again.</li>
          <li><b>Renew the DHCP lease.</b> System Settings → Wi-Fi → Details → TCP/IP → Renew DHCP Lease. This fixes connections that look joined but don't pass traffic.</li>
          <li><b>Try without the private Wi-Fi address.</b> In the network's Details, set Private Wi-Fi Address to Off for this network. Some routers and captive portals handle rotating addresses badly.</li>
          <li><b>Disconnect from VPNs and filters</b> to rule them out. Some interfere with reconnects after sleep.</li>
          <li><b>Prefer 5 or 6 GHz.</b> If your router uses separate names for each band, join the 5 GHz one. Bluetooth and other gear crowd 2.4 GHz.</li>
          <li><b>Update macOS.</b> Wi-Fi fixes ship in system updates.</li>
          <li><b>Run Wireless Diagnostics.</b> Option-click the Wi-Fi icon → Open Wireless Diagnostics, and choose to monitor your connection. It runs in the background and saves a report when the connection drops.</li>
        </ol>

        <h2>After sleep only?</h2>
        <p>If the Mac only loses Wi-Fi when it wakes, it's usually reconnecting slowly rather than failing: give it a few seconds. If it truly can't reconnect without toggling Wi-Fi, forget and rejoin the network, and check for a router firmware update.</p>
''',
        "faqs": [
            ("Why does my MacBook keep disconnecting from Wi-Fi but my phone doesn't?", "Something specific to the Mac's link: it's farther from the router, on a different band, using a private address the router handles badly, or running a VPN or filter. Work through the fixes above."),
            ("Does a private Wi-Fi address cause disconnects?", "It can on some networks, especially ones that track devices by address. Turning it off for your home network is safe."),
        ],
        "cta": "Know when your Mac drops, and why.",
    },
    # ------------------------------------------------------------------ Slow at night
    {
        "slug": "internet-slow-at-night",
        "link": "Internet slow at night?",
        "title": "Internet Slow at Night? Here's Why, and How to Fix It",
        "description": "Internet slow every evening? It's usually ISP congestion, crowded Wi-Fi channels, or busy devices at home. Here's how to tell which, and fix it.",
        "eyebrow": "Guide",
        "h1": "Internet slow at night?",
        "lede": "If your internet is fine all day and crawls from about 7 to 11 PM, you're not imagining it. Evening is peak time for everyone around you, and three different things get busy at once.",
        "tldr": "Time your router and the internet when it's slow. If the router is slow too, neighbors' Wi-Fi is crowding your channel, or your own devices are. If the router is fast and the internet isn't, it's your ISP's network congesting at peak hours.",
        "body": '''
        <h2>Three reasons it's slow in the evening</h2>
        <h3>1. Your ISP's network is congested</h3>
        <p>Cable internet in particular shares capacity across a neighborhood. When everyone streams at once, speeds and latency suffer. Your router answers quickly, but the internet doesn't. Only your ISP can fix this, so log the slowdowns and send them the pattern.</p>
        <h3>2. Your Wi-Fi channel is crowded</h3>
        <p>Neighbors' networks get busiest in the evening too. If your signal is strong but even your router answers slowly at night, <a href="/how-to-change-wifi-channel">switch to a quieter channel</a> or move to 5 or 6 GHz.</p>
        <h3>3. Your own household</h3>
        <p>Evening is when streaming, game downloads, backups, and video calls overlap at home. A single big upload can make everything else lag. That's bufferbloat, and smart queueing on your router fixes it. <a href="/bufferbloat-test">Test for it.</a></p>

        <h2>How to tell which one it is</h2>
        <p>Measure while it's slow, not the next morning. Compare a round trip to your router with one to the internet:</p>
        <ul>
          <li><strong>Router slow:</strong> it's your Wi-Fi (channel or signal) or your router.</li>
          <li><strong>Router fast, internet slow, nobody home using much:</strong> your ISP's evening congestion.</li>
          <li><strong>Only slow while someone's uploading or downloading:</strong> bufferbloat.</li>
        </ul>
        <p>A week of evenings, logged, makes the pattern obvious, and gives you something concrete to show your ISP.</p>
''',
        "faqs": [
            ("Why is my internet slow at night but fast in the morning?", "Evening is peak usage for your neighborhood (which strains your ISP's network) and for nearby Wi-Fi networks (which crowd your channel). Compare your router's response with the internet's to see which."),
            ("Will a faster plan fix evening slowdowns?", "Only if the bottleneck is your plan's speed. Neighborhood congestion and Wi-Fi channel crowding don't go away with a faster plan."),
        ],
        "cta": "Catch the evening slowdowns as they happen.",
    },
]

PING_WIDGET = '''    <section class="tool">
      <div class="wrap narrow">
        <div class="bb-card">
          <div class="bb-run">
            <button class="pill big" id="pt-start" type="button">Start the test</button>
            <span class="bb-live" id="pt-live" aria-live="polite"></span>
          </div>
          <svg class="pt-spark" id="pt-spark" viewBox="0 0 300 60" preserveAspectRatio="none" aria-hidden="true"></svg>
          <div class="bb-track"><div class="bb-bar" id="pt-bar"></div></div>
          <p class="bb-status" id="pt-status">Takes about 15 seconds and uses almost no data.</p>
          <div class="bb-result" id="pt-result" hidden>
            <div class="pt-rating" id="pt-rating">Good</div>
            <div>
              <p class="bb-summary" id="pt-summary"></p>
              <dl class="bb-numbers">
                <dt>Ping</dt><dd id="pt-ping"></dd>
                <dt>Jitter</dt><dd id="pt-jitter"></dd>
                <dt>Range</dt><dd id="pt-range"></dd>
                <dt>Didn't come back</dt><dd id="pt-lost"></dd>
              </dl>
            </div>
          </div>
          <p class="bb-note">Times 40 round trips to Cloudflare from your browser, one every quarter second. Nothing is stored.</p>
        </div>
      </div>
    </section>
'''

GUIDES += [
    {
        "slug": "ping-test",
        "link": "Ping and jitter test",
        "title": "Ping and Jitter Test — Free, in Your Browser",
        "description": "Test your ping and jitter in 15 seconds, free in your browser. See your median latency, how steady it is, and what the numbers mean for calls and games.",
        "eyebrow": "Free ping test",
        "h1": "Ping and jitter test",
        "lede": "Ping is how long a round trip takes. Jitter is how much that time jumps around. Together they decide whether video calls and games feel smooth.",
        "scripts": '\n  <script src="/probe.js" defer></script>\n  <script src="/ping.js" defer></script>',
        "widget": PING_WIDGET,
        "body": '''
        <h2>How to read your results</h2>
        <ul>
          <li><strong>Ping</strong> is the median of 40 round trips, so one slow reply doesn't skew it. Under 20 ms is excellent and under 50 ms is good. <a href="/what-is-a-good-ping">More on what counts as a good ping.</a></li>
          <li><strong>Jitter</strong> is the average change from one round trip to the next. Under 10 ms is excellent; over 30 ms makes calls choppy.</li>
          <li><strong>Didn't come back</strong> counts requests with no reply within 2 seconds. A few in a row usually means a dropout.</li>
        </ul>

        <h2>Ping is fine here but calls still lag?</h2>
        <p>This measures an idle connection. Many connections only lag while something else is uploading or downloading. <a href="/bufferbloat-test">Test lag under load.</a></p>

        <h2>Is high ping your Wi-Fi or your ISP?</h2>
        <p>A browser can only time the whole trip to the internet. To know which part is slow, compare it with a round trip to your router. If your router alone takes more than a few milliseconds, the delay is in your Wi-Fi. <a href="/why-is-my-wifi-so-slow">Here's how to check.</a></p>

        <h2>How this test works</h2>
        <p>Your browser requests a zero-byte file from Cloudflare's speed test server 40 times over an existing connection. Each round trip is the time from sending the request to the first byte of the reply, minus the time Cloudflare reports spending on it, so what's left is the network.</p>
''',
        "faqs": [
            ("What's the difference between ping and latency?", "They're used interchangeably. Ping is the name of the classic tool that measures latency, the time for a round trip."),
            ("Is this as accurate as the ping command?", "Close. The ping command uses ICMP; this uses web requests, which is what your apps actually send. Expect results within a few milliseconds of each other."),
            ("Why does my ping change between tests?", "Network conditions shift constantly: other traffic at home, your Wi-Fi signal, and congestion at your ISP. Jitter measures that variation within one test."),
        ],
        "cta": "Watch your ping all day, router and internet.",
    },
]

NEEDS_WIDGET = '''    <section class="tool">
      <div class="wrap narrow">
        <form class="bb-card needs" id="needs-form" onsubmit="return false">
          <h2>How much internet does your home need?</h2>
          <div class="needs-grid">
            <label>People at home <input id="n-people" type="number" min="1" max="12" value="2"></label>
            <label>4K streams at once <input id="n-streams" type="number" min="0" max="8" value="1"></label>
            <label class="check"><input id="n-calls" type="checkbox" checked> Video calls or remote work</label>
            <label class="check"><input id="n-gaming" type="checkbox"> Online gaming</label>
            <label class="check"><input id="n-uploads" type="checkbox"> Big uploads (backups, video, streaming)</label>
          </div>
          <dl class="bb-numbers needs-out">
            <dt>Download</dt><dd id="n-down"></dd>
            <dt>Upload</dt><dd id="n-up"></dd>
          </dl>
          <p class="bb-note" id="n-note"></p>
        </form>
      </div>
    </section>
'''

GUIDES += [
    {
        "slug": "providers",
        "link": "Compare internet providers",
        "title": "How to Compare Internet Providers at Your Address",
        "description": "Work out the speeds your home actually needs, see which providers serve your address, and compare plans on what matters: upload, lag, and the real price.",
        "eyebrow": "Compare providers",
        "h1": "Compare internet providers at your address",
        "lede": "When your plan or provider is the ceiling, switching can fix what no router will. Start from what your home needs, then see who can deliver it where you live.",
        "scripts": '\n  <script src="/needs.js" defer></script>',
        "widget": NEEDS_WIDGET,
        "body": '''
        <h2>See who serves your address</h2>
        <ol class="steps">
          <li><b>Open the FCC's National Broadband Map</b> at <a href="https://broadbandmap.fcc.gov">broadbandmap.fcc.gov</a> and enter your address.</li>
          <li><b>Read the fixed providers list.</b> It shows each provider's technology (fiber, cable, DSL, fixed wireless, satellite) and its fastest advertised speeds.</li>
          <li><b>Confirm with the provider.</b> A listing means the provider told the FCC it <em>can</em> serve your address, not that it already does. Check its site before you count on it.</li>
        </ol>
        <p>We're building a lookup right here that ranks the providers at your address by what your home needs.</p>

        <h2>What to compare</h2>
        <ul>
          <li><strong>Technology first.</strong> Fiber is usually best: fast both ways, low lag, and steady in the evening. Cable is fast downstream but uploads are much slower. 5G home internet varies with the signal at your window. Satellite is the fallback where nothing else reaches.</li>
          <li><strong>Upload speed.</strong> It's what video calls, backups, and livestreams use, and where many plans fall short.</li>
          <li><strong>The real price.</strong> Look at the FCC broadband label every provider must show: the price after the promotion ends, equipment fees, and data caps.</li>
          <li><strong>Lag under load.</strong> Plans don't list it, but it decides whether calls stutter. If a neighbor has the provider, ask them to run our <a href="/bufferbloat-test">bufferbloat test</a>.</li>
        </ul>

        <h2>Before you switch</h2>
        <p>Make sure the provider is the problem. If your router answers slowly, a new provider won't help. WiFi or ISP tells you which side it is, and if you're getting far less than you pay for, its report helps you get that fixed first.</p>
''',
        "faqs": [
            ("How much internet speed do I need?", "A rough guide: 10 Mbps down per person, plus 25 Mbps for each 4K stream, and about 3 Mbps up for each person on a video call. Use the calculator above for your home."),
            ("Is fiber better than cable?", "Usually. Fiber offers the same speed up and down and lower, steadier latency. Cable is fast downstream but uploads are much smaller, and it can slow down in busy evenings."),
            ("What does the FCC map show?", "Which providers say they can serve each location, with technology and maximum advertised speeds. It doesn't show prices, and a listing isn't a guarantee of service."),
        ],
        "cta": "Know whether it's the provider before you switch.",
    },
]
