#!/usr/bin/env bash
#
# examples/16-umbrella/demo.sh
#
#   ./demo.sh            # offline checks, then install release "platform" into hfd-16 and dispatch a shipment
#   ./demo.sh offline    # dependency build, lint, unittest, template, kubeconform, the import-values and tags traps; no cluster
#   ./demo.sh clean      # uninstall release platform and delete namespace hfd-16
#
# Offline mode needs network access only to fetch kubeconform schemas (cached under $SCHEMA_CACHE).
# The full run needs the helm4dev cluster with the Strimzi and CloudNativePG operators and the two images.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"

NS=hfd-16
REL=platform
CHART=charts/shipping-platform
VALUES="$CHART/values-dev.yaml"
K8S_VERSION=1.34.0
SCHEMA_CACHE="${SCHEMA_CACHE:-${TMPDIR:-/tmp}/hfd-kubeconform-cache}"
CRD_CATALOG='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

step() { printf '\n==> %s\n' "$*"; }

kc() {
    mkdir -p "$SCHEMA_CACHE"
    kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" -cache "$SCHEMA_CACHE" \
        -schema-location default -schema-location "$CRD_CATALOG" "$@"
}

offline() {
    step "helm dependency build (file:// subcharts are packed into charts/*.tgz) and list"
    helm dependency build "$CHART"
    helm dependency list "$CHART"

    step "helm lint --strict and helm unittest"
    helm lint --strict "$CHART" -f "$VALUES"
    helm unittest "$CHART"

    step "helm template | kubeconform"
    helm template "$REL" "$CHART" -f "$VALUES" | kc

    step "Alias names are the release object names: platform-shipping, platform-notification"
    helm template "$REL" "$CHART" -f "$VALUES" | grep -E '^  name: platform-' | sort -u

    step "The migration hook runs after install because the database is created by this release"
    helm template "$REL" "$CHART" -f "$VALUES" --show-only charts/shipping/templates/migration-job.yaml | grep 'helm.sh/hook"'

    step "Readiness is /health in the umbrella; the standalone default /healthz would wait on the hook"
    helm template "$REL" "$CHART" -f "$VALUES" --show-only charts/shipping/templates/deployment.yaml | grep -A2 readinessProbe

    step "import-values trap: a default in the subchart wins over the imported value"
    cp -r charts "$WORK/charts"
    sed -i 's|# bootstrap: ""  .*|bootstrap: "stale:9092"|' "$WORK/charts/notification-service/values.yaml"
    helm dependency build "$WORK/charts/shipping-platform" >/dev/null
    helm template "$REL" "$WORK/charts/shipping-platform" -f "$VALUES" --show-only charts/notification/templates/deployment.yaml | grep -A1 KAFKA_BOOTSTRAP

    step "tags trap: tags.messaging=false alone leaves shipping pointing at a Kafka that is gone"
    if helm template "$REL" "$CHART" -f "$VALUES" --set tags.messaging=false >/dev/null 2>"$WORK/err"; then
        echo "FAIL: expected a failure" >&2; exit 1
    fi
    grep -m1 'kafka.bootstrap is required' "$WORK/err"
    step "... the pair renders and drops notification and kafka"
    echo "Kafka resources rendered: $(helm template "$REL" "$CHART" -f "$VALUES" --set tags.messaging=false --set shipping.kafka.enabled=false | grep -cE '^kind: (Kafka|KafkaTopic)$' || true)"
}

full() {
    offline
    step "Preflight"
    kubectl get crd kafkas.kafka.strimzi.io clusters.postgresql.cnpg.io >/dev/null || { echo "operators missing: run scripts/platform/bootstrap.sh" >&2; exit 1; }
    "$REPO_ROOT/scripts/build-images.sh"

    step "Install the umbrella as one release"
    helm upgrade --install "$REL" "$CHART" -n "$NS" --create-namespace -f "$VALUES" --wait --rollback-on-failure --timeout 8m
    kubectl -n "$NS" get pods,kafka,clusters.postgresql.cnpg.io
    helm get hooks "$REL" -n "$NS" | head -5 || true

    step "Dispatch a shipment and read the notification"
    local id
    id="$(curl -fsS --retry 10 --retry-all-errors --retry-delay 1 -X POST 127.0.0.1:30080/api/shipments -H 'Authorization: Bearer dev-token' -H 'content-type: application/json' \
        -d '{"orderId":1601,"address":"1 Main St, Springfield"}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')"
    curl -fsS -X POST "127.0.0.1:30080/api/shipments/$id/dispatch" -H 'Authorization: Bearer dev-token'; echo
    sleep 3
    curl -fsS 127.0.0.1:30081/api/notifications; echo
    helm test "$REL" -n "$NS"
}

clean() {
    # Delete the KafkaTopic(s) while the entity operator still runs, so the topic operator can
    # remove its finalizer; otherwise the namespace sticks in Terminating.
    kubectl delete kafkatopic --all -n "$NS" --wait --timeout=120s 2>/dev/null || true
    helm uninstall "$REL" -n "$NS" 2>/dev/null || true
    kubectl delete namespace "$NS" --ignore-not-found --wait=false
}

case "${1:-}" in
    "")      full ;;
    offline) offline ;;
    clean)   clean ;;
    *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
