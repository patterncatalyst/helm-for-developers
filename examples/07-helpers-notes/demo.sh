#!/usr/bin/env bash
#
# examples/07-helpers-notes/demo.sh
#
#   ./demo.sh           # build the image, install the chart, check the API (needs the helm4dev cluster)
#   ./demo.sh offline   # lint, template, kubeconform, helper and NOTES checks (no cluster)
#   ./demo.sh clean     # uninstall release "shipping" and delete namespace hfd-07
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
NS=hfd-07
CHART=./shipping-service

offline() {
  helm lint "$CHART" --strict -f values-dev.yaml
  helm template shipping "$CHART" -n "$NS" -f values-dev.yaml | kubeconform -strict -summary -
  # include + helpers: recommended labels on every resource, selector labels stable.
  helm template shipping "$CHART" | grep -c 'app.kubernetes.io/managed-by: Helm'
  # fullname: a release name containing the chart name is not doubled.
  helm template shipping-service "$CHART" --show-only templates/service.yaml | grep -E '^  name: shipping-service$'
  helm template shipping "$CHART" --set fullnameOverride=ship --show-only templates/service.yaml | grep -E '^  name: ship$'
  # NOTES.txt renders at install time; --dry-run=client shows it.
  helm install shipping "$CHART" -n "$NS" --dry-run=client | sed -n '/^NOTES:/,$p'
}

live() {
  "$REPO_ROOT/scripts/build-images.sh" shipping-service
  helm upgrade --install shipping "$CHART" -n "$NS" --create-namespace --wait --timeout 3m --set service.type=NodePort --set service.nodePort=30080 -f values-dev.yaml
  helm list -n "$NS"
  kubectl -n "$NS" get deploy,svc,cm
  curl -s --retry 10 --retry-all-errors --retry-delay 1 http://127.0.0.1:30080/api/info; echo
  helm get notes shipping -n "$NS"
  kubectl -n "$NS" get deploy shipping-shipping-service --show-labels
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
