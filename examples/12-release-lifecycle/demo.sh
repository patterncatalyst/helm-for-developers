#!/usr/bin/env bash
#
# examples/12-release-lifecycle/demo.sh
#
#   ./demo.sh           # full run: drive one release through success, failure, rollback and inspection
#   ./demo.sh offline   # dependency build, lint, template, unit tests, kubeconform (no cluster)
#   ./demo.sh clean     # uninstall the release and delete the namespace
#
# The release runs in memory mode (no database), so every step finishes quickly.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"

NS=hfd-12
REL=shipping
CHART=shipping-service
FULL="$REL-$CHART"
step() { printf '\n=== %s\n' "$*"; }

offline() {
    local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
    helm dependency build "$CHART"
    helm lint "$CHART"
    helm template "$REL" "$CHART" -n "$NS" > "$tmp/base.yaml"
    helm template "$REL" "$CHART" -n "$NS" --set extras.configMap=true > "$tmp/extras.yaml"
    grep -q -- "-extra" "$tmp/extras.yaml"
    helm unittest "$CHART" shipping-postgres
    kubeconform -strict -summary -ignore-missing-schemas "$tmp/base.yaml" "$tmp/extras.yaml"
    echo "offline checks passed"
}

clean() {
    helm uninstall "$REL" -n "$NS" 2>/dev/null || true
    kubectl delete namespace "$NS" --ignore-not-found
}

full() {
    "$REPO_ROOT/scripts/build-images.sh"
    helm dependency build "$CHART"

    step "1. install: revision 1, --wait uses the kstatus watcher"
    helm upgrade --install "$REL" "$CHART" -n "$NS" --create-namespace --wait --timeout 3m --history-max 5

    step "2. a good upgrade: revision 2"
    helm upgrade "$REL" "$CHART" -n "$NS" --set config.defaultCarrier=FastShip --wait --timeout 3m --history-max 5

    step "3. a bad upgrade with --rollback-on-failure (new ReplicaSet cannot pull the image)"
    helm upgrade "$REL" "$CHART" -n "$NS" --set image.tag=doesnotexist --wait --timeout 60s --rollback-on-failure --history-max 5 || echo "upgrade failed as expected (rc=$?)"
    helm history "$REL" -n "$NS"

    step "4. a bad upgrade that also adds a resource, with --cleanup-on-fail"
    helm upgrade "$REL" "$CHART" -n "$NS" --set extras.configMap=true --set image.tag=doesnotexist --wait --timeout 60s --cleanup-on-fail --history-max 5 || echo "upgrade failed as expected (rc=$?)"
    kubectl -n "$NS" get configmap "$FULL-extra" 2>&1 || echo "the new ConfigMap was cleaned up"
    helm history "$REL" -n "$NS"

    step "5. roll back to the last good revision"
    helm rollback "$REL" 2 -n "$NS" --wait --timeout 3m
    helm status "$REL" -n "$NS"

    step "6. inspect what Helm stored"
    helm get values "$REL" -n "$NS"
    helm get values "$REL" -n "$NS" --all | head -20
    helm get manifest "$REL" -n "$NS" | head -30
    helm get notes "$REL" -n "$NS"
    helm get metadata "$REL" -n "$NS"
    helm get hooks "$REL" -n "$NS"
    helm get all "$REL" -n "$NS" | head -20

    step "7. decode the release Secret by hand"
    kubectl -n "$NS" get secrets -l owner=helm
    local latest; latest="$(kubectl -n "$NS" get secrets -l owner=helm,name="$REL" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sort -V | tail -1)"
    kubectl -n "$NS" get secret "$latest" -o jsonpath='{.data.release}' | base64 -d | base64 -d | gunzip \
        | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r["info"]["status"], r["version"], r["chart"]["metadata"]["name"], r["chart"]["metadata"]["version"])'

    step "8. server-side apply: another field manager owns replicas"
    kubectl -n "$NS" patch deployment "$FULL" --field-manager=hfd-demo --type=merge -p '{"spec":{"replicas":3}}'
    helm upgrade "$REL" "$CHART" -n "$NS" --wait --timeout 3m || echo "upgrade stopped on a field-manager conflict (rc=$?)"
    helm upgrade "$REL" "$CHART" -n "$NS" --force-conflicts --wait --timeout 3m
    kubectl -n "$NS" get deployment "$FULL" -o jsonpath='{.spec.replicas}{"\n"}'

    step "9. adopt an object Helm did not create with --take-ownership"
    kubectl -n "$NS" create configmap "$FULL-extra" --from-literal=purpose=precreated
    helm upgrade "$REL" "$CHART" -n "$NS" --set extras.configMap=true --wait --timeout 3m || echo "upgrade refused to adopt (rc=$?)"
    helm upgrade "$REL" "$CHART" -n "$NS" --set extras.configMap=true --take-ownership --wait --timeout 3m
    kubectl -n "$NS" get configmap "$FULL-extra" -o jsonpath='{.metadata.annotations}{"\n"}'

    step "10. --force-replace recreates objects instead of patching them"
    helm upgrade "$REL" "$CHART" -n "$NS" --set extras.configMap=true --force-replace --wait --timeout 3m

    step "11. --history-max keeps the revision list short"
    helm history "$REL" -n "$NS"
    echo "clean up with: ./demo.sh clean"
}

case "${1:-}" in
    "")      full ;;
    offline) offline ;;
    clean)   clean ;;
    *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
