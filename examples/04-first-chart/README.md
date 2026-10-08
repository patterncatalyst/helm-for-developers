# First chart

Snapshot for chapter 04 ([Your first chart](../../_docs/04-first-chart.md)). Release `shipping`, namespace `hfd-04`, in-memory storage.

`shipping-service/` is a hand-built chart (version 0.4.0): `Chart.yaml`, `values.yaml`, `.helmignore` and three templates that are the chapter 03 manifests with names, image and replica count templated. `demo.sh offline` also lists the files `helm create` generates, for comparison.

## Run

```bash
./demo.sh           # offline checks, then a live install on the helm4dev cluster
./demo.sh offline   # no cluster: lint, template, kubeconform, and the `helm create` file list
./demo.sh clean     # remove the release and namespace
```

The live run builds `shipping-service:0.1.0` with `scripts/build-images.sh` and reaches the service through `scripts/tunnel.sh` at http://127.0.0.1:8080. Source `scripts/env.sh` first if you run commands by hand; it selects the project-local Helm 4.3.0.

## Verification status

unverified. A live run must confirm: install, upgrade to 2 replicas, rollback to revision 1, and one `sh.helm.release.v1.shipping.vN` Secret per revision.
