---
title: "Prerequisites and lab setup"
order: 1
part: "Getting started"
description: "Install Helm 4.3.0 and the supporting tools into the repository, isolate every Helm state directory, and bring up a minikube profile with operators only."
duration: 40 minutes
---

Every chapter after this one runs Helm against a real cluster, so this chapter builds the lab once and makes it disposable. The new idea is isolation: Helm 4 lives inside the repository, its config, cache and plugins live beside it, and the cluster is a single minikube profile named `helm4dev` that holds operators and nothing else.

The code is in `examples/01-lab-setup/`. `./demo.sh offline` checks the toolchain without touching a cluster; `./demo.sh` builds the whole lab.

{% include excalidraw.html
   file="01-lab-topology"
   alt="Diagram of the lab: a host checkout with scripts/env.sh, project-local tools and Helm state under .tools, a separate untouched Helm 3, and tunnels; and the helm4dev minikube profile with the API server, registry addon, release records, operator namespaces and one hfd namespace per example"
   caption="Figure 1.1 — The lab: project-local tools on the host, one minikube profile, one namespace per example" %}

## What you need on the host

The lab was run with `minikube` 1.38.1. It also needs `kubectl`, a container engine (Docker or Podman), `curl`, `tar`, `sha256sum` and `python3`. The minikube profile uses the docker driver with the containerd runtime, 12g of RAM and 8 CPUs. Everything else, including Helm, comes from `scripts/install-tools.sh`.

The service images are built on CPython 3.14.8, not 3.15. `uv` had no 3.15.0 build and `aiokafka` had no cp315 wheel when the images were first built, so `CONTRIBUTING.md` records fallback F1. Nothing in the Helm chapters depends on the interpreter version; the change is one `ARG PYTHON_VERSION` line in `services/Containerfile`.

## Why Helm lives in the repository

A global Helm 3 may already be on your `PATH`. By default both major versions read the same `~/.config/helm` repository list and `~/.cache/helm` cache on Linux, so a second Helm major version sharing them is an avoidable risk. The lab avoids the clash by never touching the global install. The Helm 4 binary goes into `.tools/bin`, and four environment variables redirect all of Helm's state under `.tools/helm/`:

| Variable | Value | Holds |
|---|---|---|
| `HELM_CONFIG_HOME` | `.tools/helm/config` | `repositories.yaml`, registry credentials |
| `HELM_CACHE_HOME` | `.tools/helm/cache` | repository indexes, the content cache of pulled charts |
| `HELM_DATA_HOME` | `.tools/helm/data` | local plugin data |
| `HELM_PLUGINS` | `.tools/helm/plugins` | installed plugins (unittest, diff) |

