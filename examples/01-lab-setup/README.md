# 01 - Lab setup

Chapter: [Prerequisites and lab setup](../../_docs/01-prerequisites.md).

This example drives the repository's shared lab scripts. It has no chart; the lab itself is the artifact.

| Command | What it does |
|---|---|
| `./demo.sh` | Installs the project-local toolchain, creates the `helm4dev` minikube profile, installs operators only, builds both service images, prints a status report. |
| `./demo.sh offline` | Preflight only. Checks pinned tool versions, plugin versions, that `helm` resolves to `.tools/bin`, and runs `bash -n` on every script under `scripts/`. Needs no cluster. |
| `./demo.sh clean` | Stops the host tunnels started by `scripts/tunnel.sh`. |

The full run is idempotent. To delete the cluster entirely: `scripts/platform/teardown.sh`, which only ever deletes the `helm4dev` profile.

## What to look for

- `helm version --short` prints `v4.3.0+g...` and `command -v helm` prints `.tools/bin/helm` under the repository.
- `scripts/platform/cluster-status.sh` ends with `ok: platform healthy`.
- `kubectl --context helm4dev get pods -A` shows operators in `cnpg-system` and `strimzi`, and observability pods in `observability`. No application pods exist yet.

Python 3.14 note: the service images currently build on CPython 3.14.8 (fallback F1 in `CONTRIBUTING.md`). Nothing in this chapter depends on the Python version.

## Verification status

`unverified`. A live run must confirm the full run exits 0 from a deleted profile, that `cluster-status.sh` reports healthy, and that the global Helm 3 still reports its original version.
