#!/bin/sh
# Stands in for the wifiorisp CLI in the smoke test. It logs its arguments to FAKE_ARGV_LOG,
# then FAKE_MODE picks the behavior.
[ -n "$FAKE_ARGV_LOG" ] && printf '%s' "$*" > "$FAKE_ARGV_LOG"
case "$FAKE_MODE:$1" in
  ok:status)
    # Fields the server must drop: bssid, publicIP, routerMAC, and a next step pointing off-site.
    echo '{"internet":{"ms":15,"rating":"Fast"},"limits":[],"link":"wifi","nextSteps":[{"title":"Run a speed test","command":"wifiorisp speed"},{"title":"Read this","url":"https://evil.example/x"}],"paused":false,"router":{"ms":8.6,"rating":"Fast"},"routerMaker":"Calix","provider":"Example Fiber","time":"2026-10-29T18:22:07Z","verdict":{"detail":"All good.","headline":"Fine: WiFi and ISP both OK","kind":"good","problem":false},"wifi":{"band":"6 GHz","channel":37,"generation":"Wi-Fi 6E","linkRateMbps":2401,"noiseDBm":-93,"rssiDBm":-37,"signal":"Excellent","network":"Home","bssid":"aa:bb:cc:dd:ee:ff"},"publicIP":"203.0.113.9","routerMAC":"11:22:33:44:55:66"}' ;;
  problem:status)
    echo '{"internet":{"rating":"No answer"},"limits":[{"headline":"Plan ceiling","detail":"Your plan tops out.","url":"https://wifiorisp.com/routers"}],"link":"wifi","nextSteps":[{"title":"Check for an outage","url":"https://wifiorisp.com/internet-keeps-dropping"},{"title":"Send your ISP a report","command":"wifiorisp report"}],"paused":false,"router":{"ms":4,"rating":"Fast"},"time":"2026-10-29T18:22:07Z","verdict":{"detail":"Your router answers but nothing past it does.","headline":"ISP down","kind":"ispDown","problem":true,"side":"isp"}}'
    exit 2 ;;
  ok:history)
    echo '{"end":"2026-10-29T18:22:16Z","events":[{"time":"2026-10-29T03:10:00Z","text":"Internet dropped for 2m"}],"internetLoss":0.012,"internetMedianMs":13.4,"internetP95Ms":51.1,"ispSlow":0.05,"measurements":3311,"networks":["Home"],"routerMedianMs":7.2,"start":"2026-10-28T18:22:16Z","yourSideSlow":0,"samples":[{"bssid":"aa:bb:cc:dd:ee:ff"}]}' ;;
  empty:history)
    echo '{"end":"2026-10-29T18:22:16Z","events":[],"internetLoss":0,"ispSlow":0,"measurements":0,"networks":[],"start":"2026-10-28T18:22:16Z","yourSideSlow":0}' ;;
  many:history)
    printf '{"end":"2026-10-29T18:22:16Z","measurements":10,"internetLoss":0,"ispSlow":0,"yourSideSlow":0,"networks":[],"start":"2026-10-22T18:22:16Z","events":['
    i=1; while [ $i -le 40 ]; do
      [ $i -gt 1 ] && printf ','
      printf '{"time":"2026-10-29T10:%02d:00Z","text":"Drop %s"}' $i $i
      i=$((i + 1)); done
    echo ']}' ;;
  ok:report) printf 'Connection report\n=================\nPeriod: Oct 22 to Oct 29 (America/Los_Angeles)\n\n- Outages: none.\n' ;;
  ok:speed)
    echo "Speed test by M-Lab, which publishes every result, including your IP address, as open data." >&2
    echo "Download: 300 Mbps" >&2
    echo '{"downloadMbps":312.44,"minRTTms":9.1,"server":"Los Angeles, US","time":"2026-10-29T18:30:00Z","uploadMbps":40.2,"clientIP":"203.0.113.9"}' ;;
  ok:lag)
    echo "Measuring idle latency" >&2
    echo '{"detail":"Lag stays low.","downloadMbps":300,"grade":"High","headline":"Low lag","idleMs":12,"internetAddedMs":3,"loadedMs":20,"queue":"pastRouter","routerAddedMs":1,"rpm":2900,"server":"aim.cloudflare.com","time":"2026-10-29T18:31:00Z","uploadMbps":40}' ;;
  garbage:*) echo 'not json' ;;
  stderr:*) echo "Opened WiFi or ISP in the background." >&2; echo "wifiorisp: fake stderr error" >&2; echo "Run wifiorisp help for usage." >&2; exit 1 ;;
  *) echo "unexpected: $FAKE_MODE $*" >&2; exit 1 ;;
esac
