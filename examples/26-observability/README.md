# 26 Observability with the LGTM stack

The final umbrella chart (release `platform`, namespace `hfd-26`) with telemetry on in `values-dev.yaml` and a Grafana dashboard ConfigMap added to the umbrella: `templates/dashboard.yaml`, `files/shipping-dashboard.json`, a `dashboards:` values block and `tests/dashboard_test.yaml`. Everything else matches the reference `charts/` directory.

## Run

```
[host]$ ./demo.sh offline
[host]$ ./demo.sh
[host]$ ./demo.sh clean
```

The full run needs the LGTM stack from `scripts/platform/setup-lgtm.sh`. It upgrades the Grafana release with `sidecar.dashboards.searchNamespace=ALL`, installs the umbrella, dispatches a shipment and queries Tempo and the Grafana dashboard search on the published NodePort. Grafana login is `admin` / `admin`.

## Verification status

`verified` on 2026-10-08 (`_plans/evidence/26-observability.txt`): the demo ran end to end, the dashboard loaded after the sidecar upgrade, and one trace holds spans from both services. The dashboard metric exists in Mimir but is labelled `job`, not `service_name`; the dashboard was corrected. Re-run on r1.1 with published NodePorts (bound to 127.0.0.1) on 2026-10-08: `./demo.sh` exited 0; the trace held spans from both services, the TraceQL and Mimir polls succeeded (series found after 0 s), and the dashboard loaded. The release `platform` stays installed in `hfd-26` as the reference state, so `clean` was not run.
