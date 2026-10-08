#!/usr/bin/env bash
#
# examples/14-chart-testing/demo.sh
#
#   ./demo.sh            # offline checks, then install into hfd-14, run helm test, run ct install
#   ./demo.sh offline    # helm lint --strict, helm unittest, kubeconform, ct lint, plus three planted failures
#   ./demo.sh clean      # uninstall the release and delete namespace hfd-14
#
# Offline mode needs network access only to fetch kubeconform schemas (cached under $SCHEMA_CACHE).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
# shellcheck source=../../scripts/kube-context.sh
source "$REPO_ROOT/scripts/kube-context.sh"

NS=hfd-14
REL=shipping
CHART=charts/shipping-service
K8S_VERSION=1.34.0
SCHEMA_CACHE="${SCHEMA_CACHE:-${TMPDIR:-/tmp}/hfd-kubeconform-cache}"
CT_FLAGS=(--chart-yaml-schema "$REPO_ROOT/.tools/ct/chart_schema.yaml" --lint-conf "$REPO_ROOT/.tools/ct/lintconf.yaml"
          --check-version-increment=false --validate-maintainers=false)
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

step() { printf '\n==> %s\n' "$*"; }

# expect_fail <pattern> <command...>: the command must fail and its output must match.
expect_fail() {
    local pattern="$1"; shift
    local out rc=0
    out="$("$@" 2>&1)" || rc=$?
    printf '%s\n' "$out" | sed -n '1,14p'
    [[ $rc -ne 0 ]] || { echo "FAIL: expected a failure from: $*" >&2; exit 1; }
    grep -Eq "$pattern" <<<"$out" || { echo "FAIL: output did not match /$pattern/" >&2; exit 1; }
}

offline() {
    step "helm lint --strict, with the chart defaults and with the CI values"
    helm lint --strict "$CHART"
    helm lint --strict "$CHART" -f "$CHART/ci/ci-values.yaml"

    step "helm unittest: six suites, one of them snapshots"
    helm unittest "$CHART"

    step "kubeconform on the rendered chart, test pod included"
    helm template "$REL" "$CHART" -f "$CHART/ci/ci-values.yaml" | \
        kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" -cache "$(mkdir -p "$SCHEMA_CACHE" && echo "$SCHEMA_CACHE")"

    step "ct lint: Chart.yaml schema, yamllint, helm lint on every ci/*-values.yaml"
    ct lint --config ct.yaml --all

    step "Planted failure 1: .helmignore with tests/ instead of /tests/ drops templates/tests/"
    cp -r "$CHART" "$WORK/ignore-trap"
    sed -i 's#^/tests/#tests/#' "$WORK/ignore-trap/.helmignore"
    expect_fail "could not find template" helm template "$REL" "$WORK/ignore-trap" --show-only templates/tests/test-connection.yaml
    echo "    anchored /tests/ keeps the test pod and still excludes the unit-test directory:"
    helm template "$REL" "$CHART" --show-only templates/tests/test-connection.yaml | sed -n '2,4p'

    step "Planted failure 2: a snapshot no longer matches (a default value changed)"
    cp -r "$CHART" "$WORK/snapshot"
    sed -i 's/defaultCarrier: ACME-Post/defaultCarrier: Globex-Freight/' "$WORK/snapshot/values.yaml"
    expect_fail "Snapshot Summary: 1 snapshot failed" helm unittest -f 'tests/snapshot_test.yaml' "$WORK/snapshot"
    echo "    review the diff, then accept it with -u:"
    helm unittest -u -f 'tests/snapshot_test.yaml' "$WORK/snapshot" | tail -5

    step "Planted failure 3: ct lint rejects an unknown Chart.yaml key"
    cp -r "$CHART" "$WORK/chartyaml" && mkdir -p "$WORK/charts" && mv "$WORK/chartyaml" "$WORK/charts/shipping-service"
    echo "owner: team-shipping" >> "$WORK/charts/shipping-service/Chart.yaml"
    expect_fail "Unexpected element" ct lint --charts "$WORK/charts/shipping-service" "${CT_FLAGS[@]}"
}

cluster() {
    step "Build the image and install with the CI values"
    "$REPO_ROOT/scripts/build-images.sh" shipping-service
    helm upgrade --install "$REL" "$CHART" -n "$NS" --create-namespace -f "$CHART/ci/ci-values.yaml" \
        --wait --rollback-on-failure --timeout 3m

    step "helm test runs the pod annotated helm.sh/hook: test"
    helm test "$REL" -n "$NS" --timeout 3m

    step "ct install: install, helm test and clean up in a generated namespace"
    # ct has no context flag and runs kubectl itself, so give it a kubeconfig that holds only helm4dev.
    hfd_pinned_kubeconfig "$WORK/kubeconfig"
    KUBECONFIG="$WORK/kubeconfig" ct install --charts "$CHART" --helm-extra-args '--timeout 3m --kube-context helm4dev'
}

clean() {
    helm uninstall "$REL" -n "$NS" 2>/dev/null || true
    kubectl delete namespace "$NS" --ignore-not-found
}

case "${1:-}" in
    offline) offline ;;
    clean) clean ;;
    "") offline; cluster ;;
    *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
