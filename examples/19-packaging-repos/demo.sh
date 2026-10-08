#!/usr/bin/env bash
#
# examples/19-packaging-repos/demo.sh
#
#   ./demo.sh           # offline checks, package, serve a classic repo, repo add/search/pull, install
#   ./demo.sh offline   # lint, template + kubeconform, unittest, package, repo index (no cluster, no network)
#   ./demo.sh clean     # uninstall the release, remove the repo entry, stop the server, delete .work/
#
# Chart: charts/shipping-service 1.0.0 (appVersion 0.1.0) with the pc-lib library chart.
# Namespace hfd-19, release shipping. Repo name hfd-local, served on 127.0.0.1:8088.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"

NS=hfd-19; REL=shipping; REPO_NAME=hfd-local; PORT=8088
CHART=charts/shipping-service
WORK="$SCRIPT_DIR/.work"; REPO_DIR="$WORK/repo"
step() { printf '\n== %s\n' "$*"; }

offline() {
    step "dependency build (pc-lib from file://../pc-lib)"
    helm dependency build "$CHART"
    step "lint --strict"
    helm lint "$CHART" --strict
    step "template | kubeconform"
    helm template "$REL" "$CHART" | kubeconform -strict -summary -ignore-missing-schemas
    step "unittest"
    helm unittest "$CHART"
    step "package 1.0.0 into $REPO_DIR"
    rm -rf "$REPO_DIR"; mkdir -p "$REPO_DIR"
    helm package "$CHART" --dependency-update -d "$REPO_DIR"
    helm package "$CHART" --version 1.1.0-rc.1 -d "$REPO_DIR"
    step "repo index"
    helm repo index "$REPO_DIR" --url "http://127.0.0.1:$PORT"
    grep -E '^\s+(version|appVersion|digest|- http)' "$REPO_DIR/index.yaml"
    grep -q 'version: 1.0.0' "$REPO_DIR/index.yaml"
    sha256sum "$REPO_DIR/shipping-service-1.0.0.tgz"
}

serve_and_use() {
    step "serve the repository on 127.0.0.1:$PORT"
    (cd "$REPO_DIR" && python3 -m http.server "$PORT" --bind 127.0.0.1 >"$WORK/http.log" 2>&1 & echo $! >"$WORK/http.pid")
    sleep 1
    helm repo add "$REPO_NAME" "http://127.0.0.1:$PORT"
    helm repo update "$REPO_NAME"
    helm search repo "$REPO_NAME"
    helm search repo "$REPO_NAME" --devel --versions
    mkdir -p "$WORK/pull"
    helm pull "$REPO_NAME/shipping-service" --version 1.0.0 -d "$WORK/pull"
    ls "$WORK/pull"
    step "install from the repository"
    helm upgrade --install "$REL" "$REPO_NAME/shipping-service" --version 1.0.0 -n "$NS" --create-namespace \
        --set service.type=NodePort --set service.nodePort=30080 --wait --rollback-on-failure
    helm list -n "$NS"
    echo "Reach it: scripts/tunnel.sh start shipping, then curl http://127.0.0.1:8080/api/info"
}

clean() {
    helm uninstall "$REL" -n "$NS" 2>/dev/null || true
    kubectl delete namespace "$NS" --ignore-not-found --wait=false
    helm repo remove "$REPO_NAME" 2>/dev/null || true
    [ -f "$WORK/http.pid" ] && kill "$(cat "$WORK/http.pid")" 2>/dev/null || true
    rm -rf "$WORK"
    # the dependency build leaves a pc-lib archive and lock file in the snapshot; they are ignored by git
    rm -f "$CHART"/charts/*.tgz
}

case "${1:-}" in
    offline) offline ;;
    clean) clean ;;
    "") offline; serve_and_use ;;
    *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
