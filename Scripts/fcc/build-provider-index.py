#!/usr/bin/env python3
"""Builds the "providers at your address" index from the FCC's broadband availability data.

Downloads each state's fixed-broadband Location Coverage files through the FCC BDC Public Data
API, streams them without unzipping to disk, and aggregates every location into its H3
resolution-8 cell (about 0.7 km²) and into its census place (city, town, or CDP, via the Census
Bureau's 2020 block assignment files): which providers offer which technology there, their top
advertised speeds, and the share of the area's homes each one covers. Each zip is deleted
once it's read, so the full run never needs more than one file's worth of disk.

Satellite files are skipped: GSO and NGSO satellite cover nearly every location, so the site
shows them as one national note instead.

    FCC_BDC_USERNAME=... FCC_BDC_TOKEN=... Scripts/fcc/build-provider-index.py --states CA --out build/fcc

Needs an FCC API token (broadbandmap.fcc.gov → your username → Manage API Access).
The API allows 10 calls a minute; downloads are paced to stay under it.
"""
import argparse
import csv
import io
import json
import os
import sys
import subprocess
import tempfile
import time
import zipfile
from collections import defaultdict

API = "https://bdc.fcc.gov/api/public/map"
SKIP_TECHNOLOGIES = {"GSO Satellite", "NGSO Satellite"}
CALL_INTERVAL = 6.5  # seconds: 10 calls a minute, with room to spare
TECHNOLOGY = {
    "10": "copper", "40": "cable", "50": "fiber", "70": "fixed-wireless", "71": "fixed-wireless",
    "72": "fixed-wireless", "0": "other",
}

_last_call = 0.0


def call(path, username, token):
    """Fetches through curl: the FCC's bot protection turns away Python's own HTTPS client."""
    global _last_call
    wait = CALL_INTERVAL - (time.monotonic() - _last_call)
    if wait > 0:
        time.sleep(wait)
    _last_call = time.monotonic()
    with tempfile.NamedTemporaryFile() as body:
        status = subprocess.run(
            ["curl", "-sS", "--fail", "--max-time", "900", "-o", body.name,
             "-H", f"username: {username}", "-H", f"hash_value: {token}", f"{API}/{path}"],
            capture_output=True, text=True,
        )
        if status.returncode != 0:
            raise RuntimeError(f"{path}: {status.stderr.strip()}")
        return open(body.name, "rb").read()


def latest_vintage(username, token):
    data = json.loads(call("listAsOfDates", username, token))["data"]
    return max(row["as_of_date"] for row in data if row["data_type"] == "availability")


def coverage_files(vintage, username, token):
    query = "category=State&subcategory=Location%20Coverage&technology_type=Fixed%20Broadband"
    data = json.loads(call(f"downloads/listAvailabilityData/{vintage}?{query}", username, token))["data"]
    return [row for row in data if row["technology_code_desc"] not in SKIP_TECHNOLOGIES]


def read_rows(zipped):
    with zipfile.ZipFile(io.BytesIO(zipped)) as archive:
        name = next(n for n in archive.namelist() if n.endswith(".csv"))
        with archive.open(name) as raw:
            yield from csv.DictReader(io.TextIOWrapper(raw, encoding="utf-8", newline=""))


class Areas:
    """area → (provider, technology) → [locations, max down, max up], plus the locations in each area."""

    def __init__(self):
        self.offers = defaultdict(lambda: defaultdict(lambda: [0, 0, 0]))
        self.locations = defaultdict(set)

    def add(self, area, provider, technology, location, down, up):
        offer = self.offers[area][(provider, technology)]
        offer[0] += 1
        offer[1] = max(offer[1], down)
        offer[2] = max(offer[2], up)
        self.locations[area].add(location)

    def listed(self):
        """{area: [locations, [[provider, technology, share, down, up], ...]]}, fastest first."""
        areas = {}
        for area, by_offer in self.offers.items():
            total = len(self.locations[area])
            offers = sorted(
                ([provider, technology, min(1, round(n / total, 2)), down, up]
                 for (provider, technology), (n, down, up) in by_offer.items()),
                key=lambda offer: (-offer[3], -offer[2]),
            )
            areas[area] = [total, offers]
        return areas


