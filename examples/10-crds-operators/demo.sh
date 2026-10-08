#!/usr/bin/env bash
#
# examples/10-crds-operators/demo.sh
#
#   ./demo.sh           # full run: install the CRD from crds/, prove upgrade does not touch it
#   ./demo.sh offline   # dependency build, lint, template (with the operator guard), unit tests, kubeconform
#   ./demo.sh clean     # uninstall the release, delete the ShippingRoute CRD and the namespace
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
# shellcheck source=../../scripts/kube-context.sh
source "$REPO_ROOT/scripts/kube-context.sh"

NS=hfd-10
REL=shipping
CHART=shipping-service
CRD=shippingroutes.shipping.patterncatalyst.io

offline() {
    local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
    helm dependency build "$CHART"
    helm lint "$CHART"
    helm lint "$CHART" -f values-postgres.yaml --set postgres.host=shipping-postgres-rw
    echo "--- crds/ is skipped by helm template unless --include-crds is given"
    helm template "$REL" "$CHART" -n "$NS" | grep -c 'kind: CustomResourceDefinition' || true
    helm template "$REL" "$CHART" -n "$NS" --include-crds > "$tmp/memory.yaml"
    grep -q 'kind: CustomResourceDefinition' "$tmp/memory.yaml"
    echo "--- the guard fails when the operator API is not served"
    if helm template "$REL" "$CHART" -n "$NS" -f values-postgres.yaml 2> "$tmp/guard.err" > /dev/null; then
        echo "expected the operator guard to fail" >&2; exit 1
    fi
    cat "$tmp/guard.err"
    grep -q 'needs the CloudNativePG operator' "$tmp/guard.err"
    echo "--- the same render passes when the API is declared"
    helm template "$REL" "$CHART" -n "$NS" -f values-postgres.yaml --api-versions postgresql.cnpg.io/v1 > "$tmp/postgres.yaml"
    grep -q 'kind: Cluster' "$tmp/postgres.yaml"
    helm unittest "$CHART" shipping-postgres
    kubeconform -strict -summary -ignore-missing-schemas "$tmp/memory.yaml" "$tmp/postgres.yaml"
    echo "offline checks passed"
}

clean() {
    helm uninstall "$REL" -n "$NS" 2>/dev/null || true
    kubectl -n "$NS" delete shippingroute --all --ignore-not-found 2>/dev/null || true
    kubectl delete crd "$CRD" --ignore-not-found
    kubectl delete namespace "$NS" --ignore-not-found
}

props() { kubectl get crd "$CRD" -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties}' | python3 -c 'import json,sys; print(sorted(json.load(sys.stdin)))'; }

full() {
    "$REPO_ROOT/scripts/build-images.sh"
    helm dependency build "$CHART"
    echo "--- install: Helm applies crds/ first"
    helm upgrade --install "$REL" "$CHART" -n "$NS" --create-namespace --wait --timeout 5m
    kubectl get crd "$CRD"
    echo "spec properties now: $(props)"
    kubectl -n "$NS" apply -f shippingroute-sample.yaml
    kubectl -n "$NS" get shippingroute

    echo "--- upgrade with a changed CRD: Helm does not touch it"
    work="$(mktemp -d)"; trap 'rm -rf "${work:-}"' EXIT
    cp -a "$CHART" shipping-postgres "$work/"
    cp shippingroute-v2.crd.yaml "$work/$CHART/crds/shippingroute.yaml"
    helm upgrade "$REL" "$work/$CHART" -n "$NS" --wait --timeout 5m
    echo "spec properties after upgrade: $(props)"

    echo "--- the supported path for CRD changes is kubectl apply"
    kubectl apply -f shippingroute-v2.crd.yaml
    echo "spec properties after kubectl apply: $(props)"

    echo "--- uninstall leaves the CRD and its custom resources"
    helm uninstall "$REL" -n "$NS"
    kubectl get crd "$CRD"
    kubectl -n "$NS" get shippingroute
    echo "remove everything with: ./demo.sh clean"
}

case "${1:-}" in
    "")      full ;;
    offline) offline ;;
    clean)   clean ;;
    *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
