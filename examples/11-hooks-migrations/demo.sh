#!/usr/bin/env bash
#
# examples/11-hooks-migrations/demo.sh
#
#   ./demo.sh             # full run: install with a post-install migration hook, then upgrade with a warm hook
#   ./demo.sh offline     # dependency build, lint, template, unit tests, kubeconform (no cluster)
#   ./demo.sh deadlock    # reproduce the hooks-vs-readiness deadlock (waits out a 90s timeout, then fails)
#   ./demo.sh preinstall  # reproduce a pre-install hook for an in-release database (waits out a 90s timeout)
#   ./demo.sh clean       # uninstall the release and delete the namespace
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"

NS=hfd-11
REL=shipping
CHART=shipping-service
FULL="$REL-$CHART"

offline() {
    local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
    helm dependency build "$CHART"
    helm lint "$CHART"
    helm lint "$CHART" -f values-postgres.yaml --set postgres.host=shipping-postgres-rw
    helm template "$REL" "$CHART" -n "$NS" -f values-postgres.yaml --api-versions postgresql.cnpg.io/v1 > "$tmp/postgres.yaml"
    echo "--- hook annotations in the rendered Job"
    helm template "$REL" "$CHART" -n "$NS" -f values-postgres.yaml --api-versions postgresql.cnpg.io/v1 --show-only templates/migration-job.yaml | grep 'helm.sh/hook'
    grep -q '"helm.sh/hook": "post-install,post-upgrade"' "$tmp/postgres.yaml"
    echo "--- the chart default is pre-install,pre-upgrade"
    helm template "$REL" "$CHART" -n "$NS" --set config.storage=postgres --set postgres.host=db-rw --set postgres.existingSecret=db-app --show-only templates/migration-job.yaml | grep 'helm.sh/hook"'
    helm unittest "$CHART" shipping-postgres
    kubeconform -strict -summary -ignore-missing-schemas "$tmp/postgres.yaml"
    echo "offline checks passed"
}

clean() {
    helm uninstall "$REL" -n "$NS" 2>/dev/null || true
    kubectl delete namespace "$NS" --ignore-not-found
}

full() {
    "$REPO_ROOT/scripts/build-images.sh"
    helm dependency build "$CHART"
    helm upgrade --install "$REL" "$CHART" -n "$NS" --create-namespace -f values-postgres.yaml --wait --timeout 8m
    echo "--- the Job is deleted on success (hook-succeeded); events and the migrations table prove it ran"
    kubectl -n "$NS" get events --field-selector "involvedObject.name=$FULL-migrate"
    kubectl -n "$NS" exec shipping-postgres-1 -c postgres -- psql -d shipping -c 'select * from shipping.schema_migrations'
    helm get hooks "$REL" -n "$NS"
    echo "--- upgrade with the post-upgrade warm hook; the migration Job runs first (weight 0 before 10)"
    helm upgrade "$REL" "$CHART" -n "$NS" -f values-postgres.yaml --set warm.enabled=true --wait --timeout 5m
    kubectl -n "$NS" get events --field-selector "involvedObject.kind=Job" --sort-by=.lastTimestamp
    "$REPO_ROOT/scripts/tunnel.sh" start shipping
    curl -s --retry 10 --retry-all-errors --retry-delay 1 -X POST http://127.0.0.1:8080/api/shipments -H 'Content-Type: application/json' \
        -d '{"orderId": 1001, "address": "1 Main St, Springfield"}'; echo
    echo "clean up with: ./demo.sh clean"
}

deadlock() {
    helm dependency build "$CHART"
    clean
    # Readiness on /healthz needs the migrated tables, but the post-install hook only
    # starts after --wait sees every resource ready. Expect "context deadline exceeded".
    helm upgrade --install "$REL" "$CHART" -n "$NS" --create-namespace -f values-postgres.yaml \
        --set probes.readiness.path=/healthz --wait --timeout 90s || echo "install failed as expected (rc=$?)"
    kubectl -n "$NS" get pods
}

preinstall() {
    helm dependency build "$CHART"
    clean
    # The pre-install hook runs before the CNPG Cluster and its -app Secret exist, so the
    # Job pod cannot start and Helm waits for the Job until the timeout.
    helm upgrade --install "$REL" "$CHART" -n "$NS" --create-namespace -f values-postgres.yaml \
        --set-literal migration.hooks=pre-install,pre-upgrade --timeout 90s || echo "install failed as expected (rc=$?)"
    kubectl -n "$NS" get pods
}

case "${1:-}" in
    "")         full ;;
    offline)    offline ;;
    deadlock)   deadlock ;;
    preinstall) preinstall ;;
    clean)      clean ;;
    *) echo "usage: $0 [offline|deadlock|preinstall|clean]" >&2; exit 2 ;;
esac