def block_places(fips, usps, cache):
    """2020 census block → place (city, town, or CDP), from the Census Bureau's block assignment file."""
    os.makedirs(cache, exist_ok=True)
    path = os.path.join(cache, f"BlockAssign_ST{fips}_{usps}.zip")
    if not os.path.exists(path):
        url = f"https://www2.census.gov/geo/docs/maps-data/data/baf2020/BlockAssign_ST{fips}_{usps}.zip"
        if subprocess.run(["curl", "-sS", "--fail", "-o", path, url], capture_output=True).returncode != 0:
            return {}
    with zipfile.ZipFile(path) as archive:
        name = next((n for n in archive.namelist() if n.endswith("_INCPLACE_CDP.txt")), None)
        if not name:
            return {}
        lines = io.TextIOWrapper(archive.open(name), encoding="utf-8").read().splitlines()[1:]
    places = {}
    for line in lines:
        block, _, place = line.partition("|")
        if place:
            places[block] = fips + place
    return places


def build_state(files, places, username, token, log):
    cells, cities = Areas(), Areas()
    for file in files:
        started = time.monotonic()
        zipped = call(f"downloads/downloadFile/availability/{file['file_id']}", username, token)
        rows = 0
        for row in read_rows(zipped):
            if row["business_residential_code"] == "B":
                continue
            offer = (row["brand_name"], TECHNOLOGY.get(row["technology"], "other"), int(row["location_id"]),
                     int(row["max_advertised_download_speed"] or 0), int(row["max_advertised_upload_speed"] or 0))
            cells.add(row["h3_res8_id"], *offer)
            place = places.get(row["block_geoid"])
            if place:
                cities.add(place, *offer)
            rows += 1
        log(f"  {file['technology_code_desc']}: {rows:,} rows, {len(zipped) / 1e6:.0f} MB, "
            f"{time.monotonic() - started:.0f}s")
    return cells.listed(), cities.listed()


def write_json(path, vintage, key, areas):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as handle:
        json.dump({"vintage": vintage, key: areas}, handle, separators=(",", ":"))
    return os.path.getsize(path) / 1e6


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--states", required=True, help="Comma-separated USPS codes, or ALL")
    parser.add_argument("--out", default="build/fcc")
    parser.add_argument("--vintage", help="As-of date, like 2025-12-31. Defaults to the latest.")
    args = parser.parse_args()
    username, token = os.environ.get("FCC_BDC_USERNAME"), os.environ.get("FCC_BDC_TOKEN")
    if not username or not token:
        sys.exit("Set FCC_BDC_USERNAME and FCC_BDC_TOKEN.")
    os.makedirs(args.out, exist_ok=True)

    def log(message):
        print(message, flush=True)

    vintage = args.vintage or latest_vintage(username, token)
    files = coverage_files(vintage, username, token)
    by_state = defaultdict(list)
    for file in files:
        by_state[file["state_fips"]].append(file)
    names = {file["state_fips"]: file["state_name"] for file in files}
    wanted = None if args.states.upper() == "ALL" else {s.strip().upper() for s in args.states.split(",")}
    log(f"Vintage {vintage}: {len(files)} non-satellite files across {len(by_state)} states and territories")

    for fips, state_files in sorted(by_state.items()):
        usps = USPS.get(fips)
        if wanted is not None and usps not in wanted:
            continue
        log(f"{names[fips]} ({usps}): {len(state_files)} files")
        places = block_places(fips, usps, os.path.join(args.out, "census"))
        cells, cities = build_state(state_files, places, username, token, log)
        size = write_json(os.path.join(args.out, f"{usps}.json"), vintage, "cells", cells)
        write_json(os.path.join(args.out, "places", f"{usps}.json"), vintage, "places", cities)
        log(f"  → {usps}: {len(cells):,} cells ({size:.1f} MB), {len(cities):,} places")


USPS = {
    "01": "AL", "02": "AK", "04": "AZ", "05": "AR", "06": "CA", "08": "CO", "09": "CT", "10": "DE", "11": "DC",
    "12": "FL", "13": "GA", "15": "HI", "16": "ID", "17": "IL", "18": "IN", "19": "IA", "20": "KS", "21": "KY",
    "22": "LA", "23": "ME", "24": "MD", "25": "MA", "26": "MI", "27": "MN", "28": "MS", "29": "MO", "30": "MT",
    "31": "NE", "32": "NV", "33": "NH", "34": "NJ", "35": "NM", "36": "NY", "37": "NC", "38": "ND", "39": "OH",
    "40": "OK", "41": "OR", "42": "PA", "44": "RI", "45": "SC", "46": "SD", "47": "TN", "48": "TX", "49": "UT",
    "50": "VT", "51": "VA", "53": "WA", "54": "WV", "55": "WI", "56": "WY", "60": "AS", "66": "GU", "69": "MP",
    "72": "PR", "78": "VI",
}

if __name__ == "__main__":
    main()
