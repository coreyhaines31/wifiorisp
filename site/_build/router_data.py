"""Router login data for the "[brand] router login" and "[address]" pSEO pages.

Research date: 2026-10-06. Sources are manufacturer/ISP support pages, knowledge-base
articles, and PDF user guides. Where only an ISP's own community forum (moderator or
user replies) supported a claim, it is labelled as such. Anything we could not confirm
in a primary source is marked "UNVERIFIED" in the text and listed in that entry's
"unverified" field. Don't drop those labels when rendering.

Credentials policy: never print a default password as a universal fact. Each entry says
where the device prints its own credentials (usually a label) and what the docs say.

ROUTERS fields
  slug, name, kind ("isp" | "consumer")
  addresses       admin IPs/hostnames to type into a browser ([] if none)
  login           "web" | "app_only" | "web_and_app" | "app_preferred"
  login_note      plain-text explanation of how you actually get in
  app             companion app name, or ""
  credentials     where the login is printed / what the docs say
  channel_steps   list of steps (or a single explanatory step if not user-changeable)
  channel_note
  restart_steps   list of steps
  qos             {"available": True/False/None, "name": str, "note": str}
                  None = UNVERIFIED either way
  firmware        plain text
  unverified      list of plain-text caveats
  sources         list of URLs

ADDRESSES fields
  slug, address, title, brands (router slugs), brand_notes, find_steps
  ({"macos": [...], "windows": [...], "iphone": [...]}), notes, sources
"""

