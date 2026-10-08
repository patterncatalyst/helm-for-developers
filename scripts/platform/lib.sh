#!/usr/bin/env bash
# lib.sh - shared helpers for the platform scripts. Source it; do not execute it.
#
# Safety rule: every platform script operates on the minikube profile "helm4dev"
# and nothing else. Other profiles (for example "datamesh") are never touched,
# and every kubectl/helm call pins its context explicitly, so the current
# kubectl context does not matter.

# Capture the caller's MINIKUBE_PROFILE before env.sh overwrites it, so a
# mistaken override (for example MINIKUBE_PROFILE=datamesh) is refused, not ignored.
_lib_incoming_profile="${MINIKUBE_PROFILE:-}"
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../env.sh
source "$_lib_dir/../env.sh" || exit 1
unset _lib_dir

PROFILE="helm4dev"
if [[ -n "$_lib_incoming_profile" && "$_lib_incoming_profile" != "$PROFILE" ]]; then
    printf 'ERROR: MINIKUBE_PROFILE=%s. These scripts only operate on the "%s" profile.\n' \
        "$_lib_incoming_profile" "$PROFILE" >&2
    exit 1
fi
unset _lib_incoming_profile
export MINIKUBE_PROFILE="$PROFILE"

OBS_NS="${OBS_NAMESPACE:-observability}"
CNPG_NS="cnpg-system"
STRIMZI_NS="strimzi"

# Host ports published when the profile is created (minikube start --ports).
# Host port = NodePort, so 127.0.0.1:<port> reaches the service directly. No
# SSH tunnels, kubectl port-forward, or minikube tunnel anywhere in the project.   # forbidden-ok
# Ports are fixed at profile creation: adding one means recreating the profile
# (scripts/platform/setup-profile.sh --replace --confirm=helm4dev).
HFD_NODE_PORTS=(
    5000    # registry addon (hostPort on the node): build-images.sh push, ch20 helm push, ch24 digest pin, ch25 OCI source
    30080   # shipping-service NodePort: ch03-ch12, ch15-ch17, ch19-ch21, ch24-ch26
    30081   # notification-service NodePort: ch15-ch17, ch24-ch26
    30082   # Argo CD server HTTP NodePort: ch25 (argocd-values.yaml)
    30090   # ch25 Git Application shipping-git: shipping-service NodePort
    30190   # ch25 Helm repository Application platform-repo: shipping NodePort
    30191   # ch25 Helm repository Application platform-repo: notification NodePort
    30300   # Grafana NodePort: ch26 (scripts/platform/setup-lgtm.sh)
    30443   # Argo CD server HTTPS NodePort: ch25 (argocd-values.yaml)
)

step() { printf '\n==> %s\n' "$1"; }
ok()   { printf '    ok: %s\n' "$1"; }
skip() { printf '    skip: %s\n' "$1"; }
fail() { printf '\nERROR: %s\n' "$1" >&2; exit 1; }

# Context-pinned wrappers: never rely on the current kubectl context.
kc() { kubectl --context "$PROFILE" "$@"; }
hc() { helm --kube-context "$PROFILE" "$@"; }

require_tools() {
    local t
    for t in "$@"; do
        command -v "$t" >/dev/null 2>&1 || fail "$t is not on PATH"
    done
}

# The profile must exist and its API server must answer.
require_cluster() {
    require_tools kubectl helm minikube
    kc get --raw=/readyz >/dev/null 2>&1 \
        || fail "cluster '$PROFILE' is not reachable. Start it with: scripts/platform/setup-profile.sh"
}

# Idempotent helm repo registration: add_repo <name> <url>
add_repo() {
    if hc repo list 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$1"; then
        hc repo update "$1" >/dev/null
    else
        hc repo add "$1" "$2" >/dev/null
    fi
}
