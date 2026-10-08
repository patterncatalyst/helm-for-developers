#!/usr/bin/env bash
#
# examples/03-raw-manifests/demo.sh
#
#   ./demo.sh           # build images, apply the manifests, check the API (needs the helm4dev cluster)
#   ./demo.sh offline   # kubeconform on the raw manifests (no cluster)
#   ./demo.sh clean     # delete the namespace hfd-03
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
# shellcheck source=../../scripts/kube-context.sh
source "$REPO_ROOT/scripts/kube-context.sh"
NS=hfd-03

offline() {
  kubeconform -strict -summary manifests/
}

live() {
  "$REPO_ROOT/scripts/build-images.sh" shipping-service
  kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "$NS" apply -f manifests/
  kubectl -n "$NS" rollout status deployment/shipping-service --timeout=120s
  kubectl -n "$NS" get deploy,svc,cm
  curl -s --retry 10 --retry-all-errors --retry-delay 1 http://127.0.0.1:30080/api/info; echo
}

clean() {
  kubectl delete namespace "$NS" --ignore-not-found
}

case "${1:-}" in
  offline) offline ;;
  clean) clean ;;
  "") offline; live ;;
  *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
