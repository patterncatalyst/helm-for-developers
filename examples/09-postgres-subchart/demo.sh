#!/usr/bin/env bash
#
# examples/09-postgres-subchart/demo.sh
#
#   ./demo.sh           # full run: build images, install with the Postgres subchart, migrate, call the API
#   ./demo.sh offline   # dependency build, lint, template, unit tests, kubeconform (no cluster)
#   ./demo.sh clean     # uninstall the release and delete the namespace
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"

NS=hfd-09
REL=shipping
CHART=shipping-service
FULL="$REL-$CHART"

offline() {
    local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
    helm dependency build "$CHART"
    helm dependency list "$CHART"
    # lint does not resolve import-values, so the schema's "postgres needs a host" rule
    # needs the host supplied on the command line here (helm template resolves it).
    helm lint "$CHART"
    helm lint "$CHART" -f values-postgres.yaml --set postgres.host=shipping-postgres-rw
    helm template "$REL" "$CHART" -n "$NS" > "$tmp/memory.yaml"
    helm template "$REL" "$CHART" -n "$NS" -f values-postgres.yaml > "$tmp/postgres.yaml"
    echo "memory mode:   $(grep -c '^kind:' "$tmp/memory.yaml") objects"
    echo "postgres mode: $(grep -c '^kind:' "$tmp/postgres.yaml") objects (adds the CNPG Cluster)"
    grep -q 'kind: Cluster' "$tmp/postgres.yaml"
    ! grep -q 'kind: Cluster' "$tmp/memory.yaml"
    helm unittest "$CHART"
    kubeconform -strict -summary -ignore-missing-schemas "$tmp/memory.yaml" "$tmp/postgres.yaml"
    echo "offline checks passed"
}

clean() {
    helm uninstall "$REL" -n "$NS" 2>/dev/null || true
    kubectl delete namespace "$NS" --ignore-not-found
}

full() {
    "$REPO_ROOT/scripts/build-images.sh"
    helm dependency build "$CHART"
    helm upgrade --install "$REL" "$CHART" -n "$NS" --create-namespace -f values-postgres.yaml --wait --timeout 5m
    kubectl -n "$NS" get cluster.postgresql.cnpg.io,pods,svc
    # Chapter 11 turns this step into a hook. Until then, run the migration by hand
    # in the app container, which already has the PG_* environment.
    kubectl -n "$NS" exec "deploy/$FULL" -- python -m app.migrate
    curl -s --retry 10 --retry-all-errors --retry-delay 1 http://127.0.0.1:30080/api/info; echo
    curl -s -X POST http://127.0.0.1:30080/api/shipments -H 'Content-Type: application/json' \
        -d '{"orderId": 1001, "address": "1 Main St, Springfield"}'; echo
    curl -s 'http://127.0.0.1:30080/api/shipments?orderId=1001'; echo
    kubectl -n "$NS" get secret shipping-postgres-app -o jsonpath='{.data}' | python3 -c 'import json,sys; print(sorted(json.load(sys.stdin)))'
    echo "clean up with: ./demo.sh clean"
}

case "${1:-}" in
    "")      full ;;
    offline) offline ;;
    clean)   clean ;;
    *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
