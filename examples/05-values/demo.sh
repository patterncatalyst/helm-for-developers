#!/usr/bin/env bash
#
# examples/05-values/demo.sh
#
#   ./demo.sh           # build the image, install the chart, check the API (needs the helm4dev cluster)
#   ./demo.sh offline   # lint, template, kubeconform, schema and precedence checks (no cluster)
#   ./demo.sh clean     # uninstall release "shipping" and delete namespace hfd-05
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
NS=hfd-05
CHART=./shipping-service

offline() {
  helm lint "$CHART" --strict -f values-dev.yaml
  helm template shipping "$CHART" -n "$NS" -f values-dev.yaml | kubeconform -strict -summary -
  # The schema rejects a wrong type and an unknown key.
  if helm lint "$CHART" --set replicaCount=many >/dev/null 2>&1; then echo "schema accepted replicaCount=many" >&2; exit 1; fi
  if helm lint "$CHART" --set replicas=3 >/dev/null 2>&1; then echo "schema accepted unknown key replicas" >&2; exit 1; fi
  echo "schema rejects bad type and unknown key"
  # Layering: later -f wins over earlier, --set wins over every file.
  helm template shipping "$CHART" -f values-prod.yaml --set replicaCount=5 --show-only templates/deployment.yaml | grep -E 'replicas: 5'
  helm template shipping "$CHART" -f values-prod.yaml -f values-dev.yaml --show-only templates/configmap.yaml | grep -E 'LOG_LEVEL: "DEBUG"'
}

live() {
  "$REPO_ROOT/scripts/build-images.sh" shipping-service
  helm upgrade --install shipping "$CHART" -n "$NS" --create-namespace --wait --timeout 3m --set service.type=NodePort --set service.nodePort=30080 -f values-dev.yaml
  helm list -n "$NS"
  kubectl -n "$NS" get deploy,svc,cm
  curl -s --retry 10 --retry-all-errors --retry-delay 1 http://127.0.0.1:30080/api/info; echo
  helm upgrade shipping "$CHART" -n "$NS" -f values-dev.yaml -f values-prod.yaml --wait
  helm get values shipping -n "$NS" --all | sed -n '1,20p'
  helm upgrade shipping "$CHART" -n "$NS" --reset-then-reuse-values --set config.logLevel=ERROR --wait
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
