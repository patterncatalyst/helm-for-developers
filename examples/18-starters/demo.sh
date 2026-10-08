#!/usr/bin/env bash
#
# examples/18-starters/demo.sh
#
#   ./demo.sh            # offline checks, then install a chart scaffolded from the starter into hfd-18
#   ./demo.sh offline    # install the starter, helm create --starter, append the dependency, lint, template, kubeconform
#   ./demo.sh clean      # uninstall the release, delete namespace hfd-18, remove the starter from $HELM_DATA_HOME
#
# $HELM_DATA_HOME is project-local (scripts/env.sh), so the starter never touches ~/.local/share/helm.
# The scaffolded chart is built in a temporary directory next to a copy of pc-lib.
# Offline mode needs network access only to fetch kubeconform schemas (cached under $SCHEMA_CACHE).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
# shellcheck source=../../scripts/kube-context.sh
source "$REPO_ROOT/scripts/kube-context.sh"

NS=hfd-18
REL=shipping
NAME=inventory-service
K8S_VERSION=1.34.0
SCHEMA_CACHE="${SCHEMA_CACHE:-${TMPDIR:-/tmp}/hfd-kubeconform-cache}"
WORK="${WORK:-$(mktemp -d)}"
trap 'rm -rf "$WORK"' EXIT

step() { printf '\n==> %s\n' "$*"; }

kc() {
    mkdir -p "$SCHEMA_CACHE"
    kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" -cache "$SCHEMA_CACHE" "$@"
}

scaffold() {
    step "Put the starter where helm create looks for it: \$HELM_DATA_HOME/starters"
    rm -rf "$HELM_DATA_HOME/starters/pc-fastapi"
    mkdir -p "$HELM_DATA_HOME/starters"
    cp -r charts/starters/pc-fastapi "$HELM_DATA_HOME/starters/pc-fastapi"
    ls "$HELM_DATA_HOME/starters"

    step "helm create --starter pc-fastapi (by name), next to a copy of pc-lib"
    mkdir -p "$WORK/charts"
    cp -r charts/pc-lib "$WORK/charts/pc-lib"
    helm create --starter pc-fastapi "$WORK/charts/$NAME"

    step "helm create rewrote Chart.yaml: no dependencies block, and the file the starter ships is a sibling"
    cat "$WORK/charts/$NAME/Chart.yaml"
    echo "--- pc-lib-dependency.yaml"
    cat "$WORK/charts/$NAME/pc-lib-dependency.yaml"
    echo "--- placeholders left in the chart: $(grep -rl '<CHARTNAME>' "$WORK/charts/$NAME" | wc -l | tr -d ' ')"
}

offline() {
    scaffold

    step "Without the dependency the chart cannot render: pc-lib is not declared"
    if helm template "$REL" "$WORK/charts/$NAME" >/dev/null 2>"$WORK/err"; then echo "FAIL: expected a failure" >&2; exit 1; fi
    head -3 "$WORK/err"

    step "Append the dependency block, then build"
    cat "$WORK/charts/$NAME/pc-lib-dependency.yaml" >> "$WORK/charts/$NAME/Chart.yaml"
    helm dependency build "$WORK/charts/$NAME"
    helm dependency list "$WORK/charts/$NAME"

    step "helm lint --strict, helm template, kubeconform"
    helm lint --strict "$WORK/charts/$NAME"
    helm template "$REL" "$WORK/charts/$NAME" | kc
    helm template "$REL" "$WORK/charts/$NAME" | grep -E '^(kind|  name):' | head -4
    helm template "$REL" "$WORK/charts/$NAME" | grep -E 'image: |patterncatalyst.io/domain' | sort -u
}

full() {
    offline
    step "Install the scaffolded chart (the image is the shipping image under another name, so only the chart wiring is exercised)"
    "$REPO_ROOT/scripts/build-images.sh" shipping-service
    helm upgrade --install "$REL" "$WORK/charts/$NAME" -n "$NS" --create-namespace \
        --set image.repository=shipping-service --wait --rollback-on-failure --timeout 5m
    kubectl -n "$NS" get deploy,svc
    helm test "$REL" -n "$NS"
}

clean() {
    helm uninstall "$REL" -n "$NS" 2>/dev/null || true
    kubectl delete namespace "$NS" --ignore-not-found --wait=false
    rm -rf "$HELM_DATA_HOME/starters/pc-fastapi"
}

case "${1:-}" in
    "")      full ;;
    offline) offline ;;
    clean)   clean ;;
    *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
