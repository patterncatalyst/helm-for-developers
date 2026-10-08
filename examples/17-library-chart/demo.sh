#!/usr/bin/env bash
#
# examples/17-library-chart/demo.sh
#
#   ./demo.sh            # offline checks, then install release "platform" (library-based charts) into hfd-17
#   ./demo.sh offline    # lint, unittest, kubeconform, before/after render comparison; no cluster
#   ./demo.sh clean      # uninstall release platform and delete namespace hfd-17
#
# charts/    the library chart pc-lib and the services that consume it
# before/    the same two services with their own copies of the helpers (the chapter 16 state)
#
# Offline mode needs network access only to fetch kubeconform schemas (cached under $SCHEMA_CACHE).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"

NS=hfd-17
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

# Rendered output without the two lines that legitimately differ between chart versions:
# the helm.sh/chart label (carries the chart version) and the checksum of the ConfigMap that contains it.
render() { helm template x "$@" | grep -vE 'helm.sh/chart|checksum/config'; }

lines() { cat "$@" | wc -l | tr -d ' '; }

offline() {
    step "Build dependencies: pc-lib into each service, then the services into the umbrella"
    for c in shipping-service notification-service; do helm dependency build "charts/$c" >/dev/null; done
    helm dependency build "$CHART" >/dev/null
    helm dependency list charts/shipping-service

    step "helm lint --strict and helm unittest"
    helm lint charts/pc-lib
    helm lint --strict "$CHART" -f "$VALUES"
    helm unittest charts/shipping-service charts/notification-service "$CHART"

    step "A library chart cannot be installed or rendered on its own"
    if helm template x charts/pc-lib >/dev/null 2>"$WORK/err"; then echo "FAIL: expected a failure" >&2; exit 1; fi
    cat "$WORK/err"

    step "Template lines: before (helpers copied into each service) and after (pc-lib)"
    printf '  notification-service before: %s lines   after: %s lines\n' \
        "$(lines before/notification-service/templates/{_helpers.tpl,deployment.yaml,service.yaml})" \
        "$(lines charts/notification-service/templates/{_helpers.tpl,deployment.yaml,service.yaml})"
    printf '  shipping-service     before: %s lines   after: %s lines\n' \
        "$(lines before/shipping-service/templates/{_helpers.tpl,deployment.yaml,service.yaml})" \
        "$(lines charts/shipping-service/templates/{_helpers.tpl,deployment.yaml,service.yaml})"

    step "Cross-check: the library-based charts render the same manifests as the copies (diff is empty)"
    local common=(--set kafka.enabled=true --set kafka.bootstrap=k:9092 --set config.storage=postgres --set postgres.host=h)
    diff <(render before/shipping-service "${common[@]}") <(render charts/shipping-service "${common[@]}") && echo "  shipping-service: identical"
    diff <(render before/notification-service --set kafka.bootstrap=k:9092) <(render charts/notification-service --set kafka.bootstrap=k:9092) && echo "  notification-service: identical"

    step "Data-product annotations come from pc-lib.metadataAnnotations on both services"
    helm template "$REL" "$CHART" -f "$VALUES" | grep -E 'patterncatalyst.io/(domain|owner|data-product)' | sort | uniq -c

    step "helm template | kubeconform"
    helm template "$REL" "$CHART" -f "$VALUES" | kc
}

full() {
    offline
    step "Preflight"
    kubectl get crd kafkas.kafka.strimzi.io clusters.postgresql.cnpg.io >/dev/null || { echo "operators missing: run scripts/platform/bootstrap.sh" >&2; exit 1; }
    "$REPO_ROOT/scripts/build-images.sh"
    helm upgrade --install "$REL" "$CHART" -n "$NS" --create-namespace -f "$VALUES" --wait --rollback-on-failure --timeout 8m
    kubectl -n "$NS" get deploy,svc -o custom-columns=NAME:.metadata.name,DOMAIN:'.metadata.annotations.patterncatalyst\.io/domain'
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
