# NetSpot (Etwok Inc)

Researched 2026-10-06 from primary sources. Anything not confirmed in a primary source is marked **UNVERIFIED**.

## What it is
A professional, cross-platform (macOS, Windows, iOS, Android) Wi-Fi site-survey, heatmap, planning and analysis tool. [1]
Who it's for: IT admins, MSPs, consultants, Wi-Fi installers, plus home and small-business users. [1]

## Price and where sold
- **Direct (netspotapp.com, Paddle checkout):** [2]
  - NetSpot Pro (1 user + 1 technician, 50 zones/snapshots per project, 500 data points per snapshot): **US$389 lifetime** (shown struck through from US$599) or **US$189/year**.
  - NetSpot Enterprise (10 users + 10 technicians, unlimited zones and data points): **US$1,399 lifetime** (struck through from US$2,199) or **US$699/year**.
- **Mac App Store:** free download with in-app purchases: **NetSpot Home Edition $45.00**, **NetSpot PRO Edition $289.00**. [3]
- **Free tier:** a free version exists; the Wi-Fi Inspector (real-time analysis) mode is free. [1][3]
- The annual subscription option is new with NetSpot 6 (alongside lifetime licenses). [4]
- Setapp: **UNVERIFIED** (not found).
- Note: App Store and direct prices differ; a Home edition appears only in the App Store listing we saw.

## Latest version
- **NetSpot 6.0.1**, Mac App Store, released 2026-10-03. [3][5]
- NetSpot 6 (major release) shipped 2026-08-19 for macOS and Windows: multi-floor planning, up to 18x faster heatmap generation, live AP placement preview. [4]
- Requires macOS 11 Big Sur or later (supports through macOS 26 Tahoe). [3][6]

## Features vs WiFi or ISP's areas
| Area | NetSpot |
|---|---|
| Signal / noise readout | Yes. Inspector shows SSID, BSSID, signal strength, band for nearby networks; SNR heatmaps in surveys. [1] |
| Background logging / history | Not a background monitor. Data is collected in Inspector sessions and survey projects. Continuous background logging: **UNVERIFIED / not found**. |
| Latency to router vs internet | Not a feature. The speed-test page describes ping/latency inside Active Scanning and iperf3 (LAN) tests, not a simultaneous router-vs-internet timing. [7] |
| ISP-vs-Wi-Fi diagnosis | Manual only. NetSpot's own FAQ says to run a wired baseline over Ethernet, then walk the same path with Active Scanning. [7] |
| Alerts | **UNVERIFIED / none found**. |
| Speed test | "Active Scanning" during a survey measures upload, download and wireless transmit rate over HTTP, TCP or UDP, plus iperf3 for local throughput. NetSpot describes this as local-network testing, with no reference to Ookla or M-Lab. [7] Which edition includes Active Scanning: **UNVERIFIED** (the page points to a PRO trial). |
| Bufferbloat / responsiveness | **Not found**. |
| Export / reports | CSV export from Inspector; heatmap reports; technician users can export reports. [1][8] |
| Menu bar presence | **None found.** It is a windowed app. |

## What it does better than WiFi or ISP
- Visual Wi-Fi **heatmaps** from walk-through site surveys, with 20+ visualization types. [3]
- **Predictive planning** of AP placement, including multi-floor buildings, materials and attenuation. [4]
- **Scans every nearby network** (channel conflicts, interference), across 2.4/5/6 GHz. [3]
- Cross-platform (Windows, iOS, Android) and multi-user team licensing. [1][8]
- In-survey throughput testing via iperf3 to find LAN bottlenecks room by room. [7]

## Limitations / complaints
- Expensive for home users. Full features are paid, and the price is high next to free tools. [2][3]
- One App Store reviewer called it "Scam of a product," saying the free version severely limits functionality and the PRO upgrade is needed for speeds and full heatmaps. [3]
- It is a survey tool, not a monitor. There is no evidence of always-on background logging, drop alerts, or a menu bar readout.

## Permissions
- **Location Services: required** for Inspector and Survey modes, because macOS gates Wi-Fi data behind it. Planning mode doesn't need it. [6][9]
- Admin rights / privileged helper: **UNVERIFIED** (not mentioned in system requirements). [6]

## Sources
1. https://www.netspotapp.com/
2. https://www.netspotapp.com/appstore (rendered pricing cards, fetched 2026-10-06)
3. https://apps.apple.com/us/app/netspot-wifi-analyzer/id514951692?mt=12
4. https://www.netspotapp.com/help/netspot-6-0-with-multi-floor-planning/
5. https://itunes.apple.com/lookup?id=514951692&country=us (App Store metadata API: version 6.0.1, currentVersionReleaseDate 2026-10-03)
6. https://www.netspotapp.com/help/netspot-system-requirements
7. https://www.netspotapp.com/wifi-speed-test/
8. https://www.netspotapp.com/help/types-of-user-levels-in-netspot/
9. https://www.netspotapp.com/help/enable-location-services-netspot/
