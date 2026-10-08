#!/usr/bin/env bash
#
# examples/25-gitops-argocd/demo.sh
#
#   ./demo.sh           offline checks, then install Argo CD and sync the OCI, Git and Helm repository Applications
#   ./demo.sh git       only the Git-sourced Application (Argo CD already installed)
#   ./demo.sh helmrepo  only the Application that sources the umbrella from the published Helm repository
#   ./demo.sh offline   render Argo CD, render the chart the way Argo does, parse the manifests
#   ./demo.sh clean     delete the Application, uninstall Argo CD, remove namespaces
#
# Argo CD: namespace argocd, release argocd, https://127.0.0.1:30443 (published NodePort).
# Workload: namespace hfd-25, release name platform (set by helm.releaseName).
# Git Application shipping-git: shipping-service at tag r1.0 of the public repository, namespace hfd-25-git, NodePort 30090.
# Helm repository Application platform-repo: umbrella 1.0.0 from the GitHub Pages repository, namespace hfd-25-repo, NodePorts 30190, 30191.
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
    helm push "$WORK/shipping-platform-1.0.0.tgz" oci://127.0.0.1:5000/charts --plain-http
    echo "==> register the repository and create the Application"
    kubectl apply -f apps/repo-registry.yaml -f apps/shipping-platform-oci.yaml
    kubectl -n argocd wait application/platform --for=jsonpath='{.status.sync.status}'=Synced --timeout=15m
    kubectl -n argocd wait application/platform --for=jsonpath='{.status.health.status}'=Healthy --timeout=15m
    kubectl -n argocd get application platform
    echo "Argo CD UI: https://127.0.0.1:30443 (admin / $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d))"
}

# Probe a published NodePort from the host. Retry covers pods that are not Ready yet.
node_curl() { curl -s --retry 10 --retry-all-errors --retry-delay 1 "$@"; }

git_app() {
    echo "==> the Git-sourced Application: tag r1.0, path examples/25-gitops-argocd/charts/shipping-service"
    kubectl apply -f apps/shipping-service-git.yaml
    kubectl -n argocd wait application/shipping-git --for=jsonpath='{.status.sync.status}'=Synced --timeout=15m
    kubectl -n argocd wait application/shipping-git --for=jsonpath='{.status.health.status}'=Healthy --timeout=15m
    kubectl -n argocd get application shipping-git -o jsonpath='{.status.sync.revision}{"\n"}'
    kubectl -n argocd get application shipping-git
    echo "==> no Helm release behind it:"
    helm list -n hfd-25-git
    kubectl -n hfd-25-git get deploy,svc
    node_curl http://127.0.0.1:30090/api/info; echo
    echo "==> change through the Application spec (a push to the tag would do the same): defaultCarrier -> GIT-Post"
    kubectl -n argocd patch application shipping-git --type merge \
        -p '{"spec":{"source":{"helm":{"valuesObject":{"config":{"defaultCarrier":"GIT-Post"}}}}}}'
    for _ in $(seq 1 60); do
        node_curl http://127.0.0.1:30090/api/info | grep -q GIT-Post && break || sleep 3
    done
    node_curl http://127.0.0.1:30090/api/info; echo
    echo "==> drift: scale the Deployment to 3 by hand; selfHeal restores 1"
    kubectl -n hfd-25-git scale deploy/shipping-shipping-service --replicas=3
    echo "spec.replicas right after the edit: $(kubectl -n hfd-25-git get deploy/shipping-shipping-service -o jsonpath='{.spec.replicas}')"
    start=$SECONDS
    for _ in $(seq 1 60); do
        [ "$(kubectl -n hfd-25-git get deploy/shipping-shipping-service -o jsonpath='{.spec.replicas}')" = 1 ] && break || sleep 1
    done
    echo "spec.replicas reverted to $(kubectl -n hfd-25-git get deploy/shipping-shipping-service -o jsonpath='{.spec.replicas}') after about $((SECONDS - start)) s"
    kubectl -n hfd-25-git get deploy/shipping-shipping-service
    kubectl -n argocd wait application/shipping-git --for=jsonpath='{.status.health.status}'=Healthy --timeout=5m
}

