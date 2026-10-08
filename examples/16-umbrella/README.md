# 16 Umbrella charts

Snapshot for chapter 16 (`_docs/16-umbrella-charts.md`). `charts/shipping-platform` is the umbrella; release `platform`, namespace `hfd-16`. Subcharts (aliases): `shipping-service` (`shipping`), `notification-service` (`notification`), `shipping-postgres` (`db`), `shipping-kafka` (`kafka`). All charts are version `0.16.0`; the services still carry their own helpers.

What to look at:

- `charts/shipping-platform/Chart.yaml`: aliases, `condition`, `tags`, `import-values`.
- `charts/shipping-platform/values.yaml`: `global`, `tags.messaging`, the post-install migration hook, the `/health` readiness override.
- `charts/shipping-platform/values-dev.yaml`: NodePorts, dev token, OTLP endpoint.

## Run

    [host]$ ./demo.sh offline   # dependency build, lint, unittest, kubeconform, the import-values trap, the tags trap
    [host]$ ./demo.sh           # offline checks, install release platform, dispatch a shipment, helm test
    [host]$ ./demo.sh clean

The full run needs the Strimzi and CloudNativePG operators. The offline run copies the charts to a temporary directory for the import-values trap and leaves this tree unchanged. `helm dependency build` writes `charts/*.tgz` (git-ignored) and `Chart.lock`.

## Verification status

unverified. A live run must confirm: the release installs with `post-install` hooks and `shipping.probes.readiness.path=/health`; with `/healthz` readiness the release waits until the timeout; `tags.messaging=false` plus `shipping.kafka.enabled=false` installs without Kafka.
