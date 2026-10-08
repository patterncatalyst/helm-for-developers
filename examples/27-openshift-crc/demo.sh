#!/usr/bin/env bash
#
# examples/27-openshift-crc/demo.sh
#
# UNTESTED on the authoring machine; run on the CRC host (offline mode excepted).
#
#   ./demo.sh            full run: build and push images, install, test, show Routes
#   ./demo.sh offline    dependency build, lint, template (both profiles), kubeconform.
#                        No cluster needed. Routes are skipped by kubeconform (no schema).
#   ./demo.sh clean      helm uninstall platform and delete the project
#
# Env: NAMESPACE (default hfd-ocp), PROFILE (full | minimal, default minimal),
#      RELEASE (default platform).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"

NAMESPACE="${NAMESPACE:-hfd-ocp}"
RELEASE="${RELEASE:-platform}"
PROFILE="${PROFILE:-minimal}"
CHART="charts/shipping-platform"
CRDS="Route,Cluster,Kafka,KafkaNodePool,KafkaTopic"

values_args() {
    VALUES=(-f values-openshift.yaml)
    [[ "$PROFILE" == "minimal" ]] && VALUES+=(-f values-openshift-minimal.yaml)
    return 0
}

deps() {
    for c in shipping-service notification-service shipping-platform; do
        helm dependency build "charts/$c" >/dev/null
    done
}

offline() {
    command -v kubeconform >/dev/null || { echo "ERROR: kubeconform not on PATH" >&2; exit 1; }
    deps
    echo "==> helm lint (full profile)"
    helm lint "$CHART" -f values-openshift.yaml
    echo "==> without the Route API: expect 0 Routes"
    n="$(helm template "$RELEASE" "$CHART" -n "$NAMESPACE" -f values-openshift.yaml | grep -c '^kind: Route$' || true)"
    echo "    Routes: $n"; [[ "$n" == 0 ]] || { echo "FAIL: Routes rendered without the API" >&2; exit 1; }
    for p in full minimal; do
        PROFILE="$p"; values_args
        echo "==> profile $p: helm template --api-versions route.openshift.io/v1"
        out="$(helm template "$RELEASE" "$CHART" -n "$NAMESPACE" --api-versions route.openshift.io/v1 "${VALUES[@]}")"
        n="$(grep -c '^kind: Route$' <<<"$out" || true)"; want=2; [[ "$p" == minimal ]] && want=1
        echo "    Routes: $n"; [[ "$n" == "$want" ]] || { echo "FAIL: expected $want Routes" >&2; exit 1; }
        if grep -qE '^\s+runAsUser:' <<<"$out"; then echo "FAIL: runAsUser present in render" >&2; exit 1; fi
        echo "    no runAsUser in the rendered manifests"
        grep -q 'image-registry.openshift-image-registry.svc:5000/hfd-ocp/shipping-service:0.1.0' <<<"$out" \
            || { echo "FAIL: internal registry image ref missing" >&2; exit 1; }
        kubeconform -strict -summary -skip "$CRDS" <<<"$out"
    done
    echo "offline: OK"
}

full() {
    command -v oc >/dev/null || { echo "ERROR: oc not on PATH (eval \$(crc oc-env))" >&2; exit 1; }
    NAMESPACE="$NAMESPACE" ./build-and-push.sh
    deps; values_args
    helm upgrade --install "$RELEASE" "$CHART" -n "$NAMESPACE" "${VALUES[@]}" --wait --rollback-on-failure --timeout 10m
    helm test "$RELEASE" -n "$NAMESPACE" --logs
    echo; oc get routes -n "$NAMESPACE"
    host="$(oc get route "$RELEASE-shipping" -n "$NAMESPACE" -o jsonpath='{.spec.host}')"
    echo "[crc-host]\$ curl -sk https://$host/api/info"
    curl -sk "https://$host/api/info"; echo
}

clean() {
    helm uninstall "$RELEASE" -n "$NAMESPACE" --ignore-not-found || true
    command -v oc >/dev/null && oc delete project "$NAMESPACE" --ignore-not-found || true
}

case "${1:-}" in
    "") full ;;
    offline) offline ;;
    clean) clean ;;
    *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
