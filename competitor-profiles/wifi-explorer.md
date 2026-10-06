# WiFi Explorer / WiFi Explorer Pro 3 (Intuitibits)

Researched 2026-10-06 from primary sources. Anything not confirmed in a primary source is marked **UNVERIFIED**.

## What it is
A Mac Wi-Fi scanner for discovering, monitoring and troubleshooting **nearby wireless networks** with the Mac's built-in adapter. [1][2]
Who it's for: home power users and network admins. WiFi Explorer Pro 3 is aimed at WLAN professionals. [1][3]

## Price and where sold
- **WiFi Explorer: US$19.99 one-time.** Sold direct and on the Mac App Store, with a 3-day free trial. [1][4]
- **WiFi Explorer Pro 3: US$129.99 direct** (Paddle), or US$164.99 bundled with Airtool 2, with a 7-day free trial. [3] The **Mac App Store lists it at US$149.99.** [4]
- Setapp: **UNVERIFIED / not found**.

## Latest version
- **WiFi Explorer 3.6.10, released 2026-09-22** (release notes; App Store metadata shows 2026-09-25). It adds decoding of the Extended BSS Load element and fixes channel-width issues. [5][4]
- **WiFi Explorer Pro 3: 3.10.5**, App Store 2026-09-25. [4]
- Both require **macOS 13.5 or later**. [2][3]

## Features vs WiFi or ISP's areas
| Area | WiFi Explorer |
|---|---|
| Signal / noise readout | Yes, for every nearby network. Signal, noise and SNR-based quality in dBm or %. [2][6] |
| Background logging / history | Saves scan results, including historical data, to a `.wifiexplorer` file while the app runs. It is a foreground scanner, not a background logger. [7] |
| Latency to router vs internet | **Not a feature.** |
| ISP-vs-Wi-Fi diagnosis | **No.** It shows "Issues and recommendations" for network configuration (channel overlap, misconfiguration), but nothing about ISP performance. [1][8] |
| Alerts | **None found.** |
| Speed test | **None.** |
| Bufferbloat / responsiveness | **None.** |
| Export / reports | CSV export of the networks table (all, displayed or selected networks). Graphs can be dragged out as images. [7] |
| Menu bar presence | **None found.** It is a windowed app. |

## What it does better than WiFi or ISP
- **Scans every nearby network**: SSID, BSSID, vendor, channel, band, width up to 320 MHz, security, data rates and streams, across 2.4/5/6 GHz and 802.11a through be (Wi-Fi 7). [1][2]
- **Channel planning**: spectrum graphs and channel conflict/overlap identification. [1]
- **Decodes information elements**, which is useful for debugging AP configuration. [2][5]
- Pro 3 adds remote sensors, external adapters, capture-file import, spectrum-analyzer integration, coloring rules and column profiles. [3]
- Won a Wi-Fi Awards Product of the Year. [1]

## Limitations / complaints
- It shows the radio environment, not your internet. There are no latency, speed or bufferbloat tests and no background history.
- The base app only works with the built-in adapter, because CoreWLAN doesn't recognize USB adapters. [6]
- It can't see client devices on a network. [6]
- Reviews and complaints: **none collected** (no clearly sourced complaints found).

## Permissions
- **Location Services: required.** Without it WiFi Explorer can't scan for or display networks, because macOS CoreWLAN hides SSID/BSSID. Intuitibits says it never determines, saves or shares your location. [6][9]
- Admin rights / helper: **none mentioned** in the docs. [2]

## Sources
1. https://www.intuitibits.com/products/wifiexplorer/
2. https://docs.intuitibits.com/wifiexplorer/about.md
3. https://www.intuitibits.com/products/wifiexplorerpro3/
4. https://itunes.apple.com/search?term=wifi%20explorer&entity=macSoftware&country=us (App Store metadata: WiFi Explorer $19.99 v3.6.10; WiFi Explorer Pro 3 $149.99 v3.10.5)
5. https://www.intuitibits.com/release-notes/wifiexplorer/
6. https://docs.intuitibits.com/wifiexplorer/frequently-asked-questions.md
7. https://docs.intuitibits.com/wifiexplorer/save-and-export-scan-results.md
8. https://docs.intuitibits.com/wifiexplorer/issues-and-recommendations.md (listed in https://docs.intuitibits.com/llms.txt)
9. https://docs.intuitibits.com/wifiexplorer/find-wireless-networks.md
