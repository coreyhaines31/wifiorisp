# iStat Menus (Bjango)

Researched 2026-10-06 from primary sources. Anything not confirmed in a primary source is marked **UNVERIFIED**.

## What it is
An all-in-one menu bar system monitor for the Mac covering CPU, GPU, memory, disks, network, sensors/fans, battery, time and weather. [1][2]
Who it's for: Mac power users who want system stats at a glance. Network monitoring is one module among many, not a Wi-Fi diagnostic tool.

## Price and where sold
- **Direct (Paddle):** Single License **US$11.99**, Family License (up to 5 family members) **US$14.99**, one-time. Upgrades from iStat Menus 6 are US$9.99 (single) and US$12.99 (family). All licenses include 6 months of weather. [3]
- **Mac App Store:** iStat Menus 7 at **$11.99**, plus a weather in-app subscription ($0.99/month or $4.99/year). [4]
- **Setapp:** included in the US$9.99/month subscription. [1]
- 14-day free trial (direct). [1]
- Weather requires a paid weather subscription after the included period. [2][3]

## Latest version
- **Direct: iStat Menus 7.5, released 2026-09-14.** It brings Liquid Glass menus for macOS 27 and a new Astronomy item. Full notes say "More details coming soon." Requires **macOS 11 or later.** [1][5]
- **Mac App Store: 7.30, released 2026-05-27**, requiring **macOS 14 or later**. The App Store build trails the direct build. [4][6]

## Features vs WiFi or ISP's areas
| Area | iStat Menus |
|---|---|
| Signal / noise readout | It shows Wi-Fi connection info in the network dropdown (added in an earlier major version), Wi-Fi physical mode and channel bandwidth in the Airport sub-menu, and link speed. [5] **Whether RSSI/noise are shown in 7.x: UNVERIFIED** (not stated on current pages). |
| Background logging / history | Yes, for bandwidth. History graphs with ranges from 10 minutes to 28 days (added in 7.0). [5][1] Wi-Fi signal history: **UNVERIFIED**. |
| Latency to router vs internet | It has ping menu bar modes and a ping address/time in the dropdown. [5] The internet status check pings 1.1.1.1, 1.0.0.1 or google.com, or a custom address. [7] Simultaneous router-vs-internet timing: **not found**. |
| ISP-vs-Wi-Fi diagnosis | **No.** |
| Alerts | Yes, and broad. The "Rules" engine can notify when the internet connection is down, the public IP changes, and many other CPU/disk/network/sensor events. [2][8] It can also notify when the Wi-Fi network changes. [5] Alerts for falling to 2.4 GHz or roaming to a weaker AP: **not found**. |
| Speed test | **None found.** |
| Bufferbloat / responsiveness | **None found.** |
| Export / reports | It can import/export settings. [9] Exporting network or Wi-Fi history as a report: **not found**. |
| Menu bar presence | Yes, its core design. Highly customizable menu bar items, including Wi-Fi network-name and interface-icon modes. [5] |

## What it does better than WiFi or ISP
- **Whole-system monitoring**: CPU/GPU, memory, disks with S.M.A.R.T., sensors and fan control, battery and Bluetooth battery levels, clocks and world time, weather. [1][2]
- **Per-app bandwidth breakdown** and long bandwidth history graphs. [1][2]
- A very flexible **Rules** notification engine across every stat. [2][8]
- A long-established, polished product (on version 7, Setapp availability, 30+ languages). [1][5]

## Limitations / complaints
- Not a Wi-Fi diagnostic tool. There is no speed test, no bufferbloat test, no router-vs-internet comparison and no ISP report.
- The App Store version lags behind the direct version. App Store reviewers report v7 bugs (multiple clock/weather locations, history windows, settings import/export), and one says they "uninstalled and gone back to v6." [4]
- Weather costs an ongoing subscription after the included months. [3][4]
- Notifications need specific macOS notification settings for two components (Helper and Menubar). [8]

## Permissions
- **Helper:** the optional **iStat Menus Helper** enables temperatures, fan speeds and other stats. Since 7.0 the app can be installed **without an admin password**, because the helper is optional. [5][10]
- **Location Services:** Bjango's known-issues page refers to a "Request Location Access" button in a menu dropdown, so iStat Menus does request location access. [11] Whether that is for the Wi-Fi network name, weather, or both: **UNVERIFIED**.
- Network requests: it contacts bjango.com/istatmenus.app for updates, weather and public IP, Paddle for purchases, and 1.1.1.1/1.0.0.1/google.com for internet status. [7]

## Sources
1. https://bjango.com/mac/istatmenus/
2. App Store description: https://itunes.apple.com/lookup?id=6499559693&country=us
3. https://bjango.com/mac/istatmenus/ (Buy overlay, rendered 2026-10-06)
4. https://apps.apple.com/us/app/istat-menus-7/id6499559693?mt=12
5. https://bjango.com/mac/istatmenus/versionhistory/
6. https://itunes.apple.com/search?term=istat%20menus&entity=macSoftware&country=us (App Store metadata: $11.99, v7.30, 2026-05-27, minOS 14.0)
7. https://bjango.com/help/istatmenus7/domains/
8. https://bjango.com/help/istatmenus7/rules/
9. https://bjango.com/help/istatmenus7/ (help index lists "Importing and exporting settings")
10. https://bjango.com/help/istatmenus7/helper/
11. https://bjango.com/help/istatmenus7/knownissues/
