#!/usr/bin/env bash
#
# setup-lgtm.sh - install the LGTM observability stack into the "observability"
# namespace of the helm4dev cluster.
#
#   Loki   - single-binary mode, filesystem storage
#   Tempo  - monolithic mode, filesystem storage
#   Mimir  - mimir-distributed trimmed to one replica per component, no zone
#            awareness, multitenancy off (so the Collector and Grafana need no tenant header).
#            Blocks go to the chart's bundled MinIO: filesystem storage cannot be shared
#            between the ingester, store-gateway and compactor pods (found on the first
#            live run, where the compactor crashed on overlapping /data paths).
#            The chart 5.4.0 MinIO image (quay.io/minio/minio:RELEASE.2023-09-30...) is no
#            longer pullable (401), so the pgsty/silo MinIO fork that chart 6.2.1 uses
#            replaces it, for both the server and the mc client.
#   OpenTelemetry Collector - one pod; OTLP in, routes to Loki/Tempo/Mimir
#   Grafana - datasources and dashboards provisioned from platform/observability/,
#             exposed on NodePort 30300
#
# Apps emit OTLP to otel-collector.observability.svc.cluster.local (4318 HTTP, 4317 gRPC).
#
# Chart versions (pinned 2026-10-08). The defaults are the versions the
# lgtm-minikube-stack skill proved on a live cluster; all of them also render
# under Helm 4.3.0. Newer releases exist (loki 7.3.0, tempo 1.24.4,
# mimir-distributed 6.2.1, grafana 10.5.15, opentelemetry-collector 0.175.1) but
# change values layout, so bump deliberately and re-check this script.
# Override with LOKI_VERSION, TEMPO_VERSION, MIMIR_VERSION, GRAFANA_VERSION,
# OTEL_COLLECTOR_VERSION.
#
# Idempotent: helm upgrade --install and kubectl apply throughout.

set -euo pipefail
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

LOKI_VERSION="${LOKI_VERSION:-6.16.0}"
TEMPO_VERSION="${TEMPO_VERSION:-1.10.0}"
MIMIR_VERSION="${MIMIR_VERSION:-5.4.0}"
GRAFANA_VERSION="${GRAFANA_VERSION:-8.5.0}"
OTEL_COLLECTOR_VERSION="${OTEL_COLLECTOR_VERSION:-0.97.0}"
OBS_CONFIG_DIR="$HFD_ROOT/platform/observability"

require_cluster

step "Ensuring helm repos are registered"
add_repo grafana https://grafana.github.io/helm-charts
add_repo open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts

step "Namespace ${OBS_NS}"
kc create namespace "$OBS_NS" --dry-run=client -o yaml | kc apply -f - >/dev/null

