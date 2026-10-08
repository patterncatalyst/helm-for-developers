#!/usr/bin/env bash
#
# examples/08-config-secrets/demo.sh
#
#   ./demo.sh           # build the image, install the chart, check the API (needs the helm4dev cluster)
#   ./demo.sh offline   # lint, template, kubeconform, Secret and checksum checks (no cluster)
#   ./demo.sh clean     # uninstall release "shipping" and delete namespace hfd-08
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
NS=hfd-08
CHART=./shipping-service

offline() {
  helm lint "$CHART" --strict -f values-dev.yaml
  helm template shipping "$CHART" -n "$NS" -f values-dev.yaml | kubeconform -strict -summary -
  # No token configured: no Secret, no API_TOKEN.
  if helm template shipping "$CHART" | grep -qE 'kind: Secret|API_TOKEN'; then echo "unexpected Secret" >&2; exit 1; fi
  # Token from values: Secret plus secretKeyRef.
  helm template shipping "$CHART" -f values-dev.yaml --show-only templates/secret.yaml | grep -F 'api-token:'
  helm template shipping "$CHART" -f values-dev.yaml --show-only templates/deployment.yaml | grep -A4 'name: API_TOKEN'
  # existingSecret: no Secret rendered, the reference points at the named one.
  if helm template shipping "$CHART" --set auth.existingSecret=my-token --show-only templates/secret.yaml 2>&1 | grep -q 'kind: Secret'; then echo "Secret rendered despite existingSecret" >&2; exit 1; fi
  helm template shipping "$CHART" --set auth.existingSecret=my-token --show-only templates/deployment.yaml | grep -F 'name: my-token'
  # checksum/config changes when the ConfigMap content changes, and only then.
  a="$(helm template shipping "$CHART" --show-only templates/deployment.yaml | grep checksum/config)"
  b="$(helm template shipping "$CHART" --show-only templates/deployment.yaml | grep checksum/config)"
  c="$(helm template shipping "$CHART" --set config.logLevel=DEBUG --show-only templates/deployment.yaml | grep checksum/config)"
  [ "$a" = "$b" ] && [ "$a" != "$c" ] && echo "checksum stable for equal input, changes with logLevel"
  # lookup is empty offline, so generate=true renders a fresh random token each time.
  x="$(helm template shipping "$CHART" --set auth.generate=true --show-only templates/secret.yaml | grep api-token)"
  y="$(helm template shipping "$CHART" --set auth.generate=true --show-only templates/secret.yaml | grep api-token)"
  [ "$x" != "$y" ] && echo "offline render of generate=true differs per run (lookup needs a live cluster)"
}

live() {
  "$REPO_ROOT/scripts/build-images.sh" shipping-service
  helm upgrade --install shipping "$CHART" -n "$NS" --create-namespace --wait --timeout 3m --set service.type=NodePort --set service.nodePort=30080 -f values-dev.yaml
  helm list -n "$NS"
  kubectl -n "$NS" get deploy,svc,cm
  "$REPO_ROOT/scripts/tunnel.sh" start shipping
  curl -s --retry 10 --retry-all-errors --retry-delay 1 http://127.0.0.1:8080/api/info; echo
  # Writes need the dev token; reads do not.
  curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:8080/api/shipments -H 'Content-Type: application/json' -d '{"orderId":1,"address":"1 Main St"}'
  curl -s -X POST http://127.0.0.1:8080/api/shipments -H 'Authorization: Bearer dev-token' -H 'Content-Type: application/json' -d '{"orderId":1,"address":"1 Main St"}'; echo
  # A ConfigMap change rolls the pods through checksum/config.
  kubectl -n "$NS" get pods -l app.kubernetes.io/instance=shipping -o name
  helm upgrade shipping "$CHART" -n "$NS" -f values-dev.yaml --set config.defaultCarrier=Globex --wait
  kubectl -n "$NS" get pods -l app.kubernetes.io/instance=shipping -o name
  # generate=true: the token survives an upgrade (lookup).
  helm upgrade shipping "$CHART" -n "$NS" --set auth.generate=true --wait
  before="$(kubectl -n "$NS" get secret shipping-shipping-service -o jsonpath='{.data.api-token}')"
  helm upgrade shipping "$CHART" -n "$NS" --set auth.generate=true --set replicaCount=2 --wait
  after="$(kubectl -n "$NS" get secret shipping-shipping-service -o jsonpath='{.data.api-token}')"
  [ "$before" = "$after" ] && echo "generated token preserved across upgrade"
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
