#!/usr/bin/env bash
#
# examples/20-oci/demo.sh
#
#   ./demo.sh           # offline checks, local registry containers, push/show/pull/login, install by digest
#   ./demo.sh offline   # lint, template + kubeconform, unittest, package (no registry, no cluster)
#   ./demo.sh clean     # uninstall the release, remove the registry containers, log out, delete .work/
#
#   ENGINE=podman ./demo.sh     # container engine for the local registries (default: docker)
#   REGISTRY_ADDON=1 ./demo.sh  # also push to the minikube registry addon at the published node port 127.0.0.1:5000
#
# Registries: 127.0.0.1:5001 (anonymous) and 127.0.0.1:5002 (htpasswd, user hfd). Both plain HTTP.
# Namespace hfd-20, release shipping.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
# shellcheck source=../../scripts/kube-context.sh
source "$REPO_ROOT/scripts/kube-context.sh"

ENGINE="${ENGINE:-docker}"
NS=hfd-20; REL=shipping
CHART=charts/shipping-service
WORK="$SCRIPT_DIR/.work"
REG=127.0.0.1:5001; AUTH=127.0.0.1:5002
IMG=docker.io/library/registry:2
step() { printf '\n== %s\n' "$*"; }

offline() {
    step "dependency build"
    helm dependency build "$CHART"
    step "lint --strict"
    helm lint "$CHART" --strict
    step "template | kubeconform"
    helm template "$REL" "$CHART" | kubeconform -strict -summary -ignore-missing-schemas
    step "unittest"
    helm unittest "$CHART"
    step "package"
    rm -rf "$WORK/pkg"; mkdir -p "$WORK/pkg"
    helm package "$CHART" --dependency-update -d "$WORK/pkg"
    helm package charts/pc-lib -d "$WORK/pkg"
}

start_registries() {
    step "start local registries ($ENGINE)"
    "$ENGINE" rm -f hfd-registry hfd-registry-auth >/dev/null 2>&1 || true
    "$ENGINE" run -d --name hfd-registry -p 127.0.0.1:5001:5000 "$IMG" >/dev/null
    mkdir -p "$WORK/auth"
    htpasswd -Bbn hfd hfd-pass >"$WORK/auth/htpasswd"
    # create + cp + start: avoids bind-mount path restrictions on some engines
    "$ENGINE" create --name hfd-registry-auth -p 127.0.0.1:5002:5000 \
        -e REGISTRY_AUTH=htpasswd -e REGISTRY_AUTH_HTPASSWD_REALM=hfd \
        -e REGISTRY_AUTH_HTPASSWD_PATH=/htpasswd "$IMG" >/dev/null
    "$ENGINE" cp "$WORK/auth/htpasswd" hfd-registry-auth:/htpasswd
    "$ENGINE" start hfd-registry-auth >/dev/null
    for i in $(seq 1 30); do
        curl -fs "http://$REG/v2/" >/dev/null && curl -s -o /dev/null "http://$AUTH/v2/" && break; sleep 1
    done
}

oci_flow() {
    step "push without --plain-http fails (registry speaks HTTP)"
    helm push "$WORK/pkg/shipping-service-1.0.0.tgz" "oci://$REG/charts" || true
    step "push with --plain-http"
    helm push "$WORK/pkg/shipping-service-1.0.0.tgz" "oci://$REG/charts" --plain-http | tee "$WORK/push.txt"
    DIGEST="$(awk '/^Digest:/ {print $2}' "$WORK/push.txt")"
    curl -s "http://$REG/v2/_catalog"; echo
    curl -s "http://$REG/v2/charts/shipping-service/tags/list"; echo
    step "show chart / pull by tag"
    helm show chart "oci://$REG/charts/shipping-service" --version 1.0.0 --plain-http | head -8
    mkdir -p "$WORK/pull"
    helm pull "oci://$REG/charts/shipping-service" --version 1.0.0 --plain-http -d "$WORK/pull"
    step "the chart layer digest equals the sha256 of the .tgz (the manifest digest does not)"
    sha256sum "$WORK/pull/shipping-service-1.0.0.tgz"
    echo "manifest digest: $DIGEST"
    step "pull by digest"
    helm pull "oci://$REG/charts/shipping-service@$DIGEST" --plain-http -d "$WORK/pull"
    ls "$WORK/pull"
}

auth_flow() {
    step "authenticated registry: push without login fails, login, push"
    helm push "$WORK/pkg/shipping-service-1.0.0.tgz" "oci://$AUTH/charts" --plain-http || true
    echo hfd-pass | helm registry login "$AUTH" -u hfd --password-stdin --plain-http
    helm push "$WORK/pkg/shipping-service-1.0.0.tgz" "oci://$AUTH/charts" --plain-http
    helm registry logout "$AUTH"
}

oci_dependency() {
    step "OCI dependency: pc-lib comes from the registry instead of file://../pc-lib"
    helm push "$WORK/pkg/pc-lib-1.0.0.tgz" "oci://$REG/charts" --plain-http
    rm -rf "$WORK/oci-dep"; mkdir -p "$WORK/oci-dep"; cp -r "$CHART" "$WORK/oci-dep/"
    rm -f "$WORK"/oci-dep/shipping-service/charts/*.tgz "$WORK/oci-dep/shipping-service/Chart.lock"
    sed -i "s|file://../pc-lib|oci://$REG/charts|" "$WORK/oci-dep/shipping-service/Chart.yaml"
    helm dependency update "$WORK/oci-dep/shipping-service" --skip-refresh --plain-http
    helm dependency list "$WORK/oci-dep/shipping-service"
}

install_by_digest() {
    step "install by digest"
    helm upgrade --install "$REL" "oci://$REG/charts/shipping-service@$DIGEST" --plain-http -n "$NS" --create-namespace \
        --set service.type=NodePort --set service.nodePort=30080 --wait --rollback-on-failure
    helm list -n "$NS"
}

addon() {
    step "minikube registry addon (published port 127.0.0.1:5000)"
    helm push "$WORK/pkg/shipping-service-1.0.0.tgz" "oci://127.0.0.1:5000/charts" --plain-http
    curl -s http://127.0.0.1:5000/v2/_catalog; echo
}

clean() {
    helm uninstall "$REL" -n "$NS" 2>/dev/null || true
    kubectl delete namespace "$NS" --ignore-not-found --wait=false
    helm registry logout "$AUTH" 2>/dev/null || true
    "$ENGINE" rm -f hfd-registry hfd-registry-auth >/dev/null 2>&1 || true
    rm -rf "$WORK"
    rm -f "$CHART"/charts/*.tgz
}

case "${1:-}" in
    offline) offline ;;
    clean) clean ;;
    "")
        offline; start_registries; oci_flow; auth_flow; oci_dependency; install_by_digest
        if [ "${REGISTRY_ADDON:-0}" = 1 ]; then addon; fi
        echo "Registries stay up for inspection. Run ./demo.sh clean to remove them." ;;
    *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
