#!/bin/bash
# Restores the providers lookup's data (site/data/providers) from its GitHub release, so the site
# can be deployed from any machine. Rebuilding it from the FCC instead takes about an hour; see CONTRIBUTING.
#
#   Scripts/fcc/fetch-data.sh              # the vintage the site uses
#   Scripts/fcc/fetch-data.sh 2026-06-30   # a specific vintage
#   Scripts/fcc/fetch-data.sh --index      # also the raw per-state index, into build/fcc
set -euo pipefail
cd "$(dirname "$0")/../.."

VINTAGE=$(python3 -c "import json; print(json.load(open('site/_build/city_data.json'))['vintage'])")
INDEX=false
for arg in "$@"; do
  case "$arg" in
    --index) INDEX=true ;;
    *) VINTAGE="$arg" ;;
  esac
done
TAG="data-$VINTAGE"
TMP=$(mktemp -d)
trap 'rm -r "$TMP"' EXIT

echo "▶ Downloading the lookup data for $VINTAGE"
gh release download "$TAG" --repo coreyhaines31/wifiorisp --pattern "provider-lookup-$VINTAGE.tar.gz" --dir "$TMP"
[ -d site/data/providers ] && mv site/data/providers "$TMP/old-providers"
mkdir -p site/data
tar -xzf "$TMP/provider-lookup-$VINTAGE.tar.gz" -C site/data
echo "✓ site/data/providers: $(ls site/data/providers | wc -l | tr -d ' ') files"

if $INDEX; then
  echo "▶ Downloading the per-state index"
  gh release download "$TAG" --repo coreyhaines31/wifiorisp --pattern "fcc-index-$VINTAGE.tar.gz" --dir "$TMP"
  mkdir -p build
  tar -xzf "$TMP/fcc-index-$VINTAGE.tar.gz" -C build
  echo "✓ build/fcc"
fi
