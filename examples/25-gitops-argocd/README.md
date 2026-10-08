# 25 GitOps with Argo CD

Argo CD 3.5.4, installed from Helm chart `argo/argo-cd` 10.10.1, syncs the umbrella chart from the in-cluster registry addon.

| Path | Purpose |
|---|---|
| `argocd-values.yaml` | Lab install: no Dex, no notifications, NodePort 30443 |
| `apps/repo-registry.yaml` | Registers the registry addon as an OCI Helm repository |
| `apps/shipping-platform-oci.yaml` | Primary `Application`: chart 1.0.0 from OCI, `valueFiles` plus `valuesObject` |
| `apps/shipping-service-git.yaml` | Git-sourced `Application`: `shipping-service` at tag `r1.0` of `patterncatalyst/helm-for-developers`, NodePort 30090. The umbrella does not render from a clean Git checkout (see chapter 25) |
| `apps/shipping-platform-helmrepo.yaml` | Helm repository `Application`: umbrella 1.0.0 from the published GitHub Pages repository, namespace `hfd-25-repo`, NodePorts 30190 and 30191, no repository Secret. Works where the umbrella from Git does not, because the package carries its subcharts |
| `charts/` | Self-contained copy of the reference charts |

## Run

```
[host]$ ./demo.sh offline
[host]$ ./demo.sh
[host]$ ./demo.sh git
[host]$ ./demo.sh helmrepo
[host]$ ./demo.sh clean
```

The full run installs Argo CD, pushes `shipping-platform-1.0.0.tgz` to `oci://127.0.0.1:5000/charts` through `scripts/tunnel.sh registry`, and applies the `Application`. It then applies the Git-sourced `Application`, patches its `valuesObject`, and scales the Deployment by hand to show `selfHeal`; `./demo.sh git` repeats only that part. The Helm repository `Application` then syncs the umbrella from the Pages repository, dispatches a shipment to check the Kafka notification, patches `valuesObject` and scales by hand; `./demo.sh helmrepo` repeats it. The UI is at https://127.0.0.1:8443 after `scripts/tunnel.sh argocd` (self-signed certificate; user `admin`, password printed by the demo). The workload uses NodePorts 30080 and 30081, so uninstall other releases that claim them first (the chapter 26 `platform` release included).

## Verification status

`verified` on 2026-10-08 (`_plans/evidence/25-gitops-argocd.txt`, `_plans/evidence/25-gitops-argocd-git.txt`): the demo ran end to end, the OCI Application reached Synced and Healthy, and the Git-sourced Application (tag `r1.0`, `shipping-service` chart) reached Synced and Healthy, took a `valuesObject` change and reverted manual drift. The umbrella chart from Git failed because the gitignored dependency tarballs are absent from a clean checkout. The umbrella from the published Helm repository (`_plans/evidence/25-gitops-argocd-helmrepo.txt`) reached Synced and Healthy, ran the PostSync migration, delivered a Kafka notification, took a `valuesObject` change and reverted drift.
