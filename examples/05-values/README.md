# Values and overrides

Snapshot for chapter 05 ([Values and overrides](../../_docs/05-values-and-overrides.md)). Release `shipping`, namespace `hfd-05`, in-memory storage.

Version 0.5.0 moves config, resources, probes and the container port into `values.yaml`, adds `values.schema.json`, and ships `values-dev.yaml` and `values-prod.yaml` next to the chart.

## Run

```bash
./demo.sh           # offline checks, then a live install on the helm4dev cluster
./demo.sh offline   # no cluster: lint, template, kubeconform, schema rejection and precedence assertions
./demo.sh clean     # remove the release and namespace
```

The live run builds `shipping-service:0.1.0` with `scripts/build-images.sh` and reaches the service through `scripts/tunnel.sh` at http://127.0.0.1:8080. Source `scripts/env.sh` first if you run commands by hand; it selects the project-local Helm 4.3.0.

## Verification status

unverified. A live run must confirm: layered `-f` files apply in order, and `helm get values --all` shows the merged result.
