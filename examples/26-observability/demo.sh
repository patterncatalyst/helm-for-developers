#!/usr/bin/env bash
#
# examples/26-observability/demo.sh
#
#   ./demo.sh           offline checks, then install the umbrella with telemetry on and drive a trace
#   ./demo.sh offline   lint, unit tests, template and kubeconform; inspects OTel env and the dashboard
#   ./demo.sh clean     uninstall release platform from hfd-26
#
# Namespace hfd-26, release platform (the final umbrella). Needs the LGTM stack from
# scripts/platform/setup-lgtm.sh. Grafana: http://127.0.0.1:30300 (admin/admin) (published NodePort).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
# shellcheck source=../../scripts/kube-context.sh
source "$REPO_ROOT/scripts/kube-context.sh"
UMBRELLA=charts/shipping-platform
NS=hfd-26
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# Bottom-up: pc-lib into each service chart, then the service charts into the umbrella.
deps() {
    for c in shipping-service notification-service shipping-platform; do
        helm dependency build "charts/$c" >/dev/null
    done
}

offline() {
    command -v kubeconform >/dev/null || { echo "kubeconform not found in .tools/bin" >&2; exit 1; }
    deps
    echo "==> lint --strict and unit tests"
    helm lint --strict "$UMBRELLA" -f "$UMBRELLA/values-dev.yaml" >/dev/null
    helm unittest "$UMBRELLA" | tail -4
    echo "==> template with values-dev and kubeconform"
    helm template platform "$UMBRELLA" -n "$NS" -f "$UMBRELLA/values-dev.yaml" > "$WORK/dev.yaml"
    kubeconform -ignore-missing-schemas -summary < "$WORK/dev.yaml"
    echo "==> OTel environment injected by pc-lib.otelEnv (telemetry on in dev)"
    grep -A1 -E 'name: OTEL_(SDK_DISABLED|EXPORTER_OTLP_ENDPOINT|SERVICE_NAME)' "$WORK/dev.yaml" | grep -E 'name:|value:' | paste - - | sort -u
    grep -q 'value: "http://otel-collector.observability.svc.cluster.local:4318"' "$WORK/dev.yaml"
    echo "==> telemetry stays off with no endpoint (default values)"
    helm template platform "$UMBRELLA" -n "$NS" | grep -A1 'name: OTEL_SDK_DISABLED' | grep -q 'value: "true"'
    echo "==> dashboard ConfigMap carries the sidecar label and parses as JSON"
    helm template platform "$UMBRELLA" -n "$NS" -s templates/dashboard.yaml | python3 -I -c "
import sys, yaml, json
d = yaml.safe_load(sys.stdin)
assert d['metadata']['labels']['grafana_dashboard'] == '1'
j = json.loads(d['data']['shipping-dashboard.json'])
print('   ', d['metadata']['name'], '->', j['title'], '(%d panels)' % len(j['panels']))"
    echo "offline: OK"
}

# Create and dispatch one shipment on the published NodePort; prints its id.
shipment() {
    local id
    id="$(curl -s --retry 10 --retry-all-errors --retry-delay 1 -X POST 127.0.0.1:30080/api/shipments -H 'Authorization: Bearer dev-token' -H 'content-type: application/json' \
        -d "{\"orderId\":$((10000 + RANDOM)),\"address\":\"26 Trace Ave, Springfield\"}" | python3 -I -c 'import sys,json; print(json.load(sys.stdin)["id"])')"
    curl -s -X POST "127.0.0.1:30080/api/shipments/$id/dispatch" -H 'Authorization: Bearer dev-token' >/dev/null
    echo "$id"
}

