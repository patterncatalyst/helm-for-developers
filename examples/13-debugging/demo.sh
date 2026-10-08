#!/usr/bin/env bash
#
# examples/13-debugging/demo.sh
#
#   ./demo.sh            # offline ladder, then install into hfd-13 and use the cluster-side rungs
#   ./demo.sh offline    # lint --strict, template --debug, kubeconform, helm diff local, the broken chart; no cluster
#   ./demo.sh clean      # uninstall the release and delete namespace hfd-13
#
# Offline mode needs network access only to fetch kubeconform schemas (cached under $SCHEMA_CACHE).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"

NS=hfd-13
REL=shipping
GOOD=charts/shipping-service
PG=charts/shipping-postgres
K8S_VERSION=1.34.0
SCHEMA_CACHE="${SCHEMA_CACHE:-${TMPDIR:-/tmp}/hfd-kubeconform-cache}"
CRD_CATALOG='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

step() { printf '\n==> %s\n' "$*"; }

# kc: kubeconform with the built-in Kubernetes schemas plus the datree CRDs-catalog.
kc() {
    mkdir -p "$SCHEMA_CACHE"
    kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" -cache "$SCHEMA_CACHE" \
        -schema-location default -schema-location "$CRD_CATALOG" "$@"
}

# render_kc <chart>: render a chart and validate the output.
render_kc() { helm template "$REL" "$1" | kc; }

# bad_cr: the CNPG Cluster with instances rewritten to a string after rendering. (Passing
# the same value with --set stops earlier, at the chart's values.schema.json.)
bad_cr() { helm template "$REL" "$PG" | sed 's/^  instances: 1$/  instances: "one"/' | kc; }

# expect_fail <pattern> <command...>: the command must fail and its output must match.
expect_fail() {
    local pattern="$1"; shift
    local out rc=0
    out="$("$@" 2>&1)" || rc=$?
    printf '%s\n' "$out" | sed -n '1,12p'
    [[ $rc -ne 0 ]] || { echo "FAIL: expected a failure from: $*" >&2; exit 1; }
    grep -Eq "$pattern" <<<"$out" || { echo "FAIL: output did not match /$pattern/" >&2; exit 1; }
}

offline() {
    step "Rung 1: helm lint --strict on the good chart"
    helm lint --strict "$GOOD"

    step "Rung 2: helm template --debug --show-only (stdout only; the DEBUG log lines go to stderr)"
    helm template "$REL" "$GOOD" --show-only templates/configmap.yaml --debug 2>/dev/null

    step "Rung 3: kubeconform on the rendered chart, then on a CNPG Cluster using the CRDs-catalog"
    render_kc "$GOOD"
    render_kc "$PG"

    step "Rung 3b: the same CR with a wrong type is rejected by its CRD schema"
    expect_fail 'instances' bad_cr

    step "Rung 4: helm diff local shows what a values change does, with no cluster"
    cp -r "$GOOD" "$WORK/changed"
    sed -i 's/^replicaCount: 1/replicaCount: 2/; s/defaultCarrier: ACME-Post/defaultCarrier: Globex-Freight/' "$WORK/changed/values.yaml"
    helm diff local "$GOOD" "$WORK/changed" | sed -n '1,30p'

    step "The broken chart, one fault per rung"
    ladder
}

