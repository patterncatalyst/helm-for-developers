#!/usr/bin/env bash
#
# examples/01-lab-setup/demo.sh
#
#   ./demo.sh            # full run: install tools, bootstrap the cluster, build images, report status
#   ./demo.sh offline    # preflight only: tools present, pinned versions, plugins, bash -n on the scripts
#   ./demo.sh clean      # nothing to stop: host access is published NodePorts (the cluster stays; see the README to delete it)
#
# The full run is idempotent. It changes nothing outside .tools/ on the host and
# nothing outside the helm4dev minikube profile.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Pinned versions (CONTRIBUTING.md, 2026-10-08).
HELM_WANT="v4.3.0"; UNITTEST_WANT="1.2.1"; DIFF_WANT="3.15.15"
KUBECONFORM_WANT="v0.8.0"; CT_WANT="3.15.0"; COSIGN_WANT="v3.1.3"

step() { printf '\n==> %s\n' "$1"; }
ok()   { printf '    ok: %s\n' "$1"; }
bad()  { printf '    FAIL: %s\n' "$1"; PROBLEMS=$((PROBLEMS + 1)); }

preflight() {
    PROBLEMS=0
    # shellcheck source=../../scripts/env.sh
    source "$REPO_ROOT/scripts/env.sh" || { echo "run scripts/install-tools.sh first"; return 1; }

    step "Project-local Helm 4"
    got="$(helm version --short)"
    [[ "$got" == "$HELM_WANT"* ]] && ok "helm $got" || bad "helm is $got, want $HELM_WANT"
    [[ "$(command -v helm)" == "$REPO_ROOT/.tools/bin/helm" ]] \
        && ok "helm resolves to .tools/bin" || bad "helm resolves to $(command -v helm)"
    [[ "$HELM_CACHE_HOME" == "$REPO_ROOT/.tools/helm/cache" ]] \
        && ok "HELM_CACHE_HOME is project-local" || bad "HELM_CACHE_HOME is $HELM_CACHE_HOME"

    step "Pinned companion tools"
    kubeconform -v 2>&1 | grep -q "$KUBECONFORM_WANT" && ok "kubeconform $KUBECONFORM_WANT" || bad "kubeconform version"
    ct version 2>&1 | grep -q "$CT_WANT" && ok "chart-testing $CT_WANT" || bad "chart-testing version"
    cosign version 2>&1 | grep -q "$COSIGN_WANT" && ok "cosign $COSIGN_WANT" || bad "cosign version"
    helm plugin list | awk 'NR>1{print $1, $2}' | grep -q "^unittest $UNITTEST_WANT$" \
        && ok "helm-unittest $UNITTEST_WANT" || bad "helm-unittest $UNITTEST_WANT not installed"
    helm plugin list | awk 'NR>1{print $1, $2}' | grep -q "^diff $DIFF_WANT$" \
        && ok "helm-diff $DIFF_WANT" || bad "helm-diff $DIFF_WANT not installed"

    step "Cluster tooling on PATH"
    for t in minikube kubectl; do
        command -v "$t" >/dev/null 2>&1 && ok "$t" || bad "$t is not on PATH"
    done
    if command -v docker >/dev/null 2>&1 || command -v podman >/dev/null 2>&1; then
        ok "container engine present"
    else
        bad "neither docker nor podman is on PATH"
    fi

    step "Global Helm is left alone"
    if [[ -x "$HOME/.local/bin/helm" ]]; then
        ok "global helm still reports: $(PATH="$HOME/.local/bin" HELM_CONFIG_HOME="" "$HOME/.local/bin/helm" version --short 2>/dev/null || echo unknown)"
    else
        ok "no global helm to protect"
    fi

    step "bash -n on the lab scripts"
    for f in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/scripts/platform/*.sh; do
        bash -n "$f" && ok "${f#"$REPO_ROOT"/}" || bad "syntax: $f"
    done

    (( PROBLEMS == 0 )) || { printf '\nPreflight: %d problem(s).\n' "$PROBLEMS"; return 1; }
    printf '\nPreflight: OK\n'
}

case "${1:-}" in
    offline)
        preflight
        ;;
    clean)
        ;;
    "")
        step "1/5 Install project-local tools"
        "$REPO_ROOT/scripts/install-tools.sh"
        step "2/5 Preflight"
        preflight
        step "3/5 Bootstrap helm4dev (profile, registry addon, operators, LGTM)"
        "$REPO_ROOT/scripts/platform/bootstrap.sh"
        step "4/5 Build the service images into the profile"
        "$REPO_ROOT/scripts/build-images.sh"
        step "5/5 Cluster status"
        "$REPO_ROOT/scripts/platform/cluster-status.sh"
        ;;
    *)
        echo "usage: $0 [offline|clean]" >&2; exit 2
        ;;
esac
