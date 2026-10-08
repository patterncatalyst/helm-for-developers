# First chart

Snapshot for chapter 04 ([Your first chart](../../_docs/04-first-chart.md)). Release `shipping`, namespace `hfd-04`, in-memory storage.

`shipping-service/` is a hand-built chart (version 0.4.0): `Chart.yaml`, `values.yaml`, `.helmignore` and three templates that are the chapter 03 manifests with names, image and replica count templated. `demo.sh offline` also lists the files `helm create` generates, for comparison.

## Run

```bash
./demo.sh           # offline checks, then a live install on the helm4dev cluster
./demo.sh offline   # no cluster: lint, template, kubeconform, and the `helm create` file list
./demo.sh clean     # remove the release and namespace
```

The live run builds `shipping-service:0.1.0` with `scripts/build-images.sh` and reaches the service on the published NodePort at http://127.0.0.1:30080. Source `scripts/env.sh` first if you run commands by hand; it selects the project-local Helm 4.3.0.

## Verification status

`verified` on 2026-10-08 (`_plans/evidence/04-first-chart.txt`): `helm history` showed revisions 1, 2 and 3 (3 = `Rollback to 1`), one `sh.helm.release.v1.shipping.vN` Secret per revision, `--keep-history` left an `uninstalled` release, the Deployment fields were owned by manager `helm` (apply), and the history cap held at 10. Re-run on r1.1 with published NodePorts on 2026-10-08 (helm4dev recreated with `HFD_NODE_PORTS`, host requests at `http://127.0.0.1:30080`, no tunnel); the behaviour above held.