helmrepo_app() {
    local ns=hfd-25-repo
    echo "==> the umbrella from the published Helm repository (no repository Secret, no path)"
    kubectl apply -f apps/shipping-platform-helmrepo.yaml
    kubectl -n argocd wait application/platform-repo --for=jsonpath='{.status.sync.status}'=Synced --timeout=15m
    kubectl -n argocd wait application/platform-repo --for=jsonpath='{.status.health.status}'=Healthy --timeout=15m
    kubectl -n argocd get application platform-repo
    kubectl -n argocd get application platform-repo -o jsonpath='{.spec.source.repoURL}{" "}{.spec.source.chart}{" "}{.status.sync.revision}{"\n"}'
    echo "==> no Helm release behind it:"
    helm list -n "$ns"
    kubectl -n "$ns" get deploy,job,svc
    echo "==> the migration Job ran as an Argo CD sync hook:"
    kubectl -n argocd get application platform-repo \
        -o jsonpath='{range .status.operationState.syncResult.resources[*]}{.kind}/{.name} {.hookType} {.hookPhase}{"\n"}{end}' | grep -E 'PreSync|Sync |PostSync'
    echo "==> Kafka path: create, dispatch, then read the notification"
    local id
    id="$(node_curl -X POST http://127.0.0.1:30190/api/shipments -H 'Authorization: Bearer dev-token' -H 'content-type: application/json' -d "{\"orderId\":$((25000 + RANDOM)),\"address\":\"25 Repo Rd, Springfield\"}" | python3 -I -c 'import sys,json; print(json.load(sys.stdin)["id"])')"
    node_curl -X POST "http://127.0.0.1:30190/api/shipments/$id/dispatch" -H 'Authorization: Bearer dev-token'; echo
    for _ in $(seq 1 30); do
        node_curl http://127.0.0.1:30191/api/notifications | grep -q "\"$id\"\|$id" && break || sleep 2
    done
    node_curl http://127.0.0.1:30191/api/notifications; echo
    node_curl http://127.0.0.1:30190/api/info; echo
    echo "==> change through the Application spec: defaultCarrier -> REPO-Post-2"
    kubectl -n argocd patch application platform-repo --type merge \
        -p '{"spec":{"source":{"helm":{"valuesObject":{"shipping":{"config":{"defaultCarrier":"REPO-Post-2"}}}}}}}'
    for _ in $(seq 1 60); do
        node_curl http://127.0.0.1:30190/api/info | grep -q REPO-Post-2 && break || sleep 3
    done
    node_curl http://127.0.0.1:30190/api/info; echo
    echo "==> drift: scale the Deployment to 3 by hand; selfHeal restores 1"
    kubectl -n "$ns" scale deploy/platform-shipping --replicas=3
    echo "spec.replicas right after the edit: $(kubectl -n "$ns" get deploy/platform-shipping -o jsonpath='{.spec.replicas}')"
    start=$SECONDS
    for _ in $(seq 1 60); do
        [ "$(kubectl -n "$ns" get deploy/platform-shipping -o jsonpath='{.spec.replicas}')" = 1 ] && break || sleep 1
    done
    echo "spec.replicas reverted to $(kubectl -n "$ns" get deploy/platform-shipping -o jsonpath='{.spec.replicas}') after about $((SECONDS - start)) s"
    kubectl -n argocd wait application/platform-repo --for=jsonpath='{.status.health.status}'=Healthy --timeout=5m
    kubectl -n argocd get application platform-repo
}

case "${1:-all}" in
    offline) offline ;;
    clean)
        # Stop auto-sync so self-heal does not recreate the topics, then delete the KafkaTopics
        # while the entity operators still run (finalizer, see chapter 15).
        for app in $(kubectl -n argocd get application -o name 2>/dev/null); do
            kubectl -n argocd patch "$app" --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}' || true
        done
        for ns in hfd-25 hfd-25-git hfd-25-repo; do
            kubectl delete kafkatopic --all -n "$ns" --wait --timeout=120s 2>/dev/null || true
        done
        kubectl -n argocd delete application --all --ignore-not-found --timeout=5m || true
        helm uninstall argocd -n argocd || true
        kubectl delete ns argocd hfd-25 hfd-25-git hfd-25-repo --ignore-not-found
        # The Argo CD chart keeps its CRDs on uninstall (crds.keep=true); remove them for a clean lab.
        kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io --ignore-not-found ;;
    git) git_app ;;
    helmrepo) helmrepo_app ;;
    all|"") offline; live; git_app; helmrepo_app ;;
    *) echo "usage: $0 [offline|git|helmrepo|clean]" >&2; exit 2 ;;
esac
