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
| 5 | `templates/deployment.yaml` | `containerPort` rendered as a string | kubeconform only (the cluster rungs show the API server rejecting it too) |

To debug by hand, copy `broken/shipping-service` somewhere and fix one fault at a time with the ladder in the chapter.

## Verification status

`unverified`. The offline ladder exits 0 on the authoring machine. A live run must confirm:

- `helm upgrade --dry-run=client` accepts a string `containerPort` and `--dry-run=server` rejects it.
- `helm diff upgrade` shows the `replicaCount` and `LOG_LEVEL` changes against the live release.
- `helm get manifest shipping -n hfd-13` passes kubeconform.
