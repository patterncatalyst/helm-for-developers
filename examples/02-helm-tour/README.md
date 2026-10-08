# 02 - Helm tour

Chapter: [A tour of Helm 4](../../_docs/02-helm-4-tour.md).

Installs the public `podinfo` chart from `oci://ghcr.io/stefanprodan/charts/podinfo`, pinned to version `6.15.0`, into namespace `hfd-02` as release `podinfo`. The release is named for the chart because it is not part of the shipping application. Charts for the shipping service start in chapter 04 and use release name `shipping`.

| Command | What it does |
|---|---|
| `./demo.sh` | `helm install` with `--wait --rollback-on-failure`, then `helm list`, `helm status`, `helm get values`, a health probe from inside a pod, and `helm uninstall`. |
| `./demo.sh offline` | `helm show chart` and `helm template` against the OCI chart, then kubeconform on the output. Needs network access to ghcr.io, no cluster. |
| `./demo.sh clean` | Uninstalls the release and deletes `hfd-02`. |

`values-tour.yaml` overrides two values: `replicaCount: 2` and `ui.message`.

## What to look for

- The `helm list` output shows `podinfo` with status `deployed` and chart `podinfo-6.15.0`.
- `kubectl get secret -l owner=helm` shows one Secret named `sh.helm.release.v1.podinfo.v1`.
- The output of `helm get values podinfo` is only the two overridden values.
- After uninstall, the `helm list` table is empty and the Secret is gone.

## Verification status

`verified` on 2026-10-08 (`_plans/evidence/02-helm-tour.txt`): install reached `deployed` with two ready pods, `podcli check http` succeeded in-pod, uninstall removed the release Secret.