Deleting `.tools/` resets every part of the toolchain, and your other projects never see any of it. `helm --help` documents the `HELM_*_HOME` variables; the [Helm 4 overview](https://helm.sh/docs/overview/) lists the new content-based cache that `HELM_CACHE_HOME` now also holds.

## How the code works

### `scripts/env.sh`

Every script and every demo starts with `source scripts/env.sh`. It does four jobs in order.

First it finds the repository root from its own path (using `BASH_SOURCE` or the zsh equivalent) and exports `HFD_ROOT`. Nothing in the lab hard-codes `~/Dev`.

Second it prepends `$HFD_ROOT/.tools/bin` to `PATH`, so `helm` resolves to the project copy. It then exports the four Helm variables above, plus `GNUPGHOME=$HFD_ROOT/.tools/gnupg` (used for throwaway signing keys in chapter 21) and `MINIKUBE_PROFILE=helm4dev`.

Third it creates those directories, and links `$HELM_DATA_HOME/plugins` to `$HELM_PLUGINS`. The link exists because Helm 4 installs a plugin from a local directory under the data home, while the `HELM_PLUGINS` variable points at where it searches. One physical directory serves both.

Fourth it enforces the version. Unless `HFD_SKIP_HELM_CHECK=1`, it runs `helm version --short` and fails if the answer does not start with `v4.`. A reader whose shell still resolves to Helm 3 gets a message naming the binary that was found, instead of a chapter that fails ten steps later with a confusing flag error. `install-tools.sh` sets the skip variable for the one run that creates Helm, since no Helm 4 exists yet.

### `scripts/install-tools.sh`

The versions are variables at the top, pinned on 2026-10-08: Helm 4.3.0, kubeconform 0.8.0, chart-testing 3.15.0, cosign 3.1.3, helmfile 1.8.1, helm-unittest 1.2.1 and helm-diff 3.15.15. Each can be overridden by environment variable.

Each download follows the same shape: `fetch` the release asset, `fetch` its checksum file, `verify_sum` compares SHA-256 and aborts on a mismatch, then `install` copies the binary into `.tools/bin`. A `have_version` check makes the script idempotent; `--force` reinstalls. Helm comes from `https://get.helm.sh/helm-v4.3.0-linux-amd64.tar.gz` together with its `.sha256sum` file. `yamllint` and `yamale`, which chart-testing calls, go in a Python virtual environment at `.tools/venv` and are linked into `.tools/bin`.

The plugins come last, because `helm plugin install` needs the new Helm. `helm plugin install` defaults to `--verify=true`, which checks a signature against `$GNUPGHOME/pubring.kbx`. The pinned upstream releases are installed without that signature check, so the script passes `--verify=false` when `helm plugin install --help` lists the flag, and `helm plugin list` shows their provenance as `unknown`. Chapter 22 returns to plugin provenance.

### `scripts/platform/bootstrap.sh`

The bootstrap runs four tiers and gates each on the health of the one before:

1. `setup-profile.sh` creates or starts the `helm4dev` minikube profile and enables the registry addon. It refuses to act on any other profile name, checks `fs.inotify.max_user_instances`, and warns when other minikube profiles are running and competing for RAM.
2. `setup-postgres-operator.sh` runs `helm upgrade --install cnpg cnpg/cloudnative-pg` into `cnpg-system`.
3. `setup-kafka-operator.sh` installs Strimzi into `strimzi` with `watchAnyNamespace=true`, so one operator serves every `hfd-NN` namespace.
4. `setup-lgtm.sh` installs Loki, Grafana, Tempo and Mimir into `observability`. Its Grafana only loads dashboard ConfigMaps from its own namespace; chapter 26 upgrades the shared Grafana with `sidecar.dashboards.searchNamespace=ALL` so the umbrella's dashboard in `hfd-26` appears.

Operators only is a deliberate decision. The bootstrap installs the machinery that understands a `Cluster` or a `Kafka` custom resource. It never creates a database or a broker, because from chapter 09 onward the charts you write own those resources, and that is what a chart is for. Every helper in `lib.sh` pins `--context helm4dev` explicitly, so the kubectl context you happen to have active never decides where a command lands.

### `scripts/build-images.sh`

The script builds `shipping-service:0.1.0` and `notification-service:0.1.0` from one `services/Containerfile`, selecting the service with `--build-arg SERVICE=<name>`. With Docker or Podman it builds on the host and runs `minikube -p helm4dev image load`; with `BUILD_ENGINE=minikube` it builds inside the node. The charts default to `image.repository: shipping-service` and a tag taken from `.Chart.AppVersion`, so the same image serves every chapter and only charts and values change. `build-images.sh push` additionally pushes to the registry addon at `localhost:5000` through an SSH tunnel. Push mode prefers Podman when it is installed, because a Docker daemon that runs in a VM (Docker Desktop) cannot reach a tunnel bound on the host's `127.0.0.1`; set `BUILD_ENGINE=docker` to force Docker, for example with Docker Engine on Linux.

### `scripts/tunnel.sh`

Host access uses NodePort Services plus SSH tunnels instead of `kubectl port-forward`. A NodePort survives pod restarts, and `tunnel.sh` keeps its tunnels alive with `ServerAliveInterval` and fails loudly when a local port is busy. The fixed map is shipping 8080 to 30080, notification 8081 to 30081, Grafana 3000 to 30300 and Argo CD 8443 to 30443. Chapter 02 needs none of them.

## Build, run, observe

Run the preflight first. It needs no cluster.

```
[host]$ cd examples/01-lab-setup && ./demo.sh offline
```

It checks that `helm` resolves to `.tools/bin/helm`, that the pinned versions are present, that the two plugins are installed, and that every script under `scripts/` passes `bash -n`. A real run printed these lines:

```
==> Project-local Helm 4
    ok: helm v4.3.0+gbec5b06
    ok: helm resolves to .tools/bin
    ok: HELM_CACHE_HOME is project-local
==> Global Helm is left alone
    ok: global helm still reports: v3.18.3+g6838ebc
```

Then build the lab, which takes several minutes the first time.

```
[host]$ ./demo.sh
```

When it finishes, confirm the cluster independently of the script.

```
[host]$ source ../../scripts/env.sh && helm plugin list
```

The listing shows `diff 3.15.15` and `unittest 1.2.1`, both of type `cli/v1`.

## Cross-check

Compare Helm's own view of its directories with `env.sh`. `helm env` prints `HELM_CACHE_HOME`, `HELM_CONFIG_HOME`, `HELM_DATA_HOME` and `HELM_PLUGINS`; all four must start with your repository path. In a second terminal that has not sourced `env.sh`, `helm version --short` still prints the global version, which confirms the isolation works in both directions. `scripts/platform/cluster-status.sh` then reports the cluster side: the API server, the registry addon, both operators and their CRDs, and the observability pods.

## What you learned

- `scripts/env.sh` puts Helm 4 first on `PATH`, moves the four `HELM_*` locations into `.tools/helm/`, and refuses to continue unless Helm is version 4.
- `scripts/install-tools.sh` installs checksum-verified, pinned tools into `.tools/` only.
- The bootstrap installs operators and observability, never application resources, so charts own the Postgres and Kafka custom resources.
- Images are built once; every later chapter changes only charts and values.

Chapter 02 uses this lab to install a public chart and tours what changed from Helm 3 to Helm 4.

## Further reading

- Helm project, [Helm 4 overview](https://helm.sh/docs/overview/): the content-based cache, the plugin system and the renamed flags.
- Helm project, [Installing Helm](https://helm.sh/docs/intro/install/): the upstream install paths this lab replaces with a pinned, checksum-verified script.

---

*Verification status: <span class="status status--unverified">partially verified</span> on 2026-10-08, evidence `_plans/evidence/01-lab-setup.txt`. Observed on the live `helm4dev` profile: `./demo.sh offline` preflight passes, `cluster-status.sh` reports the platform healthy, the global Helm still reports v3.18.3, `helm env` and `helm plugin list` match the text, and the service image runs Python 3.14.8. The from-scratch run (delete the profile, then `./demo.sh`) was not repeated.*
