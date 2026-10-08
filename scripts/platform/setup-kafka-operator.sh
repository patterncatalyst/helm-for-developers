#!/usr/bin/env bash
#
# setup-kafka-operator.sh - install the Strimzi operator into the "strimzi"
# namespace on the helm4dev cluster, watching every namespace. Operator only:
# the example charts ship the Kafka custom resources.
#
# Version note (2026-10-08): pinned to 1.2.0, the newest chart. It serves only
# kafka.strimzi.io/v1, which is what the example charts use (0.51.0 serves v1 and
# v1beta2 and also works: STRIMZI_VERSION=0.51.0). Verified to install under Helm 4.3.0.
#
# Idempotent: re-running upgrades in place.

set -euo pipefail
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

STRIMZI_VERSION="${STRIMZI_VERSION:-1.2.0}"
require_cluster

step "Installing the Strimzi operator ${STRIMZI_VERSION} into ${STRIMZI_NS} (watchAnyNamespace=true)"
hc upgrade --install strimzi-cluster-operator \
    oci://quay.io/strimzi-helm/strimzi-kafka-operator \
    --version "$STRIMZI_VERSION" \
    --namespace "$STRIMZI_NS" --create-namespace \
    --set watchAnyNamespace=true \
    --wait --timeout 5m

step "Waiting for the operator and its CRDs"
kc wait --for=condition=Established --timeout=120s crd/kafkas.kafka.strimzi.io
kc rollout status deployment/strimzi-cluster-operator -n "$STRIMZI_NS" --timeout=180s

ok "Strimzi operator ready"
kc api-resources --api-group=kafka.strimzi.io -o name 2>/dev/null | head -20
