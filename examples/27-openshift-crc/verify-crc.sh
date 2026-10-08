#!/usr/bin/env bash
#
# verify-crc.sh - check the OpenShift Local deployment end to end.
#
# UNTESTED on the authoring machine; run on the CRC host.
#
#   ./verify-crc.sh                 minimal profile (no operators needed)
#   PROFILE=full ./verify-crc.sh    full profile (CloudNativePG + Strimzi installed)
#
# Prints PASS or FAIL for each check and exits non-zero if any check failed.
# Env: NAMESPACE (hfd-ocp), RELEASE (platform), PROFILE (minimal|full), TIMEOUT (10m).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" && cd "$HERE"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
# Helm 4 comes from the project env when present; otherwise the helm on PATH must be 4.x.
if [[ -f "$REPO_ROOT/scripts/env.sh" ]]; then
    # shellcheck source=../../scripts/env.sh
    source "$REPO_ROOT/scripts/env.sh" || true
fi

NAMESPACE="${NAMESPACE:-hfd-ocp}"
RELEASE="${RELEASE:-platform}"
PROFILE="${PROFILE:-minimal}"
TIMEOUT="${TIMEOUT:-10m}"
CHART="charts/shipping-platform"
VALUES=(-f values-openshift.yaml)
[[ "$PROFILE" == "minimal" ]] && VALUES+=(-f values-openshift-minimal.yaml)

FAILS=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      %s\n' "$2"; FAILS=$((FAILS + 1)); }
check() { # <label> <command...>
    local label="$1"; shift
    local out
    if out="$("$@" 2>&1)"; then pass "$label"; else fail "$label" "$(tail -3 <<<"$out" | tr '\n' ' ')"; fi
}

hv="$(helm version --short 2>/dev/null || true)"
case "$hv" in v4.*) pass "helm is 4.x ($hv)" ;; *) fail "helm is 4.x" "found '${hv:-none}'" ;; esac

# 1. crc status
if command -v crc >/dev/null 2>&1; then
    out="$(crc status 2>&1)"
    if grep -qE 'OpenShift:[[:space:]]+Running' <<<"$out"; then pass "crc status: OpenShift Running"
    else fail "crc status: OpenShift Running" "$(head -3 <<<"$out" | tr '\n' ' ')"; fi
else
    fail "crc status" "crc not on PATH"
fi

# 2. oc whoami
if command -v oc >/dev/null 2>&1 && who="$(oc whoami 2>&1)"; then pass "oc whoami ($who)"
else fail "oc whoami" "${who:-oc not on PATH}; log in with oc login -u kubeadmin https://api.crc.testing:6443"; fi

# 3. project (idempotent)
if oc get project "$NAMESPACE" >/dev/null 2>&1 || oc new-project "$NAMESPACE" >/dev/null 2>&1; then
    oc project "$NAMESPACE" >/dev/null 2>&1; pass "oc new-project $NAMESPACE (idempotent)"
else fail "oc new-project $NAMESPACE"; fi

# 4. images pushed to the internal registry
if NAMESPACE="$NAMESPACE" ./build-and-push.sh >/tmp/hfd-ocp-push.log 2>&1; then pass "image push to the internal registry"
else fail "image push to the internal registry" "see /tmp/hfd-ocp-push.log: $(tail -2 /tmp/hfd-ocp-push.log | tr '\n' ' ')"; fi
for svc in shipping-service notification-service; do
    check "ImageStream $svc has tag 0.1.0" bash -c "oc get imagestream $svc -n $NAMESPACE -o jsonpath='{.status.tags[*].tag}' | grep -qw 0.1.0"
done

# 5. install
for c in shipping-service notification-service shipping-platform; do helm dependency build "charts/$c" >/dev/null 2>&1; done
if out="$(helm upgrade --install "$RELEASE" "$CHART" -n "$NAMESPACE" "${VALUES[@]}" --wait --rollback-on-failure --timeout "$TIMEOUT" 2>&1)"; then
    pass "helm upgrade --install $RELEASE ($PROFILE profile) --wait --rollback-on-failure"
else
    fail "helm upgrade --install $RELEASE ($PROFILE profile)" "$(tail -3 <<<"$out" | tr '\n' ' ')"
fi

# 6. pods Ready and admitted by restricted-v2
pods="$(oc get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE" -o name 2>/dev/null | grep -E 'shipping|notification' || true)"
[[ -n "$pods" ]] || fail "application pods found" "no pods with app.kubernetes.io/instance=$RELEASE"
for p in $pods; do
    ready="$(oc get "$p" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
    scc="$(oc get "$p" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.openshift\.io/scc}' 2>/dev/null)"
    if [[ "$ready" == "True" && "$scc" == "restricted-v2" ]]; then pass "$p Ready, openshift.io/scc=$scc"
    else fail "$p Ready with restricted-v2" "ready=$ready scc=$scc"; fi
done

# 7. arbitrary UID inside a running pod
first="$(head -1 <<<"$pods")"
if [[ -n "$first" ]]; then
    uid="$(oc exec -n "$NAMESPACE" "$first" -- id -u 2>/dev/null || true)"
    if [[ -n "$uid" && "$uid" != "1001" && "$uid" != "0" ]]; then pass "uid inside $first is $uid (not 1001, not 0)"
    else fail "uid inside $first differs from the image USER 1001" "uid='${uid:-unreadable}'"; fi
fi

# 8. Route resolves and answers
host="$(oc get route "$RELEASE-shipping" -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || true)"
if [[ -n "$host" ]]; then
    pass "Route $RELEASE-shipping host: $host"
    check "Route host resolves" getent hosts "$host"
    code="$(curl -sk -o /tmp/hfd-ocp-info.json -w '%{http_code}' "https://$host/api/info" 2>/dev/null || true)"
    if [[ "$code" == "200" ]]; then pass "curl -k https://$host/api/info -> 200 ($(cat /tmp/hfd-ocp-info.json))"
    else fail "curl -k https://$host/api/info -> 200" "got HTTP '${code:-none}'"; fi
    code="$(curl -sk -o /dev/null -w '%{http_code}' --max-redirs 0 "http://$host/api/info" 2>/dev/null || true)"
    [[ "$code" == 30* ]] && pass "plain HTTP redirects to HTTPS (HTTP $code)" || fail "plain HTTP redirects to HTTPS" "got HTTP '${code:-none}'"
else
    fail "Route $RELEASE-shipping exists" "oc get route returned nothing"
fi

# 9. helm test
check "helm test $RELEASE" helm test "$RELEASE" -n "$NAMESPACE" --logs

echo
if (( FAILS )); then echo "verify-crc: $FAILS check(s) FAILED"; exit 1; fi
echo "verify-crc: all checks passed"
