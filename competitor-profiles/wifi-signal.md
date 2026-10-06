# WiFi Signal (Intuitibits / Adrian Granados)

Researched 2026-10-06 from primary sources. Anything not confirmed in a primary source is marked **UNVERIFIED**.

## What it is
A menu bar app that shows your current Wi-Fi connection details and monitors its signal quality, with notifications and an event log. [1][2]
Who it's for: Mac users and Wi-Fi-savvy people who want a better Wi-Fi readout than macOS's built-in menu item, for example on multi-AP or mesh networks. [3]

## Price and where sold
- **US$4.99 one-time, Mac App Store.** Family Sharing is supported. [3][4]
- The product page links only to the Mac App Store. [1] Direct sale or Setapp: **UNVERIFIED / not found**.
- No free tier or trial found.

## Latest version
- **4.5.3, released 2026-09-07/08** (Sep 7 in the release notes, Sep 8 in the App Store metadata, likely a timezone difference). It improves detection of hidden menu bar icons to cut false warnings. [5][4]
- 4.5 (2026-04-07) added AP-name support for Alta, Cisco, Meter and Ubiquiti and dropped macOS 12 and earlier. [5]
- Requires **macOS 13.5 or later** and a **built-in Wi-Fi adapter**. External adapters are not supported. [2][3]

## Features vs WiFi or ISP's areas
| Area | WiFi Signal |
|---|---|
| Signal / noise readout | Yes, its core job. Real-time graphs for signal strength, noise, SNR, data rate or MCS index, shown in dBm or %, with a quality rating from SNR bands (>40 dB Excellent ... <11 dB Very Poor). [2][6][7] |
| Background logging / history | Up to **30 days of event logs**: join, roam, rate change, channel change and disconnect. Each entry includes BSSID, SSID, channel, width, signal, noise and SNR. [8] It logs events, not a continuous latency timeline. |
| Latency to router vs internet | **Not a feature.** No ping or latency testing appears in the docs. [2][6][7][8] |
| ISP-vs-Wi-Fi diagnosis | **No.** It only covers the Wi-Fi link. |
| Alerts | Yes. Notifications on join, disconnect, roam to another AP, channel change, transmit rate below a threshold, and signal strength or SNR below a threshold. [9] |
| Speed test | **None.** |
| Bufferbloat / responsiveness | **None.** |
| Export / reports | CSV export of the event log. [8] |
| Menu bar presence | Yes. A fully customizable, multi-line status display in the menu bar, plus a detachable popover. [2][3] |

## What it does better than WiFi or ISP
- A deeper live **radio-level readout**: MCS index, data rate graphs, channel width, and vendor/AP-name resolution for major AP brands. [2][5][7]
- **Annotations** to name individual access points, which also appear in notifications. [2][9]
- A highly customizable menu bar status text (multi-line patterns). [1][2]
- A mature product from a respected Wi-Fi tools vendor (same developer as WiFi Explorer and Airtool). [10]

## Limitations / complaints
- Wi-Fi only. It can't tell whether a slowdown is your ISP, and has no ping, speed test or bufferbloat measurement.
- Built-in adapter only. [3]
- Known issue in 4.5: notifications may not be delivered when reconnecting to a different AP or router. [5]
- App Store reviewers mention false warnings about the menu bar icon being hidden. [3] The 4.5.3 release notes say this has been improved. [5]

## Permissions
- **Location Services: UNVERIFIED for WiFi Signal specifically.** Intuitibits' docs for its sibling app WiFi Explorer say macOS's CoreWLAN hides SSID/BSSID unless Location Services is authorized, so WiFi Signal very likely needs it to show network names and BSSIDs. The WiFi Signal docs don't say so explicitly. [11]
- Admin rights / helper: **none mentioned** in the docs. [2]
- The developer declares no data collected (App Store privacy label). [3]

## Sources
1. https://www.intuitibits.com/products/wifisignal/
2. https://docs.intuitibits.com/wifisignal/about.md
3. https://apps.apple.com/us/app/wifi-signal-status-monitor/id525912054?mt=12
4. https://itunes.apple.com/lookup?id=525912054&country=us (App Store metadata API: $4.99, v4.5.3, 2026-09-08, minOS 13.5)
5. https://www.intuitibits.com/release-notes/wifisignal/ (via https://www.intuitibits.com/3xvw)
6. https://docs.intuitibits.com/wifisignal/monitor-signal-quality.md
7. https://docs.intuitibits.com/wifisignal/general-settings.md
8. https://docs.intuitibits.com/wifisignal/monitor-wifi-events.md
9. https://docs.intuitibits.com/wifisignal/notifications-settings.md
10. https://docs.intuitibits.com/llms.txt
11. https://docs.intuitibits.com/wifiexplorer/frequently-asked-questions.md
