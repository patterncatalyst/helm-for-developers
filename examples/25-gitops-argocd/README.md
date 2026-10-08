# 25 GitOps with Argo CD

Argo CD 3.5.4, installed from Helm chart `argo/argo-cd` 10.10.1, syncs the umbrella chart from the in-cluster registry addon.

| Path | Purpose |
|---|---|
| `argocd-values.yaml` | Lab install: no Dex, no notifications, NodePort 30443 |
| `apps/repo-registry.yaml` | Registers the registry addon as an OCI Helm repository |
| `apps/shipping-platform-oci.yaml` | Primary `Application`: chart 1.0.0 from OCI, `valueFiles` plus `valuesObject` |
| `apps/shipping-platform-git.yaml` | Same chart from Git. Pending until `patterncatalyst/helm-for-developers` is pushed; not applied by the demo |
| `charts/` | Self-contained copy of the golden charts |

## Run

```
[host]$ ./demo.sh offline
[host]$ ./demo.sh
[host]$ ./demo.sh clean
```

The full run installs Argo CD, pushes `shipping-platform-1.0.0.tgz` to `oci://127.0.0.1:5000/charts` through `scripts/tunnel.sh registry`, and applies the `Application`. The UI is at https://127.0.0.1:8443 after `scripts/tunnel.sh argocd` (self-signed certificate; user `admin`, password printed by the demo). The workload uses NodePorts 30080 and 30081, so uninstall other releases that claim them first.

## Verification status

`unverified`. A live run must confirm that the OCI repository secret works over plain HTTP, that the `Application` reaches Synced and Healthy, and that the migration hook runs as a PostSync hook.
