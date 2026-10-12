# How WiFi or ISP works

This is the method behind the verdicts, for anyone who wants to check it, argue with it, or improve it. Every number here is a constant in `Packages/WiFiOrISPCore`, and the file is named next to each section.

## The idea

Your router is the border between your side of the line and your ISP's. If a round trip to the router is quick and a round trip to the internet, taken at the same moment, is slow, the delay is past the router. If even the router is slow, it's on your side. Measuring both at once matters: two measurements a minute apart can't be compared, because conditions change in seconds.

## Measuring (`Sampler.swift`, `TCPProbe.swift`)

Each sample takes three round trips at the same moment:

- **The router:** a TCP handshake to the router's address. The app tries ports 53, 80, and 443 once per network and keeps the first that answers. A refused connection still counts, because the router replied. If the router ignores every port, it's marked "not measured" and the verdict relies on signal and internet timing.
- **The internet:** TCP handshakes to 1.1.1.1 and 8.8.8.8 on port 443. The faster one counts, so one resolver having a bad moment isn't blamed on your ISP. A probe is lost only if both are.

A TCP handshake is exactly one round trip (SYN out, SYN-ACK back), needs no special privileges, and sends no data. The app doesn't use ICMP ping.

**Wi-Fi details** come from CoreWLAN: signal (RSSI) and noise in dBm, transmit rate, channel, band, channel width, and Wi-Fi generation. The app never scans for nearby networks; scanning is what sent macOS's `airportd` into a request storm for other monitoring apps.

**When it's behind a VPN,** the default route points into the tunnel, so the app uses the router of the Wi-Fi network underneath.

## How often (`PollPolicy.swift`)

| Situation | Sample every |
| --- | --- |
| Something is wrong | 5 s |
| Fine for under 2 minutes | 10 s |
| Fine for 2 to 10 minutes | 20 s |
| Fine for longer | 30 s |

If CoreWLAN stops answering, the app stops asking it and retries after 10, 20, 40 seconds, and so on, up to 5 minutes. It doesn't sample while the Mac sleeps, and for 30 seconds after waking it doesn't count a drop, because Wi-Fi is reconnecting.

## The verdict (`Verdict.swift`)

The verdict looks at the last 6 samples from the last 3 minutes, and needs at least 3.

| Measure | Threshold |
| --- | --- |
| Router is slow | Median round trip over 40 ms, or 25% or more of probes lost |
| ISP side is slow | Internet median more than 100 ms slower than the router's, or 25% or more lost |
| Signal is weak | RSSI −75 dBm or weaker, or signal-to-noise under 15 dB |
| Signal is fair | RSSI −67 dBm or weaker, or signal-to-noise under 25 dB |
| Offline | The last two internet probes were both lost |

Then, in order:

