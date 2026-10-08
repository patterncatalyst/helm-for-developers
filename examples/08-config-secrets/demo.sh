#!/usr/bin/env bash
#
# examples/08-config-secrets/demo.sh
#
#   ./demo.sh           # build the image, install the chart, check the API (needs the helm4dev cluster)
#   ./demo.sh offline   # lint, template, kubeconform, Secret and checksum checks (no cluster)
#   ./demo.sh sops      # SOPS + age + helm-secrets: encrypt, render, negative control, live install (needs network; cluster for the live part)
#   ./demo.sh clean     # uninstall release "shipping" and delete namespace hfd-08
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
NS=hfd-08
CHART=./shipping-service
WORK="$SCRIPT_DIR/.work"            # gitignored: throwaway age key, plaintext and encrypted files
PLUGDIR="$REPO_ROOT/.tools/helm/plugins-secrets"   # helm-secrets plugins, apart from the shared HELM_PLUGINS
HELM_SECRETS_VERSION=4.7.9          # jkroepke/helm-secrets, pinned 2026-10-08

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

# SOPS with age, decrypted by helm-secrets under Helm 4. The plugins live in
# .tools/helm/plugins-secrets, not in the shared .tools/helm/plugins. The key is generated
# here, never committed, and removed by `clean`.
sops_demo() {
  command -v sops >/dev/null && command -v age-keygen >/dev/null || { echo "sops and age are missing: run scripts/install-tools.sh" >&2; exit 1; }
  mkdir -p "$WORK" "$PLUGDIR"
  local shared="$HELM_PLUGINS"
  export HELM_PLUGINS="$PLUGDIR"
  # Helm 4.3.0 verifies plugin installs by default and the helm-secrets keyring is not in the
  # project GNUPGHOME, so --verify=false. OCI installs honor HELM_PLUGINS; tgz-URL installs write to the shared directory.
  for p in secrets secrets-getter; do
    helm plugin list | awk -v p="$p" 'NR>1 && $1==p {f=1} END {exit !f}' \
      || helm plugin install "oci://ghcr.io/jkroepke/helm-secrets/$p:$HELM_SECRETS_VERSION" --verify=false
  done
  rm -f "$shared"/secrets*.tgz "$shared"/secrets*.tgz.prov   # download leftovers Helm 4.3.0 writes to the shared plugin dir
  helm plugin list

  # A throwaway age key and a SOPS rule that encrypts secrets.<env>.yaml for it.
  [ -f "$WORK/dev.agekey" ] || age-keygen -o "$WORK/dev.agekey" 2>&1
  local pub; pub="$(age-keygen -y "$WORK/dev.agekey")"
  printf 'creation_rules:\n  - path_regex: secrets\\..*\\.yaml$\n    age: %s\n' "$pub" > "$WORK/.sops.yaml"
  printf 'auth:\n  token: sops-dev-token\n' > "$WORK/secrets.dev.yaml"
  sops --config "$WORK/.sops.yaml" encrypt -i "$WORK/secrets.dev.yaml"
  echo "--- encrypted file (the value is ciphertext, the key name stays readable):"
  grep -E '^auth:|^    token:' "$WORK/secrets.dev.yaml"
  if grep -q 'sops-dev-token' "$WORK/secrets.dev.yaml"; then echo "plaintext leaked into the encrypted file" >&2; exit 1; fi

  export SOPS_AGE_KEY_FILE="$WORK/dev.agekey"
  want="$(printf 'sops-dev-token' | base64)"
  echo "--- getter: -f secrets://<file>"
  got="$(helm template shipping "$CHART" -f values-dev.yaml -f "secrets://$WORK/secrets.dev.yaml" --show-only templates/secret.yaml | awk -F'"' '/api-token/ {print $2}')"
  [ "$got" = "$want" ] && echo "rendered api-token decodes to sops-dev-token (secrets:// getter)"
  echo "--- CLI: helm secrets template"
  got="$(helm secrets template shipping "$CHART" -f values-dev.yaml -f "$WORK/secrets.dev.yaml" --show-only templates/secret.yaml | awk -F'"' '/api-token/ {print $2}')"
  [ "$got" = "$want" ] && echo "rendered api-token decodes to sops-dev-token (helm secrets template)"

  echo "--- negative control: a key that is not a recipient"
  rm -f "$WORK/wrong.agekey"; age-keygen -o "$WORK/wrong.agekey" >/dev/null 2>&1
  if SOPS_AGE_KEY_FILE="$WORK/wrong.agekey" helm template shipping "$CHART" -f "secrets://$WORK/secrets.dev.yaml" >"$WORK/wrong.out" 2>&1; then
    echo "decryption succeeded with the wrong key" >&2; exit 1
  fi
  head -4 "$WORK/wrong.out"
  echo "--- negative control: the encrypted file passed as plain values"
  if helm template shipping "$CHART" -f "$WORK/secrets.dev.yaml" >"$WORK/raw.out" 2>&1; then
    echo "chart accepted the encrypted file" >&2; exit 1
  fi
  head -3 "$WORK/raw.out"

  if ! kubectl --context helm4dev get nodes >/dev/null 2>&1; then echo "no helm4dev cluster reachable: skipping the live install"; export HELM_PLUGINS="$shared"; return 0; fi
  echo "--- live install with the decrypted value"
  helm upgrade --install shipping "$CHART" -n "$NS" --create-namespace --wait --timeout 3m -f values-dev.yaml -f "secrets://$WORK/secrets.dev.yaml"
  live_tok="$(kubectl -n "$NS" get secret shipping-shipping-service -o jsonpath='{.data.api-token}' | base64 -d)"
  echo "Secret api-token in the cluster: $live_tok"
  [ "$live_tok" = "sops-dev-token" ]
  "$REPO_ROOT/scripts/tunnel.sh" start shipping
  curl -s -o /dev/null --retry 10 --retry-all-errors --retry-delay 1 http://127.0.0.1:8080/api/info
  echo "POST with the SOPS-delivered token:"
  curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:8080/api/shipments -H 'Authorization: Bearer sops-dev-token' -H 'Content-Type: application/json' -d '{"orderId":8,"address":"1 Main St"}'
  echo "POST with the old dev token:"
  curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:8080/api/shipments -H 'Authorization: Bearer dev-token' -H 'Content-Type: application/json' -d '{"orderId":8,"address":"1 Main St"}'
  echo "--- helm get values shows the decrypted value (it lands in the release record):"
  helm get values shipping -n "$NS" | grep token
  export HELM_PLUGINS="$shared"
}

clean() {
  helm uninstall shipping -n "$NS" --ignore-not-found
  kubectl delete namespace "$NS" --ignore-not-found
  rm -rf "$WORK"
}

case "${1:-}" in
  offline) offline ;;
  sops) sops_demo ;;
  clean) clean ;;
  "") offline; live; sops_demo ;;
  *) echo "usage: $0 [offline|sops|clean]" >&2; exit 2 ;;
esac
