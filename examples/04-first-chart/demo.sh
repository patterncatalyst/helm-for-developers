#!/usr/bin/env bash
#
# examples/04-first-chart/demo.sh
#
#   ./demo.sh           # build the image, install the chart, check the API (needs the helm4dev cluster)
#   ./demo.sh offline   # lint, template, kubeconform, helm create comparison (no cluster)
#   ./demo.sh clean     # uninstall release "shipping" and delete namespace hfd-04
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
NS=hfd-04
CHART=./shipping-service

offline() {
  helm lint "$CHART" --strict
  helm template shipping "$CHART" -n "$NS" | kubeconform -strict -summary -
  # The generated starter, for comparison with the hand-built chart.
  scratch="$(mktemp -d)"; trap 'rm -rf "$scratch"' RETURN
  helm create "$scratch/generated" >/dev/null
  find "$scratch/generated" -type f | sed "s|$scratch/||" | sort
}

live() {
  "$REPO_ROOT/scripts/build-images.sh" shipping-service
  helm upgrade --install shipping "$CHART" -n "$NS" --create-namespace --wait --timeout 3m --set service.type=NodePort --set service.nodePort=30080
  helm list -n "$NS"
  kubectl -n "$NS" get deploy,svc,cm
  "$REPO_ROOT/scripts/tunnel.sh" start shipping
  curl -s --retry 10 --retry-all-errors --retry-delay 1 http://127.0.0.1:8080/api/info; echo
  helm upgrade shipping "$CHART" -n "$NS" --reuse-values --set replicaCount=2 --wait
  helm history shipping -n "$NS"
  helm rollback shipping 1 -n "$NS" --wait
  helm history shipping -n "$NS"
  kubectl -n "$NS" get secrets -l owner=helm
}

clean() {
  helm uninstall shipping -n "$NS" --ignore-not-found
  kubectl delete namespace "$NS" --ignore-not-found
}

case "${1:-}" in
  offline) offline ;;
  clean) clean ;;
  "") offline; live ;;
  *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