1. **Offline:** if the router was also lost, "can't reach your router" (your side). If the router answered, "ISP is down" (their side). If the router isn't measured, plain "Offline".
2. **Router slow:** with a weak signal, "weak WiFi signal"; otherwise "WiFi or router, not ISP".
3. **ISP side slow:** "ISP, not WiFi" (or "likely ISP" when the router can't be measured).
4. **Otherwise fine,** with a note if the signal is weak enough to cause trouble.

## Drops, roaming, and alerts (`NetworkEvent.swift`)

- **A drop** starts after 2 lost internet probes in a row, and ends at the first reply. The app records whether the router kept answering throughout, which is what puts an outage on the ISP's side in the report.
- **A roam** is a change of access point (BSSID, which needs Location access), or a change of channel on the same network without it. It's "to a weaker access point" when the new signal is at least 6 dB below the old access point's typical level, not just its last reading, which usually dips right before a roam.
- **Falling to 2.4 GHz** is a band change to 2.4 GHz on the same network.

Alerts repeat at most every 5 minutes per kind.

## Next steps and ceilings (`Advice.swift`, `Hardware.swift`)

**Next steps** depend on the verdict and two things the app identifies:

- **Your router's maker**, from the first three bytes of its hardware (MAC) address, read from the Mac's own address table with `arp`. The prefixes come from the IEEE registry (`Scripts/generate-router-makers.py`). Randomized addresses are ignored.
- **Your provider**, from the ASN (network owner) that Cloudflare's speed test endpoint reports for your connection: one small request per network, skipped behind a VPN. Twelve large US providers map to their guides; others get general steps.

**Ceilings** are limits no setting fixes:

| Ceiling | When |
| --- | --- |
| Router older than your Mac | The Mac supports 6 GHz (Wi-Fi 6E or newer) but connects with Wi-Fi 5 or older |
| Wi-Fi slower than your plan | Speed tests reach 55% or more of the Wi-Fi link rate, and the plan is at least 30% faster than the tests |
| Router can't fix lag | The lag test finds the queue past your router, and the router has no smart queueing |
| Plan too small | The plan is below what your household needs (Settings → Your Plan) |
| Getting much less than the plan | Two or more speed tests average under 60% of the plan, and the problem isn't on your side |

Household needs are deliberately rough: 10 Mbps down per person, 25 per 4K stream, 15 more for gaming, 5 for calls (at least 25 total); about 3 Mbps up per person on calls, plus 20 for big uploads (at least 5).

## Speed test (`SpeedTest.swift`)

[M-Lab NDT7](https://www.measurementlab.net/tests/ndt/ndt7/): the app asks M-Lab's locate service for the nearest server, then downloads and uploads over a WebSocket for about 10 seconds each. Upload speed comes from what the server reports receiving. It runs only when you start it, and M-Lab publishes every result as open data.

## Lag under load (`Responsiveness.swift`)

The IETF [Responsiveness under Working Conditions](https://datatracker.ietf.org/doc/draft-ietf-ippm-responsiveness/) test, against Cloudflare's published server (configurable in Settings → Advanced):

1. **Idle:** 5 new-connection probes, plus router and internet handshakes.
2. **Loaded (14 seconds):** downloads and uploads at once, starting with 8 connections and adding more up to 16. Every 200 ms, a new connection is timed (TCP, TLS, and HTTP separately) and a small request rides one of the busy download connections. Every 500 ms, the router and the internet are timed together. The first 4 seconds don't count while the load ramps up.
3. **The score:** responsiveness in round trips per minute, the average of the new-connection and busy-connection scores, each 60,000 divided by a 95% trimmed mean in milliseconds.

Two choices differ from a straightforward implementation, and both matter:

- **New-connection probes and uploads go over TLS on TCP** (Network.framework), not URLSession. URLSession picks HTTP/3 for Cloudflare's server, and QUIC sidesteps the TCP queues the test is meant to find. Our first version read about 4× too optimistic because of it.
- **Router and internet handshakes during the load** show where the queue is. If the router slows down as much as the internet, the lag builds up between your Mac and the router. If the router stays quick, it's past it, in the modem or at the ISP. A router that only slows its own replies, while forwarded traffic doesn't slow, isn't counted.

## What's stored (`LogStore.swift`)

One JSON Lines file per day in `~/Library/Application Support/WiFi or ISP/Log/`, kept 7, 30, or 90 days (Settings → Privacy). Each line is a sample (time, link, Wi-Fi reading, router and internet round trips) or an event (drop, roam, band change, test result). Nothing leaves the Mac unless you export it.

## The website's browser tests

The [bufferbloat test](https://wifiorisp.com/bufferbloat-test) and [ping test](https://wifiorisp.com/ping-test) run in the browser against Cloudflare's speed test server. They probe over HTTP/1.1 (TCP) for the same reason as above, and subtract the processing time Cloudflare reports in its Server-Timing header, so what's left is the network round trip. A browser can't see your router, so they can't say where the lag is; the app can.
