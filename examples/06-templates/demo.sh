#!/usr/bin/env bash
#
# examples/06-templates/demo.sh
#
#   ./demo.sh           # build the image, install the chart, check the API (needs the helm4dev cluster)
#   ./demo.sh offline   # lint, template, kubeconform, required/tpl checks (no cluster)
#   ./demo.sh clean     # uninstall release "shipping" and delete namespace hfd-06
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
NS=hfd-06
CHART=./shipping-service

offline() {
  helm lint "$CHART" --strict -f values-dev.yaml
  helm template shipping "$CHART" -n "$NS" -f values-dev.yaml | kubeconform -strict -summary -
  # required: with the schema skipped, an empty repository stops rendering with our message.
  if out="$(helm template shipping "$CHART" --set image.repository= --skip-schema-validation 2>&1)"; then echo "required did not fire" >&2; exit 1; fi
  echo "$out" | grep -q "image.repository is required"
  # tpl: the annotation value is rendered with the release context.
  helm template shipping "$CHART" -n "$NS" -f values-dev.yaml --show-only templates/deployment.yaml | grep -F '"shipping.example.com/release": "shipping/hfd-06"'
  # with: no annotations or env block by default.
  if helm template shipping "$CHART" --show-only templates/deployment.yaml | grep -qE '^ +(annotations|env):'; then echo "unexpected empty block" >&2; exit 1; fi
  echo "required, tpl and with behave as documented"
}

live() {
  "$REPO_ROOT/scripts/build-images.sh" shipping-service
  helm upgrade --install shipping "$CHART" -n "$NS" --create-namespace --wait --timeout 3m --set service.type=NodePort --set service.nodePort=30080 -f values-dev.yaml
  helm list -n "$NS"
  kubectl -n "$NS" get deploy,svc,cm
  "$REPO_ROOT/scripts/tunnel.sh" start shipping
  curl -s --retry 10 --retry-all-errors --retry-delay 1 http://127.0.0.1:8080/api/info; echo
  helm upgrade shipping "$CHART" -n "$NS" -f values-dev.yaml --wait
  kubectl -n "$NS" get pods -l app.kubernetes.io/instance=shipping -o jsonpath='{.items[0].metadata.annotations}'; echo
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
