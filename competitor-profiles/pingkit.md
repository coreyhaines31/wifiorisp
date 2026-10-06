# PingKit (pingkit.app, developer Paul Snyman)

Researched 2026-10-06 from primary sources. Anything not confirmed in a primary source is marked **UNVERIFIED**.

## What it is
An AI-assisted network toolkit for iPhone/iPad (19 free tools), plus a free Mac menu bar companion, **PingKit Agent**, which monitors your network while the Mac is awake and syncs to the iPhone over iCloud. [1][2][3]
Who it's for: home users who want plain-English network troubleshooting, and prosumers/small offices who want device discovery, security scoring and uptime monitoring. [1][3]

**This is the closest competitor to WiFi or ISP.** The Mac Agent pings the gateway and the internet, shows Wi-Fi signal/noise/SNR, logs outages, runs scheduled speed tests and is free.

## Price and where sold
- **Free:** all 19 iOS tools and the Mac Agent, including its tools, monitoring and alerts on the Mac. No ads, no account. [4]
- **Guardian:** $2.99/month or $24.99/year (same on iPhone and Mac). It puts Mac Agent data and history on the iPhone, adds Uptime Watch for 10 URLs, trend charts, scheduled speed test results on the iPhone, and Apple Private Cloud Compute AI. [4]
- **Guardian Plus:** $4.99/month or $39.99/year on Mac ($9.99/month or $79.99/year on iPhone/iPad). It adds email and webhook alerts, a signed ISO 27001 PDF, branded reports and 90 days of history. [4][3]
- 1-week free trial on every paid plan. [4]
- Sold **only on the Apple App Store** (Mac Agent on the Mac App Store). [1][3]

## Latest version
- **PingKit Agent (Mac) 3.1.0, released 2026-09-30.** Requires **macOS 15 Sequoia or later.** [3][5]
- PingKit (iPhone/iPad) 3.1.2, released 2026-10-06, iOS 17+. [5]

## Features vs WiFi or ISP's areas
| Area | PingKit Agent (Mac) |
|---|---|
| Signal / noise readout | Yes. Signal in dBm, noise floor, SNR, channel, band and negotiated transmit rate, read from the Mac's radio. [2][3] |
| Background logging / history | Yes, while the Mac is awake. A network timeline of device joins/leaves, outages and latency spikes. It pauses while the Mac sleeps. [2][6] Longer history (90 days) is a Guardian Plus feature. [3] |
| Latency to router vs internet | Yes. Every 30 s by default (15/30/60 s; slower on battery) it checks the router and 1.1.1.1 and 8.8.8.8. Internet counts as down only if both public servers fail. The menu bar shows gateway and internet latency. [2][6] |
| ISP-vs-Wi-Fi diagnosis | Partly. Gateway vs internet latency is shown side by side. [2] The iPhone "Smart Diagnostics" names a fault location ("Inside your network" vs "Between your router and your ISP"). [7] "Fault localisation" is listed as a Guardian feature. [4] Whether the Mac Agent issues a one-click Wi-Fi-vs-ISP verdict: **UNVERIFIED**. |
| Alerts | Yes. New device, device offline, internet down, latency spikes and speed drops, with configurable thresholds. [2][3] Alerts specifically for falling to 2.4 GHz or roaming to a weaker AP: **not found**. |
| Speed test | Yes, including **scheduled** speed tests on the Mac. It uses six parallel TCP streams. [2][8] **Which server or backend it uses is UNVERIFIED** (not disclosed on the speed test page). |
| Bufferbloat / responsiveness | The iPhone Session Watch measures "lag under load", but only with Guardian. [4] An IETF RPM / responsiveness test: **not found**. On the Mac: **not found**. |
| Export / reports | The Mac Agent's Reports pane can save a PDF with recent timeline events, pitched for ISP tickets. [6] Guardian Plus adds a signed ISO 27001 PDF and branded/scheduled reports. [4] |
| Menu bar presence | Yes. A menu bar-only app (no Dock icon) that launches at login. [2] |

## What it does better than WiFi or ISP
- **LAN device discovery and fingerprinting** (Bonjour, SSDP, WS-Discovery, CoAP and more), new-device alerts, and per-device security scoring. [2][3]
- **iPhone companion**: alerts and (with Guardian) the whole dashboard on your phone via iCloud, plus remote wake/scan. [2][3]
- **Uptime Watch** from PingKit's Cloudflare-hosted backend keeps checking even when the Mac is off. [3][2]
- **Scheduled speed tests** tracked over time. [2]
- A broad toolkit: traceroute, MTR, port scan, DNS, Whois, SSL inspector, Wake-on-LAN and more. [1]
- An AI assistant that explains results in plain language, in 27 languages. [1]

## Limitations / complaints
- **macOS 15+ only**, while WiFi or ISP supports macOS 14+. [3]
- Monitoring stops while the Mac sleeps. [2][6]
- Key conveniences are behind a subscription: iPhone dashboard, longer history, fault localisation, branded reports and lag-under-load on iPhone. [4]
- Some data leaves the device: Uptime Watch and Cert Monitor targets are stored on PingKit's Cloudflare Worker, and its privacy manifest declares a per-device identifier and anonymous usage counters. [2][1] AI questions can go to PingKit's own service as a last resort, after asking permission. [3]
- Not open source (no source repository found). **UNVERIFIED**.
- Public reviews or complaints: **none collected** (the App Store metadata showed no ratings count for the Mac Agent). [5]

## Permissions
- **Local Network access permission: required** (stated on the App Store listing). [3]
- **Location Services: UNVERIFIED.** It is likely needed to read SSID/BSSID on macOS, but PingKit doesn't state it.
- Admin rights / helper: **none mentioned**. It ships through the sandboxed Mac App Store. [3]

## Sources
1. https://pingkit.app/
2. https://pingkit.app/agent/
3. https://apps.apple.com/app/pingkit-agent/id6760315668 (description and release notes via https://itunes.apple.com/lookup?id=6760315668&country=us)
4. https://pingkit.app/pricing/
5. https://itunes.apple.com/search?term=pingkit&entity=macSoftware&country=us and https://itunes.apple.com/search?term=pingkit&entity=software&country=us (App Store metadata API)
6. https://pingkit.app/connection-monitor/
7. https://pingkit.app/smart-diagnostics/
8. https://pingkit.app/speed-test/
