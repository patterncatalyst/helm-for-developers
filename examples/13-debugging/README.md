# 13 Debugging charts

Chapter: [`_docs/13-debugging-charts.md`](../../_docs/13-debugging-charts.md).

A ladder of checks (`helm lint --strict`, `helm template --debug --show-only`, kubeconform with the datree CRDs-catalog, `helm diff`, `--dry-run=server`, `helm get manifest`) applied to a working chart and to a copy with five planted faults.

## Contents

| Path | What it is |
|---|---|
| `charts/shipping-service` | The shipping-service chart at version 0.13.0: ConfigMap, Secret, Deployment, Service, migration hook, schema. No unit tests yet. |
| `charts/shipping-postgres` | One CloudNativePG `Cluster`, used to show kubeconform validating a custom resource. |
| `broken/shipping-service` | A copy of the chart with five faults, one per file. |
| `demo.sh` | `offline`, no argument (offline then cluster), or `clean`. |

## Usage

```bash
./demo.sh offline    # no cluster; fetches kubeconform schemas on the first run
./demo.sh            # offline, then install in namespace hfd-13 and run the cluster rungs
./demo.sh clean      # uninstall and delete hfd-13
```

Environment: `SCHEMA_CACHE` sets the kubeconform schema cache directory (default `$TMPDIR/hfd-kubeconform-cache`).

## The five faults

The demo copies `broken/shipping-service` to a temporary directory, asserts each failure, applies a one-line fix and moves to the next.

| # | File | Fault | First caught by |
|---|---|---|---|
| 1 | `values.yaml` | `replicaCount: "1"` | `helm lint --strict`, `helm template` |
| 2 | `templates/configmap.yaml` | `.Values.logging.level` does not exist | `helm template` |
| 3 | `templates/service.yaml` | `indent 4` instead of `nindent 4` | `helm template`, `helm lint` |
| 4 | `templates/pdb.yaml` | `policy/v1beta1` | `helm lint --strict` only |
| 5 | `templates/deployment.yaml` | `containerPort` rendered as a string | kubeconform only (the cluster rung shows `kubectl apply --server-side --dry-run=server` rejecting it; Helm 4.3.0's own `--dry-run=server` does not) |

To debug by hand, copy `broken/shipping-service` somewhere and fix one fault at a time with the ladder in the chapter.

## Verification status

`verified` on 2026-10-08 (Helm 4.3.0, minikube `helm4dev`), evidence `_plans/evidence/13-debugging.txt`. The full demo exits 0. Observed: `helm diff upgrade` shows the `replicaCount` and `LOG_LEVEL` changes, `helm get manifest` passes kubeconform, an unknown kind fails `--dry-run=server`, and a string `containerPort` passes `--dry-run=client` and `--dry-run=server` but fails `kubectl apply --server-side --dry-run=server`. Re-run on r1.1 on 2026-10-08 on the recreated helm4dev profile; this chapter makes no host requests, so only the cluster changed, and the behaviour above held.
