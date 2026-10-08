#!/usr/bin/env bash
#
# examples/15-kafka-notification/demo.sh
#
#   ./demo.sh            # offline checks, then install kafka, notification and shipping into hfd-15 and dispatch a shipment
#   ./demo.sh offline    # lint, helm-unittest, template and kubeconform (with the CRDs-catalog); no cluster
#   ./demo.sh clean      # uninstall the three releases and delete namespace hfd-15
#
# Offline mode needs network access only to fetch kubeconform schemas (cached under $SCHEMA_CACHE).
# The full run needs the helm4dev cluster with the Strimzi operator (scripts/platform/bootstrap.sh)
# and the two service images (scripts/build-images.sh).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"

NS=hfd-15
K8S_VERSION=1.34.0
SCHEMA_CACHE="${SCHEMA_CACHE:-${TMPDIR:-/tmp}/hfd-kubeconform-cache}"
CRD_CATALOG='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

step() { printf '\n==> %s\n' "$*"; }

kc() {
    mkdir -p "$SCHEMA_CACHE"
    kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" -cache "$SCHEMA_CACHE" \
        -schema-location default -schema-location "$CRD_CATALOG" "$@"
}

offline() {
    step "helm lint --strict"
    helm lint --strict charts/shipping-kafka
    helm lint --strict charts/notification-service -f values/notification-dev.yaml
    helm lint --strict charts/shipping-service -f values/shipping-dev.yaml

    step "helm unittest"
    helm unittest charts/shipping-service charts/notification-service

    step "helm template | kubeconform (Strimzi kinds checked against the CRDs-catalog)"
    helm template kafka charts/shipping-kafka | kc
    helm template notification charts/notification-service -f values/notification-dev.yaml | kc
    helm template shipping charts/shipping-service -f values/shipping-dev.yaml | kc

    step "The Kafka chart renders the same three kinds on kafka.strimzi.io/v1"
    helm template kafka charts/shipping-kafka | grep -E '^(apiVersion|kind):'

    step "notification-service refuses to render without a bootstrap address"
    if helm template notification charts/notification-service >/dev/null 2>"${TMPDIR:-/tmp}/hfd15.err"; then
        echo "FAIL: expected a failure" >&2; exit 1
    fi
    grep -m1 'kafka.bootstrap is required' "${TMPDIR:-/tmp}/hfd15.err"
}

full() {
    offline
    step "Preflight"
    kubectl get crd kafkas.kafka.strimzi.io >/dev/null || { echo "Strimzi operator missing: run scripts/platform/bootstrap.sh" >&2; exit 1; }
    "$REPO_ROOT/scripts/build-images.sh"

    step "Install the Kafka cluster and wait for the Kafka resource to report Ready"
    helm upgrade --install kafka charts/shipping-kafka -n "$NS" --create-namespace
    kubectl -n "$NS" wait --for=condition=Ready kafka/shipping-kafka --timeout=300s

    step "Install notification-service, then shipping-service"
    helm upgrade --install notification charts/notification-service -n "$NS" -f values/notification-dev.yaml --wait --rollback-on-failure --timeout 5m
    helm upgrade --install shipping charts/shipping-service -n "$NS" -f values/shipping-dev.yaml --wait --rollback-on-failure --timeout 5m
    kubectl -n "$NS" get kafka,kafkanodepool,kafkatopic,pods

    step "Dispatch a shipment and read the notification"
    "$REPO_ROOT/scripts/tunnel.sh" start shipping notification
    local id
    id="$(curl -fsS -X POST 127.0.0.1:8080/api/shipments -H 'Authorization: Bearer dev-token' -H 'content-type: application/json' \
        -d '{"orderId":1501,"address":"1 Main St, Springfield"}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')"
    curl -fsS -X POST "127.0.0.1:8080/api/shipments/$id/dispatch" -H 'Authorization: Bearer dev-token'; echo
    sleep 3
    curl -fsS 127.0.0.1:8081/api/notifications; echo
    helm test shipping -n "$NS"
    helm test notification -n "$NS"
}

clean() {
    helm uninstall shipping -n "$NS" 2>/dev/null || true
    helm uninstall notification -n "$NS" 2>/dev/null || true
    helm uninstall kafka -n "$NS" 2>/dev/null || true
    kubectl delete namespace "$NS" --ignore-not-found --wait=false
}

case "${1:-}" in
    "")      full ;;
    offline) offline ;;
    clean)   clean ;;
    *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