step "Applying Grafana datasource and dashboard ConfigMaps"
kc apply -n "$OBS_NS" -f "$OBS_CONFIG_DIR/grafana-datasources.yaml"
for f in "$OBS_CONFIG_DIR"/dashboards/*.yaml; do
    [[ -f "$f" ]] && kc apply -n "$OBS_NS" -f "$f"
done

step "Loki ${LOKI_VERSION} (single-binary)"
hc upgrade --install loki grafana/loki \
    --version "$LOKI_VERSION" --namespace "$OBS_NS" --wait --timeout 8m \
    --set deploymentMode=SingleBinary \
    --set 'loki.commonConfig.replication_factor=1' \
    --set 'loki.storage.type=filesystem' \
    --set 'loki.auth_enabled=false' \
    --set 'loki.schemaConfig.configs[0].from=2024-01-01' \
    --set 'loki.schemaConfig.configs[0].store=tsdb' \
    --set 'loki.schemaConfig.configs[0].object_store=filesystem' \
    --set 'loki.schemaConfig.configs[0].schema=v13' \
    --set 'loki.schemaConfig.configs[0].index.prefix=loki_index_' \
    --set 'loki.schemaConfig.configs[0].index.period=24h' \
    --set 'singleBinary.replicas=1' \
    --set 'singleBinary.persistence.enabled=true' \
    --set 'singleBinary.persistence.size=5Gi' \
    --set 'chunksCache.enabled=false' \
    --set 'resultsCache.enabled=false' \
    --set 'minio.enabled=false' \
    --set 'read.replicas=0' \
    --set 'write.replicas=0' \
    --set 'backend.replicas=0' \
    --set 'gateway.enabled=true' \
    --set 'gateway.replicas=1' \
    --set 'lokiCanary.enabled=false' \
    --set 'test.enabled=false'

step "Tempo ${TEMPO_VERSION} (monolithic)"
hc upgrade --install tempo grafana/tempo \
    --version "$TEMPO_VERSION" --namespace "$OBS_NS" --wait --timeout 5m \
    --set 'tempo.storage.trace.backend=local' \
    --set 'tempo.storage.trace.local.path=/var/tempo/traces' \
    --set 'persistence.enabled=true' \
    --set 'persistence.size=5Gi' \
    --set 'tempo.receivers.otlp.protocols.grpc.endpoint=0.0.0.0:4317' \
    --set 'tempo.receivers.otlp.protocols.http.endpoint=0.0.0.0:4318'

step "Mimir ${MIMIR_VERSION} (mimir-distributed, trimmed for one node)"
hc upgrade --install mimir grafana/mimir-distributed \
    --version "$MIMIR_VERSION" --namespace "$OBS_NS" --wait --timeout 10m \
    --set 'metaMonitoring.serviceMonitor.enabled=false' \
    --set 'minio.enabled=true' \
    --set 'minio.image.repository=pgsty/silo' \
    --set 'minio.image.tag=RELEASE.2026-09-03T13-18-01Z' \
    --set 'minio.mcImage.repository=pgsty/silo' \
    --set 'minio.mcImage.tag=RELEASE.2026-09-03T13-18-01Z' \
    --set 'rollout_operator.enabled=false' \
    --set 'alertmanager.enabled=false' \
    --set 'ruler.enabled=false' \
    --set 'overrides_exporter.enabled=false' \
    --set 'ingester.zoneAwareReplication.enabled=false' \
    --set 'store_gateway.zoneAwareReplication.enabled=false' \
    --set 'ingester.replicas=1' \
    --set 'store_gateway.replicas=1' \
    --set 'querier.replicas=1' \
    --set 'query_scheduler.replicas=1' \
    --set 'mimir.structuredConfig.multitenancy_enabled=false' \
    --set 'mimir.structuredConfig.ingester.ring.replication_factor=1'

step "OpenTelemetry Collector ${OTEL_COLLECTOR_VERSION}"
kc apply -n "$OBS_NS" -f "$OBS_CONFIG_DIR/otel-collector-config.yaml"
hc upgrade --install otel-collector open-telemetry/opentelemetry-collector \
    --version "$OTEL_COLLECTOR_VERSION" --namespace "$OBS_NS" --wait --timeout 5m \
    --set 'mode=deployment' \
    --set 'fullnameOverride=otel-collector' \
    --set 'replicaCount=1' \
    --set 'image.repository=otel/opentelemetry-collector-contrib' \
    --set 'configMap.create=false' \
    --set 'configMap.existingName=otel-collector-config' \
    --set 'ports.otlp.enabled=true' \
    --set 'ports.otlp-http.enabled=true' \
    --set 'service.enabled=true'

step "Grafana ${GRAFANA_VERSION} (NodePort 30300)"
hc upgrade --install grafana grafana/grafana \
    --version "$GRAFANA_VERSION" --namespace "$OBS_NS" --wait --timeout 5m \
    --set 'persistence.enabled=true' \
    --set 'persistence.size=2Gi' \
    --set 'adminUser=admin' \
    --set 'adminPassword=admin' \
    --set 'service.type=NodePort' \
    --set 'service.nodePort=30300' \
    --set 'sidecar.datasources.enabled=true' \
    --set 'sidecar.datasources.label=grafana_datasource' \
    --set 'sidecar.datasources.labelValue=1' \
    --set 'sidecar.dashboards.enabled=true' \
    --set 'sidecar.dashboards.label=grafana_dashboard' \
    --set 'sidecar.dashboards.labelValue=1' \
    --set 'sidecar.dashboards.folderAnnotation=grafana_folder' \
    --set 'sidecar.dashboards.provider.foldersFromFilesStructure=true'

printf '\nLGTM stack installed in namespace %s.\n' "$OBS_NS"
printf '  Grafana http://127.0.0.1:30300  (admin/admin)\n'
printf '  OTLP HTTP in-cluster: http://otel-collector.%s.svc.cluster.local:4318\n' "$OBS_NS"
printf '  OTLP gRPC in-cluster: otel-collector.%s.svc.cluster.local:4317\n' "$OBS_NS"
