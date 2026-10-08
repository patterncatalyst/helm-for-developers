#!/usr/bin/env bash
#
# setup-postgres-operator.sh - install the CloudNativePG operator into
# cnpg-system on the helm4dev cluster. Operator only: the example charts ship
# the Postgres custom resources.
#
# An operator install is cluster-wide: it registers CRDs and runs a controller
# that watches every namespace. Idempotent: re-running upgrades in place.
#
# Version note (2026-10-08): the lgtm-minikube-stack skill pins 0.23.0; the
# current chart is 0.29.1 (app 1.30.1, kubeVersion >=1.29). `helm template`
# succeeds under Helm 4.3.0. Override with CNPG_CHART_VERSION.

set -euo pipefail
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

CHART_VERSION="${CNPG_CHART_VERSION:-0.29.1}"
require_cluster

step "Adding the CloudNativePG helm repository"
add_repo cnpg https://cloudnative-pg.github.io/charts

step "Installing CloudNativePG ${CHART_VERSION} into ${CNPG_NS}"
hc upgrade --install cnpg cnpg/cloudnative-pg \
    --namespace "$CNPG_NS" --create-namespace \
    --version "$CHART_VERSION" \
    --wait --timeout 5m

step "Waiting for the operator and its CRDs"
kc wait --for=condition=Established --timeout=120s crd/clusters.postgresql.cnpg.io
kc wait --for=condition=Available --timeout=180s deployment \
    -l app.kubernetes.io/name=cloudnative-pg -n "$CNPG_NS"

ok "CloudNativePG operator ready (CRDs: $(kc get crd -o name | grep -c cnpg.io) cnpg.io)"
