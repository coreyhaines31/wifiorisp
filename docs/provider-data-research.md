# Provider data research: "providers at your address"

Researched 2026-10-07. Legend: **[verified]** = read in an official doc or tested live; **[third-party]** = from affiliate directories or press, not the provider's own page; **[estimate]** = my calculation; **[uncertain]** = could not confirm.

---

## TL;DR / recommendation

- The FCC has **no per-address, per-coordinate, per-hex or per-block lookup API**. The official BDC Public Data API only lists files and downloads them. [verified]
- The public **state x technology fixed availability CSVs** include one row per location x provider x technology. Each row carries `block_geoid` and `h3_res8_id`. **You do not need a Fabric license** to download or use them. Only the Fabric itself (lat/lon, address, unit count) is licensed through CostQuest. [verified]
- Recommended architecture: **geocode → H3 res-8 cell → precomputed per-cell offer list**, built offline from the FCC CSVs and served as static shards (Vercel Blob / R2 / static files). Add a **per-ZIP (ZCTA) summary** for ZIP-only input and pSEO pages.
- Estimated index size for the whole US: **~150–250 MB raw binary, ~40–100 MB gzipped** (dictionary-encoded, compact). Full JSON shards would be about 3x larger before gzip. [estimate]

---

## 1a. Official BDC Public Data API

Source: *National Broadband Map Public Data API Specifications and Instructions*, v1.5, April 28, 2025. https://www.fcc.gov/sites/default/files/bdc-public-data-api-spec.pdf. fcc.gov's Akamai blocks scripted fetches, so I read it via the Wayback copy. OpenAPI YAML: https://us-fcc.box.com/v/bdc-public-data-api-swagger.

**Auth** [verified]
- Prerequisite: an FCC User Registration account. Log in at https://broadbandmap.fcc.gov/login, click your username, then "Manage API Access", then "Generate".
- The first generation requires clicking "I Agree" on an FCC disclaimer / Terms of Use modal. The spec does not reproduce that text. [uncertain: exact terms]
- Send two headers on every call: `username: <FCC username>` and `hash_value: <token>`.
- Tokens can be regenerated or revoked by the user, and "may be revoked by an FCC Administrator at any time."

**Base URL:** `https://bdc.fcc.gov`

| # | Method + path | Purpose | Rate limit |
|---|---|---|---|
| 3.1 | `GET /api/public/map/listAsOfDates` | Lists data vintages (`data_type`: availability / challenge, `as_of_date`) | 10 calls/min |
| 3.2 | `GET /api/public/map/downloads/listAvailabilityData/{as_of_date}` | Lists every availability file for a vintage. Optional query params: `category` (Summary, State, Provider), `subcategory` (State: Provider List, Location Coverage, Hexagon Coverage; Provider: Location Coverage, Hexagon Coverage, Raw Coverage, Supporting Data), `technology_type` (Fixed Broadband, Mobile Broadband, Mobile Voice), `speed_tier` (35/3, 7/1). Returns `file_id`, technology code, state FIPS, provider, `file_name`, `record_count` | 10 calls/min |
| 3.3 | `GET /api/public/map/downloads/listChallengeData/{as_of_date}` | Lists challenge files | 10 calls/min |
| 3.4 | `GET /api/public/map/downloads/downloadFile/{data_type}/{file_id}/{file_type?}` | Downloads one zip file. `file_type` applies to GIS only: 1 = Shapefile, 2 = GeoPackage | 10 calls/min |
| 4.1 | `GET /api/public/fundingmap/downloads/listFundingData` | Lists funding map files | 10 calls/min |
| 4.2 | `GET /api/public/fundingmap/downloads/downloadFile/{file_id}` | Downloads a funding file | 10 calls/min |

**Answer to the key question:** no endpoint returns availability for a location, coordinate, hex or block. The API only lists and downloads bulk files. Its use for us is to **automate the offline build**: list the vintage, then download all `State / Fixed Broadband / Location Coverage` files. At 10 calls/min, about 56 states/territories x 9 technologies ≈ 500 downloads takes roughly an hour. [verified spec; estimate for timing]

