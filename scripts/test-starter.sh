#!/usr/bin/env bash
#
# test-starter.sh - scaffold a chart from charts/starters/pc-fastapi into a temp
# directory next to a copy of pc-lib, then lint it and run the helm-unittest
# suite in scripts/starter-tests/.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/charts"
cp -r "$HFD_ROOT/charts/pc-lib" "$TMP/charts/pc-lib"
helm create --starter "$HFD_ROOT/charts/starters/pc-fastapi" "$TMP/charts/inventory-service" >/dev/null
cat "$TMP/charts/inventory-service/pc-lib-dependency.yaml" >> "$TMP/charts/inventory-service/Chart.yaml"
helm dependency build "$TMP/charts/inventory-service" >/dev/null
mkdir -p "$TMP/charts/inventory-service/tests"
cp "$HERE"/starter-tests/*_test.yaml "$TMP/charts/inventory-service/tests/"
helm lint --strict "$TMP/charts/inventory-service"
helm unittest "$TMP/charts/inventory-service"
