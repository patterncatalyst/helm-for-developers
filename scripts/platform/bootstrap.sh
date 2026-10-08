#!/usr/bin/env bash
#
# bootstrap.sh - bring up the helm4dev platform: profile, then operators only.
#
# Tiers (each gated on health before the next):
#   1. minikube profile helm4dev + registry addon
#   2. CloudNativePG operator   (ENABLE_POSTGRES, default true)  -> cnpg-system
#   3. Strimzi operator         (ENABLE_KAFKA,    default true)  -> strimzi, watchAnyNamespace=true
#   4. LGTM observability stack (ENABLE_LGTM,     default true)  -> observability
#
# Operators only. No database or broker instances are created here: the example
# charts own those custom resources, which is what the tutorial teaches.
# Istio, KEDA and Kiali are not part of this project; setting ENABLE_ISTIO,
# ENABLE_KEDA or ENABLE_KIALI to true is an error.
#
# Idempotent: re-running resumes after an interrupted run.
#
#   scripts/platform/bootstrap.sh
#   ENABLE_LGTM=false scripts/platform/bootstrap.sh

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$HERE/lib.sh"

ENABLE_POSTGRES="${ENABLE_POSTGRES:-true}"
ENABLE_KAFKA="${ENABLE_KAFKA:-true}"
ENABLE_LGTM="${ENABLE_LGTM:-true}"
for flag in ENABLE_ISTIO ENABLE_KEDA ENABLE_KIALI; do
    [[ "${!flag:-false}" == "true" ]] && fail "$flag=true is not supported by this project's bootstrap"
done

printf '==> Active configuration\n'
printf '    profile:   %s\n    CNPG:      %s\n    Strimzi:   %s\n    LGTM:      %s\n' \
    "$PROFILE" "$ENABLE_POSTGRES" "$ENABLE_KAFKA" "$ENABLE_LGTM"

step "1/4 Profile and registry"
"$HERE/setup-profile.sh" || fail "profile setup failed"
require_cluster
ok "cluster reachable (context $PROFILE)"

step "2/4 CloudNativePG operator"
if [[ "$ENABLE_POSTGRES" == "true" ]]; then
    "$HERE/setup-postgres-operator.sh" || fail "CloudNativePG operator setup failed"
else
    skip "disabled"
fi

step "3/4 Strimzi operator"
if [[ "$ENABLE_KAFKA" == "true" ]]; then
    "$HERE/setup-kafka-operator.sh" || fail "Strimzi operator setup failed"
else
    skip "disabled"
fi

step "4/4 LGTM observability stack"
if [[ "$ENABLE_LGTM" == "true" ]]; then
    "$HERE/setup-lgtm.sh" || fail "LGTM setup failed"
else
    skip "disabled"
fi

step "Bring-up complete"
cat <<MSG

    Status:          scripts/platform/cluster-status.sh
    Host access:     127.0.0.1:<nodePort> (shipping 30080, notification 30081, Grafana 30300, Argo CD 30443)
    Images:          scripts/build-images.sh
    Tear down:       scripts/platform/teardown.sh

    Operators installed; each example chart creates its own database and broker.
MSG
