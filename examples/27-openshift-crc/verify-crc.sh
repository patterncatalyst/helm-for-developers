#!/usr/bin/env bash
#
# verify-crc.sh - check the OpenShift Local deployment end to end.
#
# Verified on OpenShift Local 2.64.0 (OpenShift 4.22.14), both profiles, 2026-10-08, with
# Strimzi 1.2.0 and with Streams for Apache Kafka 3.2.1.
#
#   ./verify-crc.sh                 minimal profile (no operators needed)
#   PROFILE=full ./verify-crc.sh    full profile (CloudNativePG + Strimzi or Streams installed);
#                                   adds a POST, dispatch and notification check through Kafka
#   CONSOLE_CHECK=1 ./verify-crc.sh also checks that the Helm chart repository URL in the
#                                   ProjectHelmChartRepository answers from the console pod
#
# Prints PASS or FAIL for each check and exits non-zero if any check failed.
# Env: NAMESPACE (hfd-ocp), RELEASE (platform), PROFILE (minimal|full), TIMEOUT (10m),
#      TOKEN (bearer token set in values-openshift.yaml, openshift-token), CONSOLE_CHECK (0|1).
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
TOKEN="${TOKEN:-openshift-token}"
CONSOLE_CHECK="${CONSOLE_CHECK:-0}"
REPO_URL="${REPO_URL:-https://patterncatalyst.github.io/helm-for-developers/charts}"
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

# 7. arbitrary UID inside every running application pod
for p in $pods; do
    uid="$(oc exec -n "$NAMESPACE" "$p" -- id -u 2>/dev/null || true)"
    if [[ -n "$uid" && "$uid" != "1001" && "$uid" != "0" ]]; then pass "uid inside $p is $uid (not 1001, not 0)"
    else fail "uid inside $p differs from the image USER 1001" "uid='${uid:-unreadable}'"; fi
done

# 8. Route resolves and answers
host="$(oc get route "$RELEASE-shipping" -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || true)"
if [[ -n "$host" ]]; then
    pass "Route $RELEASE-shipping host: $host"
    check "Route host resolves" getent hosts "$host"
    # The router needs a moment to program a new Route: retry transient 503s.
    code="$(curl -sk --retry 10 --retry-delay 2 -o /tmp/hfd-ocp-info.json -w '%{http_code}' "https://$host/api/info" 2>/dev/null || true)"
    if [[ "$code" == "200" ]]; then pass "curl -k https://$host/api/info -> 200 ($(cat /tmp/hfd-ocp-info.json))"
    else fail "curl -k https://$host/api/info -> 200" "got HTTP '${code:-none}'"; fi
    code="$(curl -sk -o /dev/null -w '%{http_code}' --max-redirs 0 "http://$host/api/info" 2>/dev/null || true)"
    [[ "$code" == 30* ]] && pass "plain HTTP redirects to HTTPS (HTTP $code)" || fail "plain HTTP redirects to HTTPS" "got HTTP '${code:-none}'"
else
    fail "Route $RELEASE-shipping exists" "oc get route returned nothing"
fi

# 9. helm test
check "helm test $RELEASE" helm test "$RELEASE" -n "$NAMESPACE" --logs

# 10. full profile: shipping -> Kafka -> notification through the Routes
if [[ "$PROFILE" == "full" && -n "$host" ]]; then
    nhost="$(oc get route "$RELEASE-notification" -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || true)"
    order=$((RANDOM + 30000))
    payload="{\"orderId\":$order,\"address\":\"1 Verify Way\"}"
    code="$(curl -sk -o /dev/null -w '%{http_code}' -X POST "https://$host/api/shipments" -H 'Content-Type: application/json' -d "$payload" 2>/dev/null || true)"
    [[ "$code" == "401" ]] && pass "POST /api/shipments without a token -> 401" || fail "POST without a token -> 401" "got HTTP '${code:-none}'"
    body="$(curl -sk -X POST "https://$host/api/shipments" -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" -d "$payload" 2>/dev/null || true)"
    sid="$(sed -n 's/.*"id":\([0-9]*\).*/\1/p' <<<"$body")"
    if [[ -n "$sid" ]]; then
        pass "POST /api/shipments with the token -> shipment $sid"
        code="$(curl -sk -o /dev/null -w '%{http_code}' -X POST "https://$host/api/shipments/$sid/dispatch" -H "Authorization: Bearer $TOKEN" 2>/dev/null || true)"
        [[ "$code" == "200" ]] && pass "dispatch shipment $sid -> 200" || fail "dispatch shipment $sid -> 200" "got HTTP '${code:-none}'"
        got=""
        for _ in $(seq 1 15); do
            curl -sk "https://$nhost/api/notifications" 2>/dev/null | grep -q "\"orderId\": *$order" && { got=1; break; }
            sleep 2
        done
        [[ -n "$got" ]] && pass "notification for order $order arrived through Kafka" || fail "notification for order $order arrived through Kafka" "not listed at https://$nhost/api/notifications"
    else
        fail "POST /api/shipments with the token" "response: ${body:0:120}"
    fi
fi

# 11. optional: the Helm chart repository behind the console's Helm view
if [[ "$CONSOLE_CHECK" == "1" ]]; then
    check "ProjectHelmChartRepository present in $NAMESPACE" bash -c "oc get projecthelmchartrepositories -n $NAMESPACE -o name | grep -q ."
    check "console pod reads $REPO_URL/index.yaml" oc exec -n openshift-console deploy/console -- curl -sf -o /dev/null "$REPO_URL/index.yaml"
fi

echo
if (( FAILS )); then echo "verify-crc: $FAILS check(s) FAILED"; exit 1; fi
echo "verify-crc: all checks passed"
