#!/usr/bin/env python3
"""Turns the per-place provider index into the dataset the city pages render from.

Reads build/fcc/places/<STATE>.json and build/fcc/<STATE>.json (from build-provider-index.py) and
the Census place gazetteer, keeps places with at least --min-homes homes, and writes
site/_build/city_data.json: each city's name, location, homes, and offers, plus statewide numbers
to compare against. That file is committed, so the site renders without the raw FCC data.

    curl -sLO https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2024_Gazetteer/2024_Gaz_place_national.zip
    Scripts/fcc/city-dataset.py --gazetteer 2024_Gaz_place_national.zip --min-homes 5000
"""
import argparse
import glob
import io
import json
import os
import re
import unicodedata
import zipfile
from collections import defaultdict

STATES = {
    "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas", "CA": "California", "CO": "Colorado",
    "CT": "Connecticut", "DE": "Delaware", "DC": "District of Columbia", "FL": "Florida", "GA": "Georgia",
    "HI": "Hawaii", "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa", "KS": "Kansas",
    "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine", "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan",
    "MN": "Minnesota", "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
    "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York", "NC": "North Carolina",
    "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma", "OR": "Oregon", "PA": "Pennsylvania",
    "RI": "Rhode Island", "SC": "South Carolina", "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas",
    "UT": "Utah", "VT": "Vermont", "VA": "Virginia", "WA": "Washington", "WV": "West Virginia", "WI": "Wisconsin",
    "WY": "Wyoming", "PR": "Puerto Rico",
}
# "Chula Vista city" → "Chula Vista"; "Nashville-Davidson metropolitan government (balance)" → "Nashville-Davidson".
SUFFIX = re.compile(
    r" (city and borough|consolidated government|unified government|metropolitan government|metro government|"
    r"urban county|municipality|borough|village|town|city|CDP|zona urbana|comunidad)( \(balance\))?$"
)


def slugify(name):
    ascii_name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", ascii_name.lower()).strip("-")


def gazetteer(path):
    with zipfile.ZipFile(path) as archive:
        name = next(n for n in archive.namelist() if n.endswith(".txt"))
        lines = io.TextIOWrapper(archive.open(name), encoding="latin-1").read().splitlines()
    header = [h.strip() for h in lines[0].split("\t")]
    places = {}
    for line in lines[1:]:
        row = dict(zip(header, (v.strip() for v in line.split("\t"))))
        places[row["GEOID"]] = {
            "name": SUFFIX.sub("", row["NAME"]), "kind": row["NAME"].rsplit(" ", 1)[-1],
            "lat": float(row["INTPTLAT"]), "lon": float(row["INTPTLONG"]),
        }
    return places


def fiber_reach(areas):
    """Share of homes where at least one fiber provider says it can serve: a lower bound, since
    two providers' coverage can overlap or not, and only the larger share is certain."""
    homes = served = 0
    for total, offers in areas:
        homes += total
        served += total * max((share for _, tech, share, _, _ in offers if tech == "fiber"), default=0)
    return round(served / homes, 3) if homes else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--index", default="build/fcc")
    parser.add_argument("--gazetteer", required=True)
    parser.add_argument("--min-homes", type=int, default=5000)
    parser.add_argument("--out", default="site/_build/city_data.json")
    args = parser.parse_args()

    names = gazetteer(args.gazetteer)
    cities, states, vintages = [], {}, set()
    for path in sorted(glob.glob(os.path.join(args.index, "places", "*.json"))):
        usps = os.path.basename(path)[:-5]
        if usps not in STATES:
            continue
        data = json.load(open(path))
        vintages.add(data["vintage"])
        cells = json.load(open(os.path.join(args.index, f"{usps}.json")))["cells"].values()
        state_homes = sum(total for total, _ in cells)
        providers = defaultdict(float)
        for total, offers in cells:
            for provider, tech, share, _, _ in offers:
                if tech in ("fiber", "cable"):
                    providers[(provider, tech)] += total * share
        states[usps] = {
            "name": STATES[usps], "homes": state_homes, "fiberReach": fiber_reach(cells),
            "top": [[p, t, round(n / state_homes, 3)] for (p, t), n in
                    sorted(providers.items(), key=lambda kv: -kv[1])[:8]],
        }
        seen = {}
        for geoid, (homes, offers) in data["places"].items():
            place = names.get(geoid)
            offers = [offer for offer in offers if offer[3] >= 1]
            if not place or homes < args.min_homes or not offers:
                continue
            slug = slugify(place["name"])
            # Two places can share a name in one state (a city and a CDP); the bigger one gets the page.
            if slug in seen and seen[slug]["homes"] >= homes:
                continue
            seen[slug] = {
                "geoid": geoid, "name": place["name"], "state": usps, "slug": slug, "lat": place["lat"],
                "lon": place["lon"], "homes": homes, "fiberReach": fiber_reach([(homes, offers)]), "offers": offers,
            }
        cities.extend(seen.values())

    if len(vintages) != 1:
        raise SystemExit(f"Expected one vintage, found {sorted(vintages)}")
    cities.sort(key=lambda city: (city["state"], -city["homes"]))
    with open(args.out, "w") as handle:
        json.dump({"vintage": vintages.pop(), "states": states, "cities": cities}, handle, separators=(",", ":"))
    print(f"{len(cities):,} cities in {len(states)} states, {os.path.getsize(args.out) / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