ROUTERS = [
    # ------------------------------------------------------------------ ISP gateways
    {
        "slug": "xfinity",
        "name": "Xfinity (Comcast) Gateway",
        "kind": "isp",
        "addresses": ["10.0.0.1"],
        "login": "app_preferred",
        "login_note": (
            "Xfinity recommends the Xfinity app for most people. The Admin Tool at "
            "http://10.0.0.1 still exists, but you must be on your home network, and Xfinity "
            "says Admin Tool access has to be toggled on (from the Xfinity app) before 10.0.0.1 "
            "works. On XB6 and newer gateways, advanced Wi-Fi settings are not shown in the "
            "Admin Tool."
        ),
        "app": "Xfinity app",
        "credentials": (
            "Admin Tool username is admin. Xfinity says to check the sticker on the bottom of "
            "your Xfinity Gateway for the default password, if you haven't changed it."
        ),
        "channel_steps": [
            "XB2 and XB3 gateways only: go to http://10.0.0.1 and sign in.",
            "Go to Gateway > Connection > Wi-Fi.",
            "Click EDIT next to the band you want to change.",
            "Select Manual for Channel Selection, then pick a channel.",
            "Click Save Settings at the bottom of the page.",
        ],
        "channel_note": (
            "On XB6 and newer gateways, Xfinity says Wi-Fi settings are optimized automatically "
            "and advanced Wi-Fi settings cannot be managed from the Admin Tool; Xfinity points "
            "these customers to the Xfinity app instead."
        ),
        "restart_steps": [
            "Xfinity app: tap the WiFi icon, tap Troubleshoot, then Restart your Gateway.",
            "Or unplug the gateway's power cable, wait one minute, and plug it back in.",
            "Xfinity says a restart can take up to 12 minutes, during which your home network is down.",
        ],
        "qos": {
            "available": None,
            "name": "",
            "note": "UNVERIFIED: we found no Xfinity support article describing a user-facing QoS or smart-queue setting.",
        },
        "firmware": (
            "Not user-managed in the docs we found. Xfinity rents and maintains the gateway; "
            "no manual firmware-update path is documented. UNVERIFIED beyond that."
        ),
        "unverified": [
            "QoS / smart queue availability.",
            "Firmware update process (assumed ISP-managed; no Xfinity article found).",
        ],
        "sources": [
            "https://www.xfinity.com/support/articles/change-wifi-channel-admin-tool",
            "https://www.xfinity.com/support/articles/admin-tool-access",
            "https://www.xfinity.com/support/articles/change-wifi-mode-admin-tool-xfinity-xfi",
            "https://www.xfinity.com/support/articles/troubleshooting-your-cable-modem",
        ],
    },
    {
        "slug": "spectrum",
        "name": "Spectrum Router",
        "kind": "isp",
        "addresses": [],
        "login": "app_only",
        "login_note": (
            "Spectrum's support pages direct you to the My Spectrum app or Spectrum.net, signed "
            "in with your Spectrum account, rather than a local admin page. In the app: Services "
            "tab > Your Spectrum Network > Advanced WiFi Settings. Whether current Spectrum "
            "routers expose any local web admin page is UNVERIFIED."
        ),
        "app": "My Spectrum app",
        "credentials": (
            "You sign in with your Spectrum account username and password, not a router admin "
            "password. Spectrum's WiFi 6 Router guide says the router's back label carries the "
            "network name and password and a QR code."
        ),
        "channel_steps": [
            "Spectrum's own guidance is that newer routers pick the channel with the most "
            "capacity automatically; restarting the modem and router makes it re-select the best "
            "available channel.",
        ],
        "channel_note": (
            "We found no Spectrum article offering manual channel selection. Advanced WiFi "
            "Settings in the app covers DNS, UPnP, port forwarding, IP reservation and factory "
            "reset."
        ),
        "restart_steps": [
            "My Spectrum app: Services tab > Internet, choose your equipment, then Restart Equipment.",
            "On the Spectrum WiFi 6 Router, holding the side Reboot button for 4 to 14 seconds "
            "reboots it without erasing your settings (15+ seconds is a factory reset).",
        ],
        "qos": {
            "available": None,
            "name": "",
            "note": "UNVERIFIED: no user-facing QoS feature appears in Spectrum's WiFi 6 Router guide or support pages we found.",
        },
        "firmware": (
            "Automatic. Spectrum's WiFi 6 Router guide lists a light pattern for 'Updating "
            "firmware (device will automatically restart)'; there is no manual update path."
        ),
        "unverified": [
            "Whether any local web admin page (e.g. 192.168.1.1 or 192.168.0.1) exists on current Spectrum-supplied routers.",
            "QoS availability.",
            "The spectrum.net article pages block automated fetching; the app paths above come from spectrum.net search excerpts plus the official PDF user guide.",
        ],
        "sources": [
            "https://www.spectrum.net/support/internet/managing-advanced-settings-my-spectrum-app",
            "https://www.spectrum.net/support/internet/advanced-wifi-advanced-settings",
            "https://www.spectrum.net/support/internet/wifi-router-troubleshooting-0",
            "https://drupal-cms.spectrum.net/sites/default/files/2024-09/20240729%20WiFi%206%20User%20Guide.pdf",
        ],
    },
    {
        "slug": "att",
        "name": "AT&T Wi-Fi Gateway",
        "kind": "isp",
        "addresses": ["192.168.1.254"],
        "login": "web_and_app",
        "login_note": (
            "Basic settings (Wi-Fi name and password, connected devices, restart) are in the AT&T "
            "Smart Home Manager app. Advanced gateway settings are at http://192.168.1.254 from a "
            "device on your network; changes there ask for the Device Access Code."
        ),
        "app": "Smart Home Manager",
        "credentials": (
            "Gateway settings ask for the Device Access Code, which AT&T says is printed on the "
            "label on the side of your gateway. You can change the code later from the gateway "
            "settings page."
        ),
        "channel_steps": [
            "Go to http://192.168.1.254.",
            "Select Home Network, then Wi-Fi.",
            "Enter the Device Access Code from the gateway's label.",
            "Select Advanced Options and scroll to the 2.4 GHz or 5 GHz radio section to set the channel.",
            "Save.",
        ],
        "channel_note": (
            "Path confirmed on AT&T's BGW320 FAQ (Home Network > Wi-Fi > Advanced Options, with "
            "2.4 GHz and 5 GHz radio sections). Which channels you can pick, and whether manual "
            "5 GHz selection is offered, varies by gateway model and firmware (UNVERIFIED per model)."
        ),
        "restart_steps": [
            "Smart Home Manager: select Network (Wi-Fi icon), scroll to Restart Wi-Fi, then select Restart.",
            "Or unplug the power cord from the gateway and the wall (remove the backup battery if "
            "there is one), wait 20 seconds, and plug it back in.",
            "AT&T says it can take up to five minutes to come back online.",
        ],
        "qos": {
            "available": None,
            "name": "",
            "note": "UNVERIFIED: no QoS or smart-queue setting found in AT&T's gateway documentation.",
        },
        "firmware": "Not user-managed in the AT&T docs we found (UNVERIFIED; assumed AT&T-managed).",
        "unverified": [
            "Per-model channel options (especially manual 5 GHz selection).",
            "QoS availability.",
            "Firmware update process.",
        ],
        "sources": [
            "https://www.att.com/support/article/u-verse-high-speed-internet/KM1395833/",
            "https://www.att.com/support/article/u-verse-high-speed-internet/KM1049866/",
            "https://www.att.com/support/article/u-verse-high-speed-internet/KM1010361/",
            "https://www.att.com/support/article/u-verse-high-speed-internet/KM1212976/",
        ],
    },
    {
        "slug": "verizon-fios",
        "name": "Verizon Fios Router",
        "kind": "isp",
        "addresses": ["mynetworksettings.com", "myfiosgateway.com", "192.168.1.1"],
        "login": "web_and_app",
        "login_note": (
            "Basic settings are in My Verizon. The full router interface is at "
            "mynetworksettings.com (Verizon Router CR1000A) or myfiosgateway.com (Fios Router "
            "pages); 192.168.1.1 works for both. Expect a browser 'connection is not private' "
            "warning; Verizon's guide says to proceed to 192.168.1.1."
        ),
        "app": "My Verizon app",
        "credentials": (
            "Username admin. Verizon says the unique default password (the 'Network Settings "
            "password' / admin password) is printed on the label on the back of the router. The "
            "same label lists the default Wi-Fi name, Wi-Fi password and local URL."
        ),
        "channel_steps": [
            "Verizon Router (CR1000A): sign in at mynetworksettings.com.",
            "From the Advanced menu, select Wi-Fi, then Radio Management.",
            "Optionally click Scan to rate channels (Channel Analysis shows a 0-10 congestion score).",
            "Under Channel Settings, pick a channel or leave it on Auto.",
            "To keep a manual channel after a reboot, open Settings on that page and tick "
            "'Keep my channel selection during power cycle', then Apply changes.",
        ],
        "channel_note": "Path is from the Verizon Router CR1000A user guide. Older Fios Router models (e.g. G3100) may differ (UNVERIFIED).",
        "restart_steps": [
            "In the router interface: System > Reboot Router > Reboot Device (Verizon warns to do this only when needed).",
            "Or press and hold the rear Reset button for at least three seconds for a soft reboot. "
            "Holding it ten seconds or more is a factory reset.",
        ],
        "qos": {
            "available": False,
            "name": "Wi-Fi QoS (WMM)",
            "note": (
                "The CR1000A guide lists WMM Wi-Fi QoS and Layer 2/3 QoS support in its specs, "
                "but no consumer smart-queue / bufferbloat setting."
            ),
        },
        "firmware": (
            "Over the air. The CR1000A guide lists a 'Firmware update (FOTA)' light pattern; "
            "no manual update path is described."
        ),
        "unverified": [
            "Channel menu path on older Fios Router models (G3100, G1100).",
        ],
        "sources": [
            "https://www.verizon.com/support/knowledge-base-239713/",
            "https://www.verizon.com/support/residential/internet/equipment/routers/verizon-router",
            "https://www.verizon.com/support/residential/internet/equipment/routers/fios-router/",
            "https://www.verizon.com/content/dam/verizon/support/consumer/documents/internet/verizon-router-guide.pdf",
        ],
    },
    {
        "slug": "cox",
        "name": "Cox Panoramic Wifi Gateway",
        "kind": "isp",
        "addresses": ["192.168.0.1"],
        "login": "app_preferred",
        "login_note": (
            "Cox manages Panoramic Wifi through the Panoramic Wifi app (or wifi.cox.com), signed "
            "in with your Cox account. Cox community-forum moderators describe a limited "
            "diagnostic page at 192.168.0.1 when you're connected to the gateway; we found no "
            "Cox support article documenting it (UNVERIFIED)."
        ),
        "app": "Panoramic Wifi app",
        "credentials": (
            "The app and wifi.cox.com use your Cox account login. For the 192.168.0.1 page, check "
            "the label on the gateway and Cox support; Cox forum replies cite a factory login, but "
            "it is not published in a Cox support article, so we don't repeat it (UNVERIFIED)."
        ),
        "channel_steps": [
            "Not user-changeable. Per Cox forum moderators, Panoramic gateways manage channel "
            "selection, channel width and Wi-Fi mode automatically and scan for the least "
            "congested channel; a restart triggers a fresh scan.",
        ],
        "channel_note": "Source is Cox's official community forum, not a support article (UNVERIFIED).",
        "restart_steps": [
            "Panoramic Wifi app: Overview tab > Connection Trouble > Restart Gateway (can take several minutes).",
            "Or unplug the gateway's power cord, wait about 10 to 30 seconds, and plug it back in.",
        ],
        "qos": {
            "available": None,
            "name": "",
            "note": "UNVERIFIED: no QoS feature documented by Cox for Panoramic gateways.",
        },
        "firmware": "Not user-managed in any Cox doc we found (UNVERIFIED; assumed Cox-managed).",
        "unverified": [
            "The 192.168.0.1 diagnostic page and its login (forum-sourced only).",
            "No manual channel selection (forum-sourced only).",
            "App restart path (forum-sourced only).",
            "QoS and firmware process.",
        ],
        "sources": [
            "https://forums.cox.com/conversations/internet/how-do-i-change-the-wifi-channels-in-the-panoramic-gateway-re-range-and-latency-issues/68751632f7d738f198f36a07",
            "https://forums.cox.com/conversations/internet/is-it-possible-to-change-the-wifi-channel-on-my-panoramic-wifi-to-one-that-is-less-crowded/68750e03f7d738f198a1a608",
            "https://forums.cox.com/conversations/apps/cant-view-wifi-details-or-restart-gateway-in-panoramic-wifi-app/687516d7f7d738f198faad13",
            "https://www.cox.com/content/dam/cox/residential/support/internet/print_media/TechnicolorCGM4331_EasyConnectGuide.pdf",
        ],
    },
    {
        "slug": "t-mobile",
        "name": "T-Mobile 5G Home Internet Gateway",
        "kind": "isp",
        "addresses": ["192.168.12.1"],
        "login": "web_and_app",
        "login_note": (
            "T-Mobile now puts gateway management in the T-Life app (formerly the T-Mobile "
            "Internet app). Many gateway models also have a web interface at http://192.168.12.1; "
            "what it lets you change varies by model (Nokia, Arcadyan, Sagemcom)."
        ),
        "app": "T-Life app (T-Mobile Internet)",
        "credentials": (
            "T-Mobile says the default admin username and password are on the label on the "
            "underside of the gateway. For some older devices T-Mobile notes the default "
            "password matches the Wi-Fi password on that label."
        ),
        "channel_steps": [
            "Varies by gateway model; we found no single T-Mobile article covering channel "
            "selection across current gateways (UNVERIFIED).",
        ],
        "channel_note": "",
        "restart_steps": [
            "App: on the Overview screen, confirm the gateway is online and select Restart your gateway.",
            "Web interface (models that have one): System tab > Reboot, then confirm.",
            "Or turn it off and on with the power button / power cable.",
        ],
        "qos": {
            "available": None,
            "name": "",
            "note": "UNVERIFIED: no user QoS feature found in T-Mobile gateway docs.",
        },
        "firmware": "Not user-managed in the docs we found (UNVERIFIED; assumed T-Mobile-managed).",
        "unverified": [
            "Wi-Fi channel control (model-dependent).",
            "QoS and firmware process.",
            "t-mobile.com support pages block automated fetching; details come from t-mobile.com search excerpts.",
        ],
        "sources": [
            "https://www.t-mobile.com/support/devices/web-gateway-user-interface-gui-high-speed-internet-gateway",
            "https://www.t-mobile.com/support/home-internet/arcadyan-gateway",
            "https://www.t-mobile.com/support/home-internet/app",
            "https://www.t-mobile.com/support/public-files/attachments/hint-gateway/Sagemcom%205G%20Gateway%20User%20Guide_English.pdf",
        ],
    },
    # ------------------------------------------------------------------ Consumer brands
    {
        "slug": "eero",
        "name": "eero",
        "kind": "consumer",
        "addresses": [],
        "login": "app_only",
        "login_note": (
            "eero home networks are managed only in the eero app; there is no browser admin page. "
            "eero's support says the network can't be configured through a web browser or on "
            "Windows, Linux or Intel-based Macs. (eero Insight at insight.eero.com is for eero "
            "Business only.)"
        ),
        "app": "eero app",
        "credentials": (
            "No router password. You sign in to the eero app with a one-time code sent by text or "
            "email, or with a linked Amazon account."
        ),
        "channel_steps": [
            "Not user-changeable. eero uses automatic channel selection and Dynamic Frequency "
            "Selection to move to less congested channels; eero suggests a soft reset so the "
            "system re-learns your environment.",
        ],
        "channel_note": "",
        "restart_steps": [
            "eero app: Settings > Advanced networking > more options (…) > Restart Network, then confirm.",
            "Or unplug each eero briefly and plug it back in.",
        ],
        "qos": {
            "available": True,
            "name": "Optimize for Conferencing and Gaming (formerly Smart Queue Management / SQM)",
            "note": (
                "Shapes queues to cut latency on busy networks. eero's help center has described "
                "it under Settings > Advanced networking > SQM; newer app versions list it under "
                "Discover > eero Labs (path varies by app version). eero advises enabling it only "
                "if your measured speeds match your plan. Model support varies."
            ),
        },
        "firmware": (
            "Automatic. Updates install during your Preferred update time (eero app: Settings > "
            "Software updates > Preferred update time). The network reboots briefly during updates."
        ),
        "unverified": [
            "Exact current app path to Optimize for Conferencing and Gaming (help article vs. eero Labs location).",
            "Restart path is from eero support search excerpts; the eero help center returned errors to automated fetches.",
        ],
        "sources": [
            "https://support.eero.com/hc/en-us/articles/207852793-What-is-the-eero-app",
            "https://support.eero.com/hc/en-us/articles/207599876-Do-I-need-a-password-to-log-into-my-eero-I-think-I-forgot-my-password",
            "https://support.eero.com/hc/en-us/articles/360000709886-What-is-eero-Labs-",
            "https://support.eero.com/hc/en-us/articles/215473703-How-do-I-reboot-or-reset-my-eero",
            "https://support.eero.com/hc/en-us/articles/213372343-How-do-eero-OS-updates-work",
            "https://support.eero.com/hc/en-us/articles/360042096252-What-is-Dynamic-Frequency-Selection",
        ],
    },
    {
        "slug": "google-nest-wifi",
        "name": "Google Nest Wifi / Google Wifi",
        "kind": "consumer",
        "addresses": [],
        "login": "app_only",
        "login_note": (
            "Nest Wifi Pro, Nest Wifi and Google Wifi are set up and managed only in the Google "
            "Home app (the old Google Wifi app is retired). There is no browser admin page. The "
            "router's LAN address defaults to the 192.168.86.x range (DHCP pool "
            "192.168.86.20-250) and can change to 192.168.85.x behind another Google Wifi network."
        ),
        "app": "Google Home app",
        "credentials": "No router password; you sign in to the Google Home app with your Google Account.",
        "channel_steps": [
            "Not user-changeable. Google says the router and points work together to keep devices "
            "on the clearest channel automatically.",
        ],
        "channel_note": "",
        "restart_steps": [
            "Whole network: Google Home app > Home > Wifi > Network settings > Restart entire network.",
            "One point: Google Home app > Home > All devices, touch and hold the device tile > Settings > Restart Wifi point.",
        ],
        "qos": {
            "available": True,
            "name": "Preferred activities and Prioritize device",
            "note": (
                "Preferred activities (Home > Wifi > Network settings > Preferred activities) "
                "focuses bandwidth on video conferencing. Prioritize device reserves more "
                "bandwidth for one device for a set time. Neither is described as a "
                "bufferbloat/SQM feature."
            ),
        },
        "firmware": "Automatic. Google rolls out updates over days or weeks; the device needs to stay online.",
        "unverified": [],
        "sources": [
            "https://support.google.com/wifi/answer/6340375?hl=en",
            "https://support.google.com/googlehome/answer/6272001?hl=en",
            "https://support.google.com/googlenest/answer/9541371?hl=en",
            "https://support.google.com/googlenest/answer/6246483?hl=en",
            "https://support.google.com/googlehome/answer/6246630?hl=en",
            "https://support.google.com/googlehome/answer/7014518?hl=en",
            "https://support.google.com/googlehome/answer/13800967?hl=en",
        ],
    },
    {
        "slug": "netgear",
        "name": "NETGEAR (Nighthawk and Orbi)",
        "kind": "consumer",
        "addresses": ["routerlogin.net", "192.168.1.1", "orbilogin.com"],
        "login": "web_and_app",
        "login_note": (
            "Nighthawk routers: routerlogin.net or http://192.168.1.1. Orbi: orbilogin.com. "
            "The Nighthawk app and Orbi app are alternatives (not every model supports the app)."
        ),
        "app": "Nighthawk app / Orbi app",
        "credentials": (
            "Username admin. NETGEAR says the password is the one you set during setup; newer "
            "routers make you change the default during setup. NETGEAR also says to check the "
            "label on the bottom or back of the router for your model's login details. Password "
            "recovery is available if you enabled it."
        ),
        "channel_steps": [
            "Sign in at routerlogin.net (Orbi: orbilogin.com).",
            "Select Wireless (on some models ADVANCED > Wireless Settings).",
            "Scroll to the band you want and choose a number from the Channel menu.",
            "Click Apply. If you use extenders, set them to match.",
        ],
        "channel_note": "Not every channel is available in every region.",
        "restart_steps": [
            "Sign in, then click ADVANCED > Reboot (Nighthawk Pro Gaming: three-dot menu > Reboot).",
            "Settings are kept on reboot.",
        ],
        "qos": {
            "available": True,
            "name": "Dynamic QoS (select Nighthawk models)",
            "note": (
                "Off by default. Sign in, select Dynamic QoS, tick Enable Dynamic QoS, enter your "
                "internet bandwidth, Apply. NETGEAR lists supported models (RAX series, R7000-class, "
                "XR1000 gaming routers, some mesh kits). Orbi support for Dynamic QoS is UNVERIFIED."
            ),
        },
        "firmware": (
            "ADVANCED > Administration (or Settings > Administration) > Firmware Update or Router "
            "Update > Check. Don't power off until the router restarts. Orbi has its own "
            "orbilogin.com upgrade article."
        ),
        "unverified": [
            "Dynamic QoS on Orbi models.",
        ],
        "sources": [
            "https://kb.netgear.com/980/How-do-I-log-in-to-my-NETGEAR-router",
            "https://kb.netgear.com/20026/How-do-I-change-the-admin-password-on-my-NETGEAR-router",
            "https://kb.netgear.com/31014/How-do-I-change-my-Orbi-WiFi-System-s-admin-login-password",
            "https://kb.netgear.com/23783/How-do-I-change-the-wireless-channel-on-my-NETGEAR-router",
            "https://kb.netgear.com/30860/How-do-I-reboot-my-NETGEAR-router-using-the-router-web-interface",
            "https://kb.netgear.com/25613/How-do-I-enable-Dynamic-QoS-on-my-Nighthawk-router",
            "https://kb.netgear.com/23442/How-do-I-update-the-firmware-on-my-NETGEAR-router-with-a-web-browser",
            "https://kb.netgear.com/31573/How-do-I-manually-upgrade-firmware-on-my-Orbi-router-using-orbilogin-com",
        ],
    },
    {
        "slug": "tp-link",
        "name": "TP-Link (Archer and Deco)",
        "kind": "consumer",
        "addresses": ["tplinkwifi.net", "192.168.0.1", "tplinkdeco.net", "192.168.68.1"],
        "login": "web_and_app",
        "login_note": (
            "Archer routers: tplinkwifi.net or 192.168.0.1 (TP-Link also suggests 192.168.1.1 if "
            "those fail), or the Tether app. Deco mesh: managed mainly in the Deco app; a web page "
            "at tplinkdeco.net or 192.168.68.1 adds some advanced settings and only the owner "
            "TP-Link ID can sign in. A VPN or proxy can block the local address."
        ),
        "app": "Tether app (Archer) / Deco app",
        "credentials": (
            "Archer: newer models make you create an admin password on first login; TP-Link says "
            "some older models use a pre-filled default. The default Wi-Fi name and password are "
            "on the router's label. Deco web page: the password of the owner TP-Link ID account."
        ),
        "channel_steps": [
            "Archer: sign in at tplinkwifi.net, go to Advanced > Wireless > Wireless Settings, pick a Channel (TP-Link recommends Auto unless you have problems), Save.",
            "Deco: only some models allow manual channels (Deco app: More > Wi-Fi Settings > Advanced). Others use More > Network Optimization to pick channels automatically.",
        ],
        "channel_note": "Exact menus vary by model and firmware.",
        "restart_steps": [
            "Archer: Advanced > System Tools > Reboot (newer UIs: Advanced > System > Reboot), or set a Scheduled Reboot.",
            "Deco: power the Deco off and on; the app also offers restart options (path varies by model, UNVERIFIED).",
        ],
        "qos": {
            "available": True,
            "name": "QoS (Archer) / QoS with Scene and Client Acceleration (Deco)",
            "note": (
                "Archer: Advanced > QoS, enter your ISP upload/download, then prioritize by device "
                "or application (options vary by model). Deco app: More > QoS; HomeShield models "
                "offer Scene Acceleration and Client Acceleration, HomeCare models a High Priority "
                "mode. Not described as SQM/bufferbloat control."
            ),
        },
        "firmware": (
            "Archer: Advanced > System Tools > Firmware Upgrade (Online Upgrade or upload a file). "
            "Deco: Deco app > More > System > Update Deco, or web page Advanced > System > Firmware Upgrade."
        ),
        "unverified": [
            "Deco restart path in the app.",
            "Which Deco models support manual channel selection (forum-sourced; TP-Link staff note newer Wi-Fi 7 Decos added it).",
        ],
        "sources": [
            "https://www.tp-link.com/us/support/faq/87/",
            "https://www.tp-link.com/us/support/faq/2641/",
            "https://www.tp-link.com/us/support/faq/1104/",
            "https://www.tp-link.com/us/support/faq/1601/",
            "https://www.tp-link.com/us/support/faq/1599/",
            "https://www.tp-link.com/us/user-guides/archer-ax3200_v1/chapter-14-manage-the-router",
            "https://community.tp-link.com/en/home/forum/topic/847686",
        ],
    },
    {
        "slug": "asus",
        "name": "ASUS",
        "kind": "consumer",
        "addresses": ["www.asusrouter.com", "192.168.50.1"],
        "login": "web_and_app",
        "login_note": (
            "Web GUI at http://www.asusrouter.com or the router's LAN IP (ASUS's example is "
            "192.168.50.1; it varies by model). The ASUS Router app is an alternative. ASUS's "
            "Device Discovery Utility finds the IP if you don't know it."
        ),
        "app": "ASUS Router app",
        "credentials": (
            "ASUS says some models have a default login printed on a sticker on the back or "
            "bottom; other models show model-specific credentials on that label. This login is "
            "separate from the Wi-Fi name and password."
        ),
        "channel_steps": [
            "Sign in at www.asusrouter.com.",
            "Go to Wireless > General.",
            "Pick the band (2.4 / 5 / 6 GHz), set Control Channel, click Apply.",
        ],
        "channel_note": "By default ASUS picks the control channel automatically. Available channels depend on your country.",
        "restart_steps": [
            "Sign in to the web GUI and click Reboot, then OK.",
        ],
        "qos": {
            "available": True,
            "name": "Adaptive QoS",
            "note": (
                "Adaptive QoS > QoS > Enable QoS, choose QoS type (Adaptive QoS, Traditional QoS, "
                "or Bandwidth Limiter; one at a time), pick a mode, Apply. Not every model supports "
                "it; ASUS has a separate FAQ to check yours."
            ),
        },
        "firmware": (
            "Advanced Settings > Administration > Firmware Upgrade (check, upload a file, or "
            "enable Auto Firmware Upgrade). ASUS Router app: Settings > Firmware Upgrade."
        ),
        "unverified": [],
        "sources": [
            "https://www.asus.com/us/support/faq/1005263/",
            "https://www.asus.com/us/support/faq/1011432/",
            "https://www.asus.com/us/support/faq/1053498/",
            "https://www.asus.com/support/faq/1010935/",
            "https://www.asus.com/us/support/faq/1044327/",
            "https://www.asus.com/us/support/faq/1008000/",
        ],
    },
    {
        "slug": "linksys",
        "name": "Linksys (including Velop)",
        "kind": "consumer",
        "addresses": ["myrouter.local", "192.168.1.1"],
        "login": "web_and_app",
        "login_note": (
            "Go to myrouter.local or https://192.168.1.1 from a computer on the network (Linksys "
            "says a desktop computer is needed for the mesh web interface). You may have to click "
            "past a mobile-blocking page and a browser security warning. The Linksys app is the "
            "alternative."
        ),
        "app": "Linksys app",
        "credentials": (
            "Enter your router password in the 'Access Velop/Router' field. If it's your first "
            "login or you've forgotten it, use Reset Password, which asks for the Recovery Key "
            "printed on the bottom of the router connected to your modem."
        ),
        "channel_steps": [
            "Web: sign in, click Wi-Fi Settings, and set Channel (and Channel width) there.",
            "App: menu > Wi-Fi Settings > Advanced Wi-Fi Settings > Channel Finder to scan for the best channels (some models re-scan automatically every 5 days).",
        ],
        "channel_note": "Settings vary by model.",
        "restart_steps": [
            "Linksys app: Network Administration > Restart Network.",
        ],
        "qos": {
            "available": True,
            "name": "Media Prioritization / Priority (QoS)",
            "note": (
                "Smart Wi-Fi routers have Media Prioritization; some other Linksys routers put it "
                "under Applications & Gaming > QoS; Velop's Priority feature lets you pick up to "
                "three devices for bandwidth first. Not an SQM/bufferbloat feature."
            ),
        },
        "firmware": (
            "Mesh systems update automatically by default (web interface: Router Settings > "
            "Connectivity, 'Automatic' box). On Smart Wi-Fi routers automatic updates are off by "
            "default and can be enabled in the Firmware Update section."
        ),
        "unverified": [],
        "sources": [
            "https://support.linksys.com/kb/article/107-en/",
            "https://support.linksys.com/kb/article/264-en/",
            "https://support.linksys.com/kb/article/83-en/",
            "https://support.linksys.com/kb/article/99-en/",
            "https://support.linksys.com/kb/article/283-en/",
            "https://support.linksys.com/kb/article/82-en/",
            "https://support.linksys.com/kb/article/130-en/",
        ],
    },
    {
        "slug": "ubiquiti-unifi",
        "name": "Ubiquiti UniFi (Dream Router, UniFi Express)",
        "kind": "consumer",
        "addresses": ["unifi", "192.168.1.1"],
        "login": "web_and_app",
        "login_note": (
            "Setup is done in the UniFi mobile app. Afterwards you can manage it in the app, at "
            "unifi.ui.com with remote management, or locally: Ubiquiti says to open a browser on "
            "the local network and enter the console's IP address, or type 'unifi/' if a UniFi "
            "gateway is on the network. 192.168.1.1 as the factory LAN address comes from "
            "Ubiquiti community threads, not an official doc (UNVERIFIED)."
        ),
        "app": "UniFi app",
        "credentials": (
            "You sign in with your UI Account (or, for local-only setups, the local admin account "
            "you created during setup). No password is printed on the device."
        ),
        "channel_steps": [
            "In UniFi Network: set channels for all APs under Radios, or per access point in "
            "UniFi Devices > select the AP > Settings.",
            "Ubiquiti recommends only channels 1, 6 or 11 on 2.4 GHz.",
        ],
        "channel_note": "Menu names come from Ubiquiti's help center and shift between UniFi Network versions.",
        "restart_steps": [
            "In UniFi Network, open the device and choose Restart (exact location varies by version, UNVERIFIED), or power-cycle it.",
        ],
        "qos": {
            "available": True,
            "name": "Smart Queues",
            "note": (
                "Built to prevent bufferbloat on slower connections. Ubiquiti does not recommend it "
                "at 300 Mbps or above and says it can reduce throughput by up to 30%. Needs a UniFi "
                "gateway. Exact settings path UNVERIFIED (help center blocked automated fetch)."
            ),
        },
        "firmware": "Settings > Control Plane > Updates (automatic updates can be scheduled there).",
        "unverified": [
            "Factory LAN address 192.168.1.1 (community-sourced).",
            "Settings path to Smart Queues and device restart.",
            "help.ui.com blocked automated fetches; details come from help.ui.com search excerpts.",
        ],
        "sources": [
            "https://help.ui.com/hc/en-us/articles/4416276882327-How-to-Set-Up-UniFi",
            "https://help.ui.com/hc/en-us/articles/28457353760919-UniFi-Local-Management",
            "https://help.ui.com/hc/en-us/articles/12648661321367-UniFi-Gateway-Smart-Queues",
            "https://help.ui.com/hc/en-us/articles/221029967-Optimizing-WiFi-Connectivity-and-Reducing-Latency",
            "https://help.ui.com/hc/en-us/articles/7605005245975-UniFi-Updates",
            "https://community.ui.com/questions/Default-IP-192-168-1-1-of-Unifi-Dream-Pro-is-in-use/f6fa9c78-a334-4888-b073-6f8fe3b6d8f5",
        ],
    },
    {
        "slug": "apple-airport",
        "name": "Apple AirPort (discontinued)",
        "kind": "consumer",
        "addresses": [],
        "login": "app_only",
        "login_note": (
            "AirPort Extreme, AirPort Express and AirPort Time Capsule have no web admin page; "
            "they're configured with AirPort Utility (in Applications > Utilities on Mac, or the "
            "iOS app). Apple has discontinued all AirPort hardware and AirPort Utility: macOS 26, "
            "iOS 26 and iPadOS 26 are the last versions that officially support it, though "
            "upgrading to macOS 27 or iOS 27 doesn't remove an installed copy."
        ),
        "app": "AirPort Utility",
        "credentials": "AirPort Utility asks for the base station password you set when configuring it.",
        "channel_steps": [
            "Open AirPort Utility, select the base station, click Edit.",
            "Click Wireless, then Wireless Options near the bottom.",
            "Choose channels from the 2.4 GHz Channel and 5 GHz Channel pop-up menus.",
            "Click Save, then Update.",
        ],
        "channel_note": "",
        "restart_steps": [
            "AirPort Utility on Mac: Base Station > Restart.",
            "If that doesn't work, unplug it for a few seconds and plug it back in.",
        ],
        "qos": {
            "available": False,
            "name": "",
            "note": "No QoS or smart-queue feature is documented in AirPort Utility's help.",
        },
        "firmware": (
            "Select the base station in AirPort Utility; an Update button appears if firmware is "
            "available. Apple's last listed firmware is 7.6.8 (UNVERIFIED that no later release exists)."
        ),
        "unverified": [
            "Whether 7.6.8 is the final AirPort firmware.",
        ],
        "sources": [
            "https://support.apple.com/en-us/124173",
            "https://support.apple.com/guide/aputility/set-wireless-options-aprt3bba689c/mac",
            "https://support.apple.com/guide/aputility/change-settings-aprt4369e195/mac",
            "https://support.apple.com/guide/aputility/keep-your-base-station-up-to-date-aprt2704/mac",
            "https://support.apple.com/en-us/106840",
        ],
    },
]


