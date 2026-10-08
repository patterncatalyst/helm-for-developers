# 26 Observability with the LGTM stack

The final umbrella chart (release `platform`, namespace `hfd-26`) with telemetry on in `values-dev.yaml` and a Grafana dashboard ConfigMap added to the umbrella: `templates/dashboard.yaml`, `files/shipping-dashboard.json`, a `dashboards:` values block and `tests/dashboard_test.yaml`. Everything else matches the golden `charts/` directory.

## Run

```
[host]$ ./demo.sh offline
[host]$ ./demo.sh
[host]$ ./demo.sh clean
```

The full run needs the LGTM stack from `scripts/platform/setup-lgtm.sh`. It upgrades the Grafana release with `sidecar.dashboards.searchNamespace=ALL`, installs the umbrella, dispatches a shipment and queries Tempo and the Grafana dashboard search through `scripts/tunnel.sh`. Grafana login is `admin` / `admin`.

## Verification status

`unverified`. A live run must confirm that the dashboard appears in Grafana, that the dispatch trace holds spans from both services, and that the dashboard's metric name (`http_server_duration_milliseconds_count`) exists in Mimir.