# ladder: apply one fix per stage to a copy of broken/shipping-service and show the next failure.
ladder() {
    local W="$WORK/broken"
    cp -r broken/shipping-service "$W"

    echo "--- fault 1: values violate values.schema.json (lint and template stop before rendering)"
    expect_fail "got string, want integer" helm lint --strict "$W"
    sed -i 's/^replicaCount: "1"/replicaCount: 1/' "$W/values.yaml"

    echo "--- fault 2: a nil pointer in a template (the error names the file and line)"
    expect_fail "nil pointer evaluating interface" helm template "$REL" "$W"
    sed -i 's/\.Values\.logging\.level/.Values.config.logLevel/' "$W/templates/configmap.yaml"

    echo "--- fault 3: valid template, invalid YAML after rendering"
    expect_fail "mapping values are not allowed" helm template "$REL" "$W"
    echo "    --debug prints the rendered text that failed to parse:"
    helm template "$REL" "$W" --show-only templates/service.yaml --debug 2>/dev/null | sed -n '1,8p' || true
    sed -i 's/| indent 4 }}/| nindent 4 }}/' "$W/templates/service.yaml"

    echo "--- fault 4: lint passes, lint --strict fails on a deprecated API"
    helm lint "$W" | tail -3
    expect_fail "policy/v1beta1 PodDisruptionBudget is deprecated" helm lint --strict "$W"
    sed -i 's#policy/v1beta1#policy/v1#' "$W/templates/pdb.yaml"

    echo "--- fault 5: lint and template pass, kubeconform rejects a string containerPort"
    helm lint --strict "$W" | tail -2
    expect_fail "containerPort" render_kc "$W"
    sed -i 's/containerPort | quote/containerPort/' "$W/templates/deployment.yaml"

    echo "--- all five fixed"
    helm lint --strict "$W" | tail -2
    render_kc "$W"
    echo "    the fixed copy differs from the good chart only by the PodDisruptionBudget:"
    diff -rq "$GOOD" "$W" || true
}

cluster() {
    step "Build the image and install"
    "$REPO_ROOT/scripts/build-images.sh" shipping-service
    helm upgrade --install "$REL" "$GOOD" -n "$NS" --create-namespace --wait --rollback-on-failure --timeout 3m

    step "--dry-run=client renders locally; --dry-run=server also resolves kinds and lookup against the cluster"
    helm upgrade "$REL" "$GOOD" -n "$NS" --dry-run=client --set replicaCount=2 | sed -n '1,6p'
    helm upgrade "$REL" "$GOOD" -n "$NS" --dry-run=server --set replicaCount=2 | sed -n '1,6p'

    step "An unknown kind: helm template renders it, helm upgrade --dry-run=server stops at the cluster"
    cp -r "$GOOD" "$WORK/unknown-kind"
    printf 'apiVersion: example.com/v1\nkind: Widget\nmetadata:\n  name: x\n' > "$WORK/unknown-kind/templates/widget.yaml"
    helm template "$REL" "$WORK/unknown-kind" -n "$NS" >/dev/null && echo "helm template: ok"
    expect_fail "no matches for kind" helm upgrade "$REL" "$WORK/unknown-kind" -n "$NS" --dry-run=server

    step "A string containerPort: both Helm dry-runs pass on Helm 4.3.0, the API server's own dry-run rejects it"
    cp -r "$GOOD" "$WORK/server-fault"
    sed -i 's/containerPort: {{ .Values.containerPort }}/containerPort: {{ .Values.containerPort | quote }}/' "$WORK/server-fault/templates/deployment.yaml"
    helm upgrade "$REL" "$WORK/server-fault" -n "$NS" --dry-run=client >/dev/null && echo "helm --dry-run=client: ok"
    helm upgrade "$REL" "$WORK/server-fault" -n "$NS" --dry-run=server >/dev/null && echo "helm --dry-run=server: ok (no schema validation)"
    helm template "$REL" "$WORK/server-fault" -n "$NS" > "$WORK/fault.yaml"
    expect_fail "expected numeric" kubectl -n "$NS" apply --server-side --dry-run=server -f "$WORK/fault.yaml"

    step "helm diff upgrade against the live release"
    helm diff upgrade "$REL" "$GOOD" -n "$NS" --set replicaCount=2 --set config.logLevel=DEBUG | sed -n '1,40p'

    step "helm get manifest is what the cluster was sent; validate it"
    helm get manifest "$REL" -n "$NS" | kc
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
