#!/usr/bin/env bash
#
# examples/25-gitops-argocd/demo.sh
#
#   ./demo.sh           offline checks, then install Argo CD and sync the OCI Application
#   ./demo.sh offline   render Argo CD, render the chart the way Argo does, parse the manifests
#   ./demo.sh clean     delete the Application, uninstall Argo CD, remove namespaces
#
# Argo CD: namespace argocd, release argocd, https://127.0.0.1:8443 after `scripts/tunnel.sh argocd`.
# Workload: namespace hfd-25, release name platform (set by helm.releaseName).
# apps/shipping-platform-git.yaml is pending until the GitHub repository exists; it is not applied.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
ARGO_CHART_VERSION=10.10.1       # Argo CD v3.5.4
UMBRELLA=charts/shipping-platform
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# Bottom-up: pc-lib into each service chart, then the service charts into the umbrella.
deps() {
    for c in shipping-service notification-service shipping-platform; do
        helm dependency build "charts/$c" >/dev/null
    done
}

offline() {
    command -v kubeconform >/dev/null || { echo "kubeconform not found in .tools/bin" >&2; exit 1; }
    helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
    echo "==> Argo CD chart $ARGO_CHART_VERSION renders under $(helm version --short)"
    if helm template argocd argo/argo-cd --version "$ARGO_CHART_VERSION" -n argocd -f argocd-values.yaml > "$WORK/argocd.yaml" 2>"$WORK/err"; then
        grep -q 'nodePort: 30443' "$WORK/argocd.yaml"
        kubeconform -ignore-missing-schemas -summary < "$WORK/argocd.yaml"
    else
        echo "    skipped: chart not reachable ($(head -1 "$WORK/err"))"
    fi
    echo "==> the chart as Argo CD renders it: helm template, valueFiles then valuesObject"
    deps
    python3 -I - <<'PY' > "$WORK/object.yaml"
import yaml
app = yaml.safe_load(open("apps/shipping-platform-oci.yaml"))
print(yaml.safe_dump(app["spec"]["source"]["helm"]["valuesObject"]))
PY
    helm template platform "$UMBRELLA" -n hfd-25 -f "$UMBRELLA/values-dev.yaml" -f "$WORK/object.yaml" > "$WORK/platform.yaml"
    kubeconform -ignore-missing-schemas -summary < "$WORK/platform.yaml"
    grep -q 'ARGO-Post' "$WORK/platform.yaml"
    echo "==> helm hook annotations Argo CD maps to sync hooks:"
    grep -E 'helm.sh/hook(-weight)?":' "$WORK/platform.yaml" | sort | uniq -c
    echo "==> Application manifests parse"
    python3 -I - <<'PY'
import glob, yaml
for f in sorted(glob.glob("apps/*.yaml")):
    for d in yaml.safe_load_all(open(f)):
        print(f"    {f}: {d['kind']}/{d['metadata']['name']}")
PY
    echo "offline: OK"
}

live() {
    deps
    "$REPO_ROOT/scripts/build-images.sh"
    echo "==> install Argo CD"
    helm upgrade --install argocd argo/argo-cd --version "$ARGO_CHART_VERSION" -n argocd --create-namespace \
        -f argocd-values.yaml --wait --timeout 10m --rollback-on-failure
    echo "==> package the umbrella and push it to the registry addon"
    helm package "$UMBRELLA" -d "$WORK" >/dev/null
    "$REPO_ROOT/scripts/tunnel.sh" registry argocd
    helm push "$WORK/shipping-platform-1.0.0.tgz" oci://127.0.0.1:5000/charts --plain-http
    echo "==> register the repository and create the Application"
    kubectl apply -f apps/repo-registry.yaml -f apps/shipping-platform-oci.yaml
    kubectl -n argocd wait application/platform --for=jsonpath='{.status.sync.status}'=Synced --timeout=15m
    kubectl -n argocd wait application/platform --for=jsonpath='{.status.health.status}'=Healthy --timeout=15m
    kubectl -n argocd get application platform
    echo "Argo CD UI: https://127.0.0.1:8443 (admin / $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d))"
}

case "${1:-all}" in
    offline) offline ;;
    clean)
        kubectl -n argocd delete application --all --ignore-not-found --timeout=5m || true
        helm uninstall argocd -n argocd || true
        kubectl delete ns argocd hfd-25 hfd-25-git --ignore-not-found
        # The Argo CD chart keeps its CRDs on uninstall (crds.keep=true); remove them for a clean lab.
        kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io --ignore-not-found ;;
    all|"") offline; live ;;
    *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