FIND_ROUTER_ADDRESS = {
    "macos": [
        "Open Apple menu > System Settings, then click Wi-Fi in the sidebar.",
        "Click Details next to the network you're connected to.",
        "Click TCP/IP. The address next to Router is your router's address.",
        "Shortcut: Option-click the Wi-Fi icon in the menu bar; the router address is listed under your network.",
    ],
    "windows": [
        "Open Command Prompt (search for cmd).",
        "Type ipconfig and press Enter.",
        "Under your Wi-Fi or Ethernet adapter, the Default Gateway is your router's address.",
    ],
    "iphone": [
        "Open Settings and tap Wi-Fi.",
        "Tap the info (i) button next to your network.",
        "Scroll to the Router field; that's your router's address.",
    ],
}

FIND_ROUTER_SOURCES = [
    "https://support.apple.com/guide/mac-help/wi-fi-settings-on-mac-mh11935/mac",
    "https://support.apple.com/guide/mac-help/change-tcpip-settings-on-mac-mh14129/mac",
    "https://support.apple.com/guide/mac-help/use-the-wi-fi-status-menu-on-mac-mchlfad426fa/mac",
    "https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/ipconfig",
    "https://support.apple.com/en-us/102509",
]

ADDRESSES = [
    {
        "slug": "192-168-1-1",
        "address": "192.168.1.1",
        "title": "192.168.1.1 router login",
        "brands": ["netgear", "verizon-fios", "linksys", "ubiquiti-unifi", "tp-link"],
        "brand_notes": [
            "NETGEAR: documented alongside routerlogin.net.",
            "Verizon Fios / Verizon Router: documented alongside mynetworksettings.com and myfiosgateway.com.",
            "Linksys: documented as https://192.168.1.1 alongside myrouter.local.",
            "UniFi: commonly the factory LAN address (community-sourced, UNVERIFIED).",
            "TP-Link: suggested as a fallback if tplinkwifi.net and 192.168.0.1 don't load.",
        ],
        "find_steps": FIND_ROUTER_ADDRESS,
        "notes": (
            "192.168.1.1 is a private address: it only reaches the router on the network you're "
            "connected to. If it doesn't load, your router probably uses a different address; "
            "look it up with the steps below. Some routers use HTTPS with a self-signed "
            "certificate, so a browser privacy warning is expected."
        ),
        "unverified": ["UniFi factory default."],
        "sources": [
            "https://kb.netgear.com/980/How-do-I-log-in-to-my-NETGEAR-router",
            "https://www.verizon.com/support/knowledge-base-239713/",
            "https://support.linksys.com/kb/article/107-en/",
            "https://www.tp-link.com/us/support/faq/87/",
        ] + FIND_ROUTER_SOURCES,
    },
    {
        "slug": "192-168-0-1",
        "address": "192.168.0.1",
        "title": "192.168.0.1 router login",
        "brands": ["tp-link", "cox"],
        "brand_notes": [
            "TP-Link Archer routers: the default login address alongside tplinkwifi.net.",
            "Cox Panoramic Wifi: a limited diagnostic page per Cox forum moderators; Cox steers settings to the Panoramic Wifi app (UNVERIFIED in a Cox support article).",
        ],
        "find_steps": FIND_ROUTER_ADDRESS,
        "notes": (
            "192.168.0.1 only works from a device on that router's network. Type it into the "
            "address bar, not a search box. If it doesn't load, find your router's real address "
            "with the steps below."
        ),
        "unverified": ["Cox's use of 192.168.0.1 is forum-sourced."],
        "sources": [
            "https://www.tp-link.com/us/support/faq/87/",
            "https://forums.cox.com/conversations/internet/is-it-possible-to-change-the-wifi-channel-on-my-panoramic-wifi-to-one-that-is-less-crowded/68750e03f7d738f198a1a608",
        ] + FIND_ROUTER_SOURCES,
    },
    {
        "slug": "10-0-0-1",
        "address": "10.0.0.1",
        "title": "10.0.0.1 router login",
        "brands": ["xfinity"],
        "brand_notes": [
            "Xfinity (Comcast) gateways: the Admin Tool address. You must be on your home "
            "network, Admin Tool access must be turned on, and Xfinity recommends the Xfinity app "
            "for most settings. XB6 and newer gateways don't show advanced Wi-Fi settings there.",
        ],
        "find_steps": FIND_ROUTER_ADDRESS,
        "notes": (
            "10.0.0.1 is a private address, so it only works on your own network. If it doesn't "
            "load, check the Router / Default Gateway address with the steps below."
        ),
        "unverified": [],
        "sources": [
            "https://www.xfinity.com/support/articles/admin-tool-access",
            "https://www.xfinity.com/support/articles/change-wifi-channel-admin-tool",
        ] + FIND_ROUTER_SOURCES,
    },
    {
        "slug": "192-168-1-254",
        "address": "192.168.1.254",
        "title": "192.168.1.254 router login",
        "brands": ["att"],
        "brand_notes": [
            "AT&T Wi-Fi gateways: the gateway settings address. Changes ask for the Device "
            "Access Code printed on the label on the side of the gateway.",
        ],
        "find_steps": FIND_ROUTER_ADDRESS,
        "notes": (
            "192.168.1.254 only reaches the gateway from a device on its network. If it doesn't "
            "load, find your router's address with the steps below."
        ),
        "unverified": [],
        "sources": [
            "https://www.att.com/support/article/u-verse-high-speed-internet/KM1049866/",
            "https://www.att.com/support/article/u-verse-high-speed-internet/KM1395833/",
        ] + FIND_ROUTER_SOURCES,
    },
]
