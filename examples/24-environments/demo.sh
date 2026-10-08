#!/usr/bin/env bash
#
# examples/24-environments/demo.sh
#
#   ./demo.sh              offline checks, then install the dev environment
#   ./demo.sh offline      lint + Helmfile template for dev, stage and prod + kubeconform
#   ./demo.sh pin <env>    push the images to the registry addon and write tag@digest into pins/<env>.yaml
#   ./demo.sh clean        helmfile destroy for dev, stage and prod
#
# Namespaces: hfd-24-dev, hfd-24-stage, hfd-24-prod. Release name: platform.
# Only dev is installed live; stage and prod need more memory than the lab cluster has.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
# shellcheck source=../../scripts/kube-context.sh
source "$REPO_ROOT/scripts/kube-context.sh"
UMBRELLA=charts/shipping-platform

# replicas <env>: spec.replicas of the shipping Deployment in the rendered environment
replicas() {
    awk '/^# Source: shipping-platform\/charts\/shipping\/templates\/deployment.yaml/ {on=1} on && /^  replicas:/ {print $2; exit}' "/tmp/hfd-24-$1.yaml"
}

# Bottom-up: pc-lib into each service chart, then the service charts into the umbrella.
deps() {
    for c in shipping-service notification-service shipping-platform; do
        helm dependency build "charts/$c" >/dev/null
    done
}

offline() {
    command -v helmfile >/dev/null || { echo "helmfile not found in .tools/bin" >&2; exit 1; }
    command -v kubeconform >/dev/null || { echo "kubeconform not found in .tools/bin" >&2; exit 1; }
    echo "==> helmfile $(helmfile --version | awk '{print $3}') with $(helm version --short)"
    deps
    for env in dev stage prod; do
        echo "==> $env: helm lint --strict with the environment's values"
        helm lint --strict "$UMBRELLA" -f "$UMBRELLA/values-$env.yaml" -f "pins/$env.yaml" >/dev/null
        echo "==> $env: helmfile template | kubeconform"
        helmfile --kube-context "$HELM_KUBECONTEXT" -l "env=$env" template --skip-deps > "/tmp/hfd-24-$env.yaml" 2>/dev/null
        kubeconform -ignore-missing-schemas -summary < "/tmp/hfd-24-$env.yaml"
    done
    echo "==> layering check: prod shipping runs 3 replicas, dev runs 1"
    [[ "$(replicas prod)" == 3 && "$(replicas dev)" == 1 ]] || { echo "unexpected replica counts" >&2; exit 1; }
    echo "==> digest pin check: tag@digest renders unchanged into the pod spec"
    local fake="sha256:$(printf 'shape-check' | sha256sum | cut -d' ' -f1)"
    printf 'shipping:\n  image:\n    tag: "0.1.0@%s"\n' "$fake" > /tmp/hfd-24-digest.yaml
    helm template platform "$UMBRELLA" -f "$UMBRELLA/values-prod.yaml" -f /tmp/hfd-24-digest.yaml \
        | grep -q "image: \"shipping-service:0.1.0@$fake\""
    echo "    (synthetic digest, a syntax check only; use ./demo.sh pin <env> for a real one)"
    echo "==> helm unittest on the umbrella"
    helm unittest "$UMBRELLA" >/dev/null
    echo "offline: OK"
}

pin() {
    local env="${1:?usage: ./demo.sh pin <dev|stage|prod>}" accept digest
    "$REPO_ROOT/scripts/build-images.sh" push
    accept='application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'
    digest="$(curl -sI -H "Accept: $accept" http://127.0.0.1:5000/v2/shipping-service/manifests/0.1.0 \
        | tr -d '\r' | awk 'tolower($1)=="docker-content-digest:" {print $2}')"
    [[ -n "$digest" ]] || { echo "no digest returned by the registry" >&2; exit 1; }
    cat > "pins/$env.yaml" <<EOF
# Written by ./demo.sh pin $env. Images come from the registry addon, by digest.
global:
  imageRegistry: localhost:5000
shipping:
  image:
    tag: "0.1.0@$digest"
EOF
    echo "pinned shipping-service to $digest in pins/$env.yaml"
}

live() {
    deps
    "$REPO_ROOT/scripts/build-images.sh"
    echo "==> helmfile sync (dev)"
    helmfile --kube-context "$HELM_KUBECONTEXT" -l env=dev sync --skip-deps
    echo "==> helm test"
    helm test platform -n hfd-24-dev
    echo "==> releases"
    helm list -A --filter '^platform$'
    echo "Next: curl -s http://127.0.0.1:30080/api/info"
}

case "${1:-all}" in
    offline) offline ;;
    pin) pin "${2:-}" ;;
    clean)
        # Delete the KafkaTopics while the entity operators still run (finalizer, see chapter 15).
        for ns in hfd-24-dev hfd-24-stage hfd-24-prod; do
            kubectl delete kafkatopic --all -n "$ns" --wait --timeout=120s 2>/dev/null || true
        done
        helmfile --kube-context "$HELM_KUBECONTEXT" destroy --skip-deps || true
        kubectl delete ns hfd-24-dev hfd-24-stage hfd-24-prod --ignore-not-found ;;
    all|"") offline; live ;;
    *) echo "usage: $0 [offline|pin <env>|clean]" >&2; exit 2 ;;
esac