live() {
    deps
    "$REPO_ROOT/scripts/build-images.sh"
    echo "==> let the Grafana sidecar watch every namespace (default: its own)"
    helm upgrade grafana grafana/grafana --version 8.5.0 -n observability --reuse-values \
        --set sidecar.dashboards.searchNamespace=ALL --wait --timeout 5m
    echo "==> install the umbrella with telemetry on"
    helm upgrade --install platform "$UMBRELLA" -n "$NS" --create-namespace -f "$UMBRELLA/values-dev.yaml" \
        --wait --rollback-on-failure --timeout 8m
    echo "==> create and dispatch a shipment"
    local id
    id="$(shipment)"
    # Spans and metrics are exported on a timer and rate() needs two samples, so poll with bounded retries.
    echo "==> the trace holds spans from both services"
    local tid="" start=$SECONDS
    while :; do
        tid="$(curl -s -u admin:admin -G 127.0.0.1:30300/api/datasources/proxy/uid/tempo/api/search \
            --data-urlencode "q={ span.http.target =~ \".*shipments/$id/dispatch\" }" \
            | python3 -I -c 'import sys,json; t=json.load(sys.stdin).get("traces") or []; print(t[0]["traceID"] if t else "")' 2>/dev/null || true)"
        [ -n "$tid" ] && break
        [ $((SECONDS - start)) -ge 180 ] && { echo "FAIL: no Tempo trace for shipment $id after 180 s" >&2; exit 1; }
        sleep 10
    done
    echo "   trace found after $((SECONDS - start)) s"
    curl -s -u admin:admin "127.0.0.1:30300/api/datasources/proxy/uid/tempo/api/traces/$tid" | python3 -I -c "
import sys, json
names = {a['value']['stringValue'] for b in json.load(sys.stdin)['batches'] for a in b['resource']['attributes'] if a['key'] == 'service.name'}
print('   trace $tid services:', sorted(names))
assert names >= {'platform-shipping', 'platform-notification'}"
    echo "==> TraceQL through Grafana: dispatch spans of platform-shipping"
    curl -s -u admin:admin -G 127.0.0.1:30300/api/datasources/proxy/uid/tempo/api/search \
        --data-urlencode 'q={ resource.service.name = "platform-shipping" && span.http.target =~ ".*dispatch.*" }' \
        | python3 -I -c 'import sys,json; [print("   trace", t["traceID"], t["rootTraceName"]) for t in json.load(sys.stdin)["traces"]]'
    echo "==> request-rate panel query returns series in Mimir (polls up to 180 s)"
    local out="" n=0
    start=$SECONDS
    while :; do
        out="$(curl -s -u admin:admin -G 127.0.0.1:30300/api/datasources/proxy/uid/mimir/api/v1/query \
            --data-urlencode 'query=sum by (job) (rate(http_server_duration_milliseconds_count{job=~".*/platform-.*"}[5m]))' \
            | python3 -I -c 'import sys,json; [print("   ", x["metric"]) for x in json.load(sys.stdin)["data"]["result"]]' 2>/dev/null || true)"
        [ -n "$out" ] && break
        [ $((SECONDS - start)) -ge 180 ] && { echo "FAIL: Mimir returned no series for the request-rate query after 180 s" >&2; exit 1; }
        n=$((n + 1)); shipment >/dev/null   # keep a little traffic flowing between attempts
        sleep 15
    done
    echo "$out"
    echo "   series found after $((SECONDS - start)) s ($n retries)"
    echo "==> dashboard loaded by the sidecar"
    curl -s -u admin:admin -G 127.0.0.1:30300/api/search --data-urlencode 'query=Shipping platform' \
        | python3 -I -c 'import sys,json; [print("   ", d["title"], "folder:", d.get("folderTitle")) for d in json.load(sys.stdin)]'
}

case "${1:-all}" in
    offline) offline ;;
    clean)
        # Delete the KafkaTopic while the entity operator still runs, so its finalizer is removed.
        kubectl delete kafkatopic --all -n "$NS" --wait --timeout=120s 2>/dev/null || true
        helm uninstall platform -n "$NS" || true ;;
    all|"") offline; live ;;
    *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
