#!/usr/bin/env python3
"""Builds the "providers at your address" index from the FCC's broadband availability data.

Downloads each state's fixed-broadband Location Coverage files through the FCC BDC Public Data
API, streams them without unzipping to disk, and aggregates every location into its H3
resolution-8 cell (about 0.7 km²): which providers offer which technology there, their top
advertised speeds, and the share of the cell's locations each one covers. Each zip is deleted
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


def build_state(files, username, token, log):
    """cell → (provider, technology) → [locations, max down, max up]; plus locations per cell."""
    offers = defaultdict(lambda: defaultdict(lambda: [0, 0, 0]))
    locations = defaultdict(set)
    for file in files:
        started = time.monotonic()
        zipped = call(f"downloads/downloadFile/availability/{file['file_id']}", username, token)
        rows = 0
        for row in read_rows(zipped):
            if row["business_residential_code"] == "B":
                continue
            cell = row["h3_res8_id"]
            offer = offers[cell][(row["brand_name"], TECHNOLOGY.get(row["technology"], "other"))]
            offer[0] += 1
            offer[1] = max(offer[1], int(row["max_advertised_download_speed"] or 0))
            offer[2] = max(offer[2], int(row["max_advertised_upload_speed"] or 0))
            locations[cell].add(int(row["location_id"]))
            rows += 1
        log(f"  {file['technology_code_desc']}: {rows:,} rows, {len(zipped) / 1e6:.0f} MB, "
            f"{time.monotonic() - started:.0f}s")
    return offers, {cell: len(ids) for cell, ids in locations.items()}


def write_state(state, vintage, offers, counts, out):
    """One JSON file per state: {cell: [locations, [[provider, technology, share, down, up], ...]]}."""
    cells = {}
    for cell, by_offer in offers.items():
        total = counts[cell]
        listed = sorted(
            ([provider, technology, round(n / total, 2), down, up]
             for (provider, technology), (n, down, up) in by_offer.items()),
            key=lambda offer: (-offer[3], -offer[2]),
        )
        cells[cell] = [total, listed]
    path = os.path.join(out, f"{state}.json")
    with open(path, "w") as handle:
        json.dump({"vintage": vintage, "cells": cells}, handle, separators=(",", ":"))
    return path, len(cells)


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
        offers, counts = build_state(state_files, username, token, log)
        path, cells = write_state(usps, vintage, offers, counts, args.out)
        log(f"  → {path}: {cells:,} cells, {os.path.getsize(path) / 1e6:.1f} MB")


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
