#!/usr/bin/env bash
#
# examples/02-helm-tour/demo.sh
#
#   ./demo.sh            # install podinfo from OCI into hfd-02, inspect it, uninstall it
#   ./demo.sh offline    # show chart metadata and render the chart locally; no cluster needed
#   ./demo.sh clean      # uninstall the release and delete the namespace
#
# Needs network access to ghcr.io. The chart is public and pinned to 6.15.0.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"

CHART="oci://ghcr.io/stefanprodan/charts/podinfo"
VERSION="6.15.0"
NS="hfd-02"
RELEASE="podinfo"
CTX="helm4dev"

step() { printf '\n==> %s\n' "$1"; }

offline() {
    step "helm show chart"
    helm show chart "$CHART" --version "$VERSION" | tee /dev/stderr | grep -q "^version: $VERSION$"
    step "helm template with the tour values"
    out="$(mktemp --suffix=.yaml)"; trap 'rm -f "$out"' RETURN
    helm template "$RELEASE" "$CHART" --version "$VERSION" -n "$NS" -f values-tour.yaml > "$out"
    grep -E '^kind: ' "$out" | sort | uniq -c
    grep -q 'replicas: 2' "$out" || { echo "FAIL: replicas override not rendered" >&2; return 1; }
    step "kubeconform on the rendered output"
    kubeconform -strict -summary -ignore-missing-schemas "$out"
}

full() {
    kubectl config get-contexts -o name | grep -qx "$CTX" \
        || { echo "context $CTX not found; run examples/01-lab-setup/demo.sh first" >&2; exit 1; }
    step "Install $RELEASE $VERSION into $NS"
    helm install "$RELEASE" "$CHART" --version "$VERSION" --kube-context "$CTX" -n "$NS" --create-namespace \
        -f values-tour.yaml --wait --rollback-on-failure --timeout 3m
    step "helm list"
    helm list --kube-context "$CTX" -n "$NS"
    step "helm status"
    helm status "$RELEASE" --kube-context "$CTX" -n "$NS"
    step "Release record stored in the cluster"
    kubectl --context "$CTX" -n "$NS" get secret -l owner=helm
    step "helm get values (user-supplied only)"
    helm get values "$RELEASE" --kube-context "$CTX" -n "$NS"
    step "Probe the running pods"
    kubectl --context "$CTX" -n "$NS" exec deploy/"$RELEASE" -- podcli check http localhost:9898/healthz
    step "helm uninstall"
    helm uninstall "$RELEASE" --kube-context "$CTX" -n "$NS" --wait
    helm list --kube-context "$CTX" -n "$NS"
}

clean() {
    helm uninstall "$RELEASE" --kube-context "$CTX" -n "$NS" --ignore-not-found --wait
    kubectl --context "$CTX" delete namespace "$NS" --ignore-not-found
}

case "${1:-}" in
    offline) offline ;;
    clean)   clean ;;
    "")      full ;;
    *)       echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
