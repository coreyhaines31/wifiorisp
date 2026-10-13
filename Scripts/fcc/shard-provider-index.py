#!/usr/bin/env python3
"""Splits the per-state provider index into small files the website can load one at a time.

Reads build/fcc/<STATE>.json from build-provider-index.py and writes
site/data/providers/<res-4 cell>.json: every resolution-8 cell inside one resolution-4 H3 cell
(about 1,800 km²), across state lines. The page computes your cell and loads just that file.

    python3 -m pip install h3
    Scripts/fcc/shard-provider-index.py --index build/fcc --out site/data/providers
"""
import argparse
import glob
import json
import os
import shutil
from collections import defaultdict

import h3

PARENT_RESOLUTION = 4


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--index", default="build/fcc")
    parser.add_argument("--out", default="site/data/providers")
    args = parser.parse_args()

    shards = defaultdict(dict)
    vintages = set()
    for path in sorted(glob.glob(os.path.join(args.index, "*.json"))):
        state = json.load(open(path))
        vintages.add(state["vintage"])
        for cell, (total, offers) in state["cells"].items():
            # Some filings list 0 Mbps, which tells a reader nothing.
            entry = [total, [offer for offer in offers if offer[3] >= 1]]
            if not entry[1]:
                continue
            shard = shards[h3.cell_to_parent(cell, PARENT_RESOLUTION)]
            if cell in shard:
                # A cell on a state line: add up locations and keep every offer.
                total, offers = shard[cell]
                shard[cell] = [total + entry[0], offers + entry[1]]
            else:
                shard[cell] = entry
    if len(vintages) != 1:
        raise SystemExit(f"Expected one vintage across states, found {sorted(vintages)}")

    shutil.rmtree(args.out, ignore_errors=True)
    os.makedirs(args.out)
    for parent, cells in shards.items():
        # Provider names repeat in every cell, so each file lists them once and offers point at them:
        # {"p": [names], "t": [technologies], "c": {cell: [homes, [[name, technology, share, down, up], ...]]}}
        names, techs = {}, {}
        compact = {
            cell: [total, [[names.setdefault(o[0], len(names)), techs.setdefault(o[1], len(techs)), *o[2:]]
                           for o in offers]]
            for cell, (total, offers) in cells.items()
        }
        with open(os.path.join(args.out, f"{parent}.json"), "w") as handle:
            json.dump({"p": list(names), "t": list(techs), "c": compact}, handle, separators=(",", ":"))
    providers = {offer[0] for cells in shards.values() for _, offers in cells.values() for offer in offers}
    homes = sum(total for cells in shards.values() for total, _ in cells.values())
    meta = {"vintage": vintages.pop(), "parentResolution": PARENT_RESOLUTION, "resolution": 8,
            "providers": len(providers), "homes": homes}
    with open(os.path.join(args.out, "meta.json"), "w") as handle:
        json.dump(meta, handle)
    print(json.dumps(meta))
    size = sum(os.path.getsize(p) for p in glob.glob(os.path.join(args.out, "*.json")))
    print(f"{len(shards):,} files, {sum(len(c) for c in shards.values()):,} cells, {size / 1e6:.0f} MB")


if __name__ == "__main__":
    main()
