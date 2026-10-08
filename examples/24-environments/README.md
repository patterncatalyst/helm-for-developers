# 24 Environment promotion

The umbrella chart from chapter 16 deployed to three environments with Helmfile 1.8.1 on Helm 4.3.0. Each environment layers `charts/shipping-platform/values-<env>.yaml` and `pins/<env>.yaml`, and installs into its own namespace (`hfd-24-dev`, `hfd-24-stage`, `hfd-24-prod`) as release `platform`.

| Path | Purpose |
|---|---|
| `helmfile.yaml` | Three releases; the `version:` line is the chart pin |
| `pins/<env>.yaml` | Image tag, or tag@digest after `./demo.sh pin <env>` |
| `charts/` | Self-contained copy of the golden charts at 1.0.0 |

## Run

```
[host]$ ./demo.sh offline
[host]$ ./demo.sh pin stage
[host]$ ./demo.sh
[host]$ ./demo.sh clean
```

`offline` lints and renders all three environments and checks the layering. The full run installs dev only; stage and prod need more memory than the lab cluster has. Dev claims NodePorts 30080 and 30081, so uninstall any other release that uses them first.

## Verification status

`verified` on 2026-10-08 (`_plans/evidence/24-environments.txt`): dev installed and passed `helm test`, and a pinned digest was pulled and ran. Stage and prod are offline only. `./demo.sh pin` pushes with Podman when it is installed (push mode prefers it, since a Docker daemon in a VM such as Docker Desktop cannot reach the registry tunnel); `BUILD_ENGINE` overrides.
