#!/usr/bin/env bash
#
# publish-charts.sh - build the classic Helm chart repository served by GitHub Pages.
#
#   scripts/publish-charts.sh <outdir>
#
# Packages the reference charts bottom-up into <outdir>/charts/ and writes
# <outdir>/charts/index.yaml with absolute URLs under the Pages site. Needs only
# Helm (4.x) on PATH; the charts' dependencies are file:// paths inside this repo.
# Override the URL for a local test with HFD_CHARTS_URL.

set -euo pipefail

BASE_URL="${HFD_CHARTS_URL:-https://patterncatalyst.github.io/helm-for-developers/charts}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ $# -eq 1 ]] || { echo "usage: $0 <outdir>" >&2; exit 2; }
command -v helm >/dev/null 2>&1 || { echo "ERROR: helm not on PATH (source scripts/env.sh)" >&2; exit 1; }

mkdir -p "$1"
OUT="$(cd "$1" && pwd)/charts"
rm -rf "$OUT"
mkdir -p "$OUT"

# Dependencies first: pc-lib, then the service charts that use it, then the umbrella.
for c in pc-lib shipping-service notification-service shipping-postgres shipping-kafka shipping-platform; do
    echo "==> $c"
    helm dependency build "$ROOT/charts/$c" >/dev/null
    helm package "$ROOT/charts/$c" --destination "$OUT"
done

helm repo index "$OUT" --url "$BASE_URL"
echo "==> $OUT"
ls -1 "$OUT"
