#!/usr/bin/env bash
#
# cluster-status.sh - read-only health report for the helm4dev cluster.
# Changes nothing. Exit 1 if any area needs attention.

set -uo pipefail
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

PROBLEMS=0
bad()  { printf '    FAIL: %s\n' "$1"; PROBLEMS=$((PROBLEMS + 1)); }

step "minikube profile $PROFILE"
if minikube status -p "$PROFILE" >/dev/null 2>&1; then
    ok "running"
else
    bad "not running. Start it with scripts/platform/setup-profile.sh"
    exit 1
fi

step "Control plane"
if kc get --raw=/readyz >/dev/null 2>&1; then ok "API server /readyz"; else bad "API server not responding"; fi
cp_bad="$(kc get pods -n kube-system --no-headers 2>/dev/null \
    | grep -iE 'etcd|scheduler|controller-manager|apiserver' | grep -ivE 'Running|Completed' || true)"
if [[ -n "$cp_bad" ]]; then bad "control-plane pods unhealthy"; printf '%s\n' "$cp_bad" | sed 's/^/        /'; else ok "control-plane pods Running"; fi

step "Registry addon"
if minikube addons list -p "$PROFILE" -o json 2>/dev/null \
    | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)["registry"]["Status"] == "enabled" else 1)' 2>/dev/null; then
    ok "registry addon enabled"
else
    bad "registry addon not enabled"
fi

step "Operators"
check_ns() { # <namespace> <label>
    local ns="$1" label="$2" notready
    if ! kc get ns "$ns" >/dev/null 2>&1; then bad "$label: namespace $ns missing"; return; fi
    notready="$(kc get pods -n "$ns" --no-headers 2>/dev/null | grep -ivE 'Running|Completed' || true)"
    if [[ -z "$notready" ]]; then ok "$label ($ns): pods Running"; else bad "$label ($ns): pods not healthy"; printf '%s\n' "$notready" | sed 's/^/        /'; fi
}
check_ns "$CNPG_NS" "CloudNativePG operator"
check_ns "$STRIMZI_NS" "Strimzi operator"
kc get crd clusters.postgresql.cnpg.io >/dev/null 2>&1 && ok "CRD clusters.postgresql.cnpg.io" || bad "CNPG CRDs missing"
kc get crd kafkas.kafka.strimzi.io >/dev/null 2>&1 && ok "CRD kafkas.kafka.strimzi.io" || bad "Strimzi CRDs missing"

step "Observability"
check_ns "$OBS_NS" "LGTM"

step "Examples (hfd-* namespaces)"
kc get ns --no-headers 2>/dev/null | awk '$1 ~ /^hfd-/ {print "    " $1}' || true

step "Verdict"
if (( PROBLEMS == 0 )); then ok "platform healthy"; else printf '    %d area(s) need attention\n' "$PROBLEMS"; exit 1; fi