## 1b. broadbandmap.fcc.gov's own address lookup

- The NBM web app's address search and location detail use internal endpoints under `broadbandmap.fcc.gov/nbm/map/api/...`. These are **not documented** in the Public Data API spec or anywhere else official that I found. [verified absence in spec]
- They sit behind Akamai bot protection. A scripted `curl` to `/nbm/map/api/...` returned **HTTP 403**, and so did the app's JS bundle. [verified 2026-10-07]
- The FCC's documented route for address-level checks is the **web UI** ("Search by Address"; see https://help.bdc.fcc.gov/hc/en-us/articles/10467446103579-How-to-Use-the-FCC-s-National-Broadband-Map). I found no grant of third-party programmatic use. The UChicago "Hitchhiker's Guide" paper also says the FCC "currently serves the BDC dataset purely through file-based downloads" and asks the FCC for a queryable API.
- **Recommendation: do not call or scrape the internal endpoints.** They are undocumented and bot-protected, so the integration would be fragile and arguably unauthorized. Use the bulk files.
- Commercial alternative if needed later: BroadbandMap.com sells an API built on FCC data (https://broadbandmap.com/api/). Its ToS forbids scraping and bulk copying. [third-party]

## 1c. Bulk data: fixed broadband availability files

Source: *BDC Specifications for Data Downloads from the National Broadband Map*, March 18, 2025, §3.1.1 and §3.2.1. https://www.fcc.gov/sites/default/files/bdc-data-downloads-output.pdf [verified]

- **Granularity:** "records of the locations for which any service provider reported fixed broadband availability for the selected as-of date, state, and technology." One row per location x provider x technology.
- **Format:** CSV in a zip, one file per state x technology x vintage. Name: `bdc_{StateFIPS}_{Technology}_fixed_broadband_{J|D}{YY}_{RevisionDate}.zip`. Technologies: `copper, cable, fiber, gso_satellite, ngso_satellite, unlicensed_tfw, licensed_tfw, lbr_tfw, other`. Per-provider files also exist (§3.2.1, same columns).
- **Columns:** `frn, provider_id, brand_name, location_id, technology (10 copper, 40 cable, 50 fiber, 60 GSO sat, 61 NGSO sat, 70 unlicensed FW, 71 licensed FW, 72 LBR FW, 0 other), max_advertised_download_speed (Mbps int), max_advertised_upload_speed (Mbps int), low_latency (0/1), business_residential_code (B/R/X), state_usps, block_geoid (15-digit 2020 block), h3_res8_id (15-char hex)`.
  - Caveat from the spec: `h3_res8_id` is the **parent res-8 of the location's res-9 cell**, so "a location may fall outside the parent resolution-8 cell." When you index by res-8, a point lookup can occasionally hit a neighbour cell. Mitigation: query the cell plus its six neighbours (`gridDisk(cell,1)`) and weight the centre cell first.
- **Keys:** `location_id` (Fabric ID), `block_geoid` and `h3_res8_id` are all in the public file. **No lat/lon or address.**
- **License:** the availability layer is publicly downloadable. The **Fabric** (lat/lon, address, unit count, building type) needs a CostQuest license agreement, issued free only for BDC-participation purposes (see CostQuest: https://www.costquest.com/broadband-serviceable-location-fabric/, and the Hitchhiker's Guide §3.4: "the fabric data is not publicly accessible but subject to license agreements"). **Hex-level and block-level aggregation needs no Fabric license** because both IDs are in the public file. [verified]
- **Other public geographies:** the summary files only go down to Census Place, County, Congressional District, Tribal and CBSA. There is no ZIP and no block in the summaries. Fixed **"Hexagon Coverage"** files in the API are mobile products (H3 res-9 GIS). [verified]
- **Mobile:** aggregated per-state mobile H3 **res-9** GIS files exist for 3G/4G/5G (`h3_res9_id`, mindown/minup, environment). They are not needed for home internet. T-Mobile/Verizon/AT&T home 5G appear in the **fixed** files as licensed fixed wireless (typically code 71). [uncertain: confirm by provider_id in the provider list]
- **Scale:** about 116.4M BSLs in Fabric v7 (June 2025, CostQuest: https://costquest.substack.com/p/national-fabric-overview-location) and 2,142 reporting ISPs. The UChicago paper describes the dataset as "hundreds of millions of records amounting to tens of gigabytes."

**Size estimate per state** [estimate; not measured, since the FCC download page is JS-only and the API needs a token]
- Row ≈ 95–110 bytes of CSV. Rows ≈ BSLs x ~6 (≈2–3 satellite rows nearly everywhere from Starlink, Hughes and Viasat, plus ~2–4 terrestrial rows).
- National: ~650–800M rows, **~65–85 GB uncompressed CSV, ~8–15 GB zipped**.
- Large state (CA ≈ 14M BSLs): ~80–90M rows, ~8–9 GB uncompressed, ~1–1.5 GB zipped. Satellite files are the bulk.
- Mid state (e.g., OR ≈ 1.9M BSLs): ~1.2 GB uncompressed, ~150–200 MB zipped.
- Small state (VT/WY ≈ 0.3M BSLs): ~150–250 MB uncompressed, ~25–40 MB zipped.
- Each file's `record_count` from `listAvailabilityData` gives exact numbers once a token exists.

## 1d. Feasible architecture

```
User input
  ├─ full address → Census Geocoder (via our Vercel function) → lat/lon (+ optional 2020 block GEOID)
  └─ ZIP only     → /zip/{zcta}.json (precomputed summary)
lat/lon → h3-js latLngToCell(lat, lon, 8) → shard key = cellToParent(cell, 4 or 5)
fetch shard → offers for the cell (+ gridDisk ring 1 fallback) → rank client-side by user needs
```

**Offline build** (Node or DuckDB script, run each vintage, about twice a year plus revisions):
1. Pull the list via the API (`category=State`, `subcategory=Location Coverage`, `technology_type=Fixed Broadband`) and download all ~500 zips.
2. Stream each CSV through DuckDB, filtering `business_residential_code IN ('R','X')`.
3. Group by `h3_res8_id, provider_id, technology`. Compute `max(down)`, `max(up)` (or the median), `count(distinct location_id)` and `low_latency`.
4. Also compute the per-cell total of distinct locations. That gives a **coverage %** per offer ("Fiber from AT&T: 1 Gbps, available at 82% of homes in your area"). This is the honest way to present area-level data. Note that locations with zero offers never appear in any file, but satellite rows cover nearly every BSL, so the denominator is close to complete.
5. Map `provider_id` to a display name using the provider list (`bdc_us_provider_list_*`, holding company) plus the most common `brand_name`. Keep a small curated alias table, e.g. "Charter Communications" → "Spectrum" and "Comcast" → "Xfinity".
6. Satellite: Starlink (61), HughesNet and Viasat (60) are near-universal. Store them per state as a default with per-cell exceptions, or keep a 1-byte bitmask per cell. This cuts the index size by roughly 40%.
7. Encode a provider dictionary (u16 index), technology (u8), down/up (u16 or a tier code), coverage % (u8), and **dedupe identical offer-sets** (adjacent cells are often identical): `cell → offerSetId`, plus `offerSets[]`.
8. ZIP: join `block_geoid` to ZCTA with the Census 2020 ZCTA↔tabulation-block relationship file. Aggregate per ZCTA (~33.8k files, each listing providers with tech, max speeds and % of locations). This also gives one data-backed pSEO page per ZIP ("Internet providers in 92101").

**Size estimate for the whole US index** [estimate]
- Non-empty res-8 cells: **~4–7M** (res-8 ≈ 0.74 km²; CONUS ≈ 11M cells total; rural BSLs are sparse). [uncertain ±50%]
- Terrestrial offers: about 2–5 per cell on average.
- Naive binary: cell (8 B) + 3–5 offers x 7 B ≈ 30–45 B per cell → **~150–250 MB**. With satellite removed and offer-set dedupe: **~60–120 MB raw, ~40–80 MB gzipped**.
- Naive JSON (`{"882aa8458dfffff":[["AT&T",50,1000,1000,82],...]}`): ~120–180 B per cell → **~0.6–1.1 GB raw, ~120–200 MB gzipped**.
- Sharding: by res-4 parent (~1.8k km²; ~2–3k populated shards nationally; ~20–60 KB gzipped each) or res-5 (~15–20k shards, ~3–10 KB each). Res-4 keeps the file count low.
- ZIP summaries: ~33.8k x ~1–3 KB ≈ **50–100 MB raw, ~10–20 MB gzipped**.
- Hosting: put the shards in **Vercel Blob or Cloudflare R2** (cheap, CDN-cached, no deployment file-count limit) and fetch them directly from the browser. Committing them to the static site also works if the file count fits Vercel's per-deployment limits. [uncertain: check current Vercel limit]
- Alternative: one Postgres/SQLite table `(h3 bigint pk, offers bytea)` with 4–7M rows, about 300–600 MB with index. That is too big for Neon's free tier. Turso/libSQL or a single DuckDB/Parquet file on R2 with HTTP range reads would also work. Static shards are simpler and cost almost nothing.
- Client-side H3: `h3-js` is fairly heavy (~1 MB unminified emscripten build). [uncertain: exact size] Either lazy-load it on the tool page or compute the cell in the Vercel geocode function and return `{lat, lon, h3_8}`.

**Accuracy disclaimers to show:** the data is provider-reported to the FCC, as of the vintage date (e.g., "as of Dec 31, 2025"). The tool shows area-level availability, not a guarantee at your exact address. Link "Verify on the FCC map" to broadbandmap.fcc.gov.

## 2. Geocoding

**US Census Geocoder** (free). Docs: https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html [verified]
- Endpoints: `/geocoder/locations/onelineaddress`, `/locations/address` (street/city/state/zip), `/locations/addressPR`, `/geographies/onelineaddress|address|coordinates` (adds geographies; needs `vintage`), and batch `addressbatch` / `coordinatesbatch` (**10,000 records per file**).
- Example: `https://geocoding.geo.census.gov/geocoder/locations/onelineaddress?address=...&benchmark=Public_AR_Current&format=json` returns `addressMatches[0].coordinates {x: lon, y: lat}`, `matchedAddress` and the ZIP. Add `/geographies/` + `vintage=Current_Current` + `layers=...` to get block or block-group GEOIDs (`layers=10` returned block groups in my test; use `layers=all` or the 2020 block layer to get the block).
- **CORS: not supported.** A request with `Origin: https://wifiorisp.com` came back with no `Access-Control-Allow-Origin`. **JSONP works** (`format=jsonp&callback=cb` returned `/**/cb({...})`). Use a **Vercel serverless proxy** (`/api/geocode`) instead of JSONP. The proxy lets you cache, rate-limit, normalize, and return the H3 cell. [verified 2026-10-07]
- **ZIP-only input is not supported.** "20500" returned zero matches. The docs require street + ZIP or street + city + state. Handle ZIP via the precomputed ZCTA summaries. [verified]
- Limits/terms: the docs publish no per-request rate limit or ToS beyond the 10k batch cap. It is a free federal service, so be polite (cache, debounce, no autocomplete-per-keystroke). [uncertain: unpublished throttling]
- Weaknesses: it matches only address *ranges* (TIGER), so new construction and rural routes miss more often, and it has no autocomplete.

**Alternatives** (all need a key in the proxy; check pricing and ToS before choosing) [uncertain: current free-tier numbers]
- **Nominatim (OSM) public instance:** max 1 req/s, autocomplete forbidden, valid UA required (https://operations.osmfoundation.org/policies/nominatim/). Fine only as a low-volume fallback.
- **Geoapify, Radar, Mapbox Search, Google Places/Geocoding:** these offer address **autocomplete** and CORS-enabled browser keys. Mapbox's and Google's terms restrict storing results; ephemeral use is fine.
- Pragmatic setup: autocomplete via Geoapify or Radar (free tiers), with the Census Geocoder as the free fallback for full addresses.

## 3. Affiliate / referral programs (Corey applies himself)

Note: most ISP affiliate programs run on **CJ Affiliate** and are also resold through **FlexOffers** (a sub-network). The payouts below come from affiliate directories, change often, and are **[third-party]** unless marked. Apply at https://www.cj.com (Publisher sign-up, then search the advertiser and click "Join Program"), https://app.impact.com (partner sign-up), or https://www.flexoffers.com. CJ approval needs a live site with real content and traffic info, and brand approval can take 1–2 weeks.

| ISP | Program | Network(s) | Payout (public, unverified) | Apply |
|---|---|---|---|---|
| Spectrum (Charter) | Spectrum affiliate (internet/TV/mobile) | CJ; also FlexOffers, Awin | CPA, reported $6.40–$60 per package (FlexOffers); some directories say up to $150; 30-day cookie | CJ → search "Spectrum"; https://www.flexoffers.com/affiliate-programs/spectrumns-affiliate-program/ |
| Xfinity (Comcast) | Xfinity Residential + Xfinity Mobile (separate) | CJ; FlexOffers | Reported $96 per Internet connect (others: TV $32, Mobile $60/line); one-time; 30-day cookie | CJ → "Xfinity"; https://www.flexoffers.com/affiliate-programs/xfinity-residential-affiliate-program |
| AT&T Fiber / Internet | AT&T Internet | CJ; FlexOffers | Reported $45 per sale; 30-day cookie | CJ → "AT&T Internet"; https://www.flexoffers.com/affiliate-programs/att-affiliate-program |
| Verizon Fios / 5G Home | Verizon Home Internet (also Verizon, Verizon Business) | CJ; FlexOffers | Reported $60 per 5G Home activation, ~$36–45 per Fios Data; 45–60-day cookie | CJ → "Verizon Home Internet"; https://www.flexoffers.com/affiliate-programs/verizon-fios-affiliate-program |
| T-Mobile Home Internet | T-Mobile 5G Home Internet | FlexOffers; Impact/CJ also reported | Reported $20 per online sale, 1-day cookie (low) | https://www.flexoffers.com/affiliate-programs/t-mobile-home-internet-affiliate-program/ [uncertain which network is primary] |
| Cox | Cox Communications | FlexOffers (CJ reported) | Reported $6.40–$60 per package; 30-day cookie | https://www.flexoffers.com/affiliate-programs/cox-communications-affiliate-program |
| Optimum (Altice) | Optimum | CJ (reportedly CJ-only) | Reported $28 per sale; 30-day cookie | CJ → "Optimum"; https://www.flexoffers.com/affiliate-programs/optimum-affiliate-program |
| Frontier | Frontier Communications | CJ; FlexOffers | Reported $100 per plan; long cookie (directories say 120 days) | CJ → "Frontier"; https://www.flexoffers.com/affiliate-programs/frontier-communications-affiliate-program/ |
| Google Fiber | Google Fiber affiliate | Impact | Reported $50 per purchase | Impact marketplace → "Google Fiber". Separate customer refer-a-friend: https://gfiber.com/refer-a-friend |
| Starlink | **No publisher affiliate program found.** Customer referral program only | In-house (account Referrals tab) | Customer referral, reported $100 cash per referral in the US since Aug 2026 (Notebookcheck); requires being a Starlink subscriber; paid after the referee completes billing cycles | https://starlink.com/support/article/eee7e99e-a736-f16e-9506-c446dd70fb16 (terms; read whether public/commercial posting is allowed) [uncertain] |

**Aggregators / lead partners**
- **Allconnect** (Red Ventures): no self-serve affiliate program. There is a "Partner with Allconnect" B2B form at https://www.allconnect.com/partner-with-us (asks for monthly order volume; mentions "125+ … partner affiliates" and serviceability/order integrations). Apply through the form and ask for a publisher/referral deal or their serviceability API. [verified page]
- **Clearlink (HighSpeedInternet.com, SatelliteInternet.com, etc.):** https://www.clearlink.com/partner-with-us/ targets brands and advertisers, not publishers. No public publisher program found. Contact via "Start the conversation" and ask about a referral or lead-share deal. [verified page]
- **BroadbandNow:** no public affiliate or partner page found (`/partners`, `/affiliates` and `/advertise` return 404). Contact via the site's contact page. [verified 404s]
- Practical note: the ISPs' CJ programs pay per *completed connection*. Aggregators like Allconnect often pay for phone or order leads and can sell many ISPs through one integration. That is worth asking about once traffic exists.

**Amazon Associates (router / mesh links)**
- Sign up at https://affiliate-program.amazon.com. The Operating Agreement (https://affiliate-program.amazon.com/help/operating/agreement) requires this exact statement, clearly and prominently on the site: **"As an Amazon Associate I earn from qualifying purchases."** [verified via agreement excerpt]
- New accounts must make **3 qualifying sales within 180 days** or the application closes. This is the standard Associates Central rule. [uncertain: re-verify in Associates Central help]
- Don't hard-code prices unless they come from the Product Advertising API / Creators API (agreement rule). Don't use links in email/offline or cloak them in ways that hide amazon.com. [verify current agreement]
- **FTC:** the Endorsement Guides require *clear and conspicuous* disclosure of material connections. Put it close to the links, in plain language, and not only in a footer or "About" page (FTC "Disclosures 101": https://www.ftc.gov/business-guidance/resources/disclosures-101-social-media-influencers; Endorsement Guides FAQ: https://www.ftc.gov/business-guidance/resources/ftcs-endorsement-guides). Suggested near-link copy: *"We may earn a commission if you sign up or buy through links on this page. It doesn't change our rankings."* Add the Amazon sentence on pages with Amazon links.
- If ranking is "by your needs" while some providers pay commissions, also state that rankings aren't affected by commissions, and keep that true.

---

## Sources
- FCC, *National Broadband Map Public Data API Specifications*, v1.5 (Apr 28, 2025): https://www.fcc.gov/sites/default/files/bdc-public-data-api-spec.pdf (Wayback: http://web.archive.org/web/2025/https://www.fcc.gov/sites/default/files/bdc-public-data-api-spec.pdf)
- FCC, *Specifications for Data Downloads from the National Broadband Map* (Mar 18, 2025): https://www.fcc.gov/sites/default/files/bdc-data-downloads-output.pdf
- FCC BDC help, How to Use the National Broadband Map: https://help.bdc.fcc.gov/hc/en-us/articles/10467446103579-How-to-Use-the-FCC-s-National-Broadband-Map
- Marques, Schrubbe, Marwell, Feamster (UChicago), *The Hitchhiker's Guide to Analyzing the FCC BDC Datasets*: https://par.nsf.gov/servlets/purl/10613556
- CostQuest, National Fabric overview (116.4M BSLs, v7): https://costquest.substack.com/p/national-fabric-overview-location ; Fabric licensing: https://www.costquest.com/broadband-serviceable-location-fabric/
- H3: https://h3geo.org
- US Census Geocoder API docs: https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html (CORS/JSONP/ZIP behaviour tested live 2026-10-07)
- Nominatim usage policy: https://operations.osmfoundation.org/policies/nominatim/
- BroadbandMap.com API/ToS: https://broadbandmap.com/api/ , https://broadbandmap.com/terms-of-service
- Affiliate directories (third-party): FlexOffers program pages linked in the table; https://linkclicky.com/affiliate-program/att-internet/ ; https://linkclicky.com/affiliate-program/google-fiber/ ; https://linkclicky.com/affiliate-program/frontier-communications/ ; https://uppromote.com/affiliate-directory/xfinity/ ; https://www.affilitizer.com/programs/verizon.com
- Starlink referral: https://starlink.com/support/article/eee7e99e-a736-f16e-9506-c446dd70fb16 ; https://www.notebookcheck.net/SpaceX-now-offers-100-in-cash-instead-of-Starlink-credit-for-referrals-to-speed-up-adoption.1380314.0.html
- Allconnect partners: https://www.allconnect.com/partner-with-us ; Clearlink: https://www.clearlink.com/partner-with-us/
- Amazon Associates Operating Agreement: https://affiliate-program.amazon.com/help/operating/agreement
- FTC Disclosures 101: https://www.ftc.gov/business-guidance/resources/disclosures-101-social-media-influencers
