---
title: "A tour of Helm 4"
order: 2
part: "Getting started"
description: "What Helm is, how a release differs from a chart, and the install, list, status and uninstall cycle on a public OCI chart, plus what changed from Helm 3 to Helm 4."
duration: 35 minutes
---

Before writing a chart of your own, use somebody else's. This chapter installs `podinfo`, a small public web application, straight from an OCI registry, follows the release through its whole lifecycle, and ends with a table of what Helm 4 changed. The new idea is the separation of three things: a chart, a release, and the cluster state that proves the release exists.

The code is in `examples/02-helm-tour/`. `./demo.sh offline` renders the chart without a cluster; `./demo.sh` installs it into `hfd-02`. Chapter 01 builds the lab this chapter runs on.

{% include excalidraw.html
   file="02-helm-architecture"
   alt="Diagram in three columns: an OCI registry holding the podinfo chart artifact, the local Helm 4 client with values and a content cache, and a Kubernetes cluster holding the rendered objects and a release record Secret; arrows show pull, apply and record"
   caption="Figure 2.1 — Helm is a client: it pulls a chart, applies rendered objects and records a release in the cluster" %}

## What Helm is

Helm is a package manager for Kubernetes with three nouns.

- A **chart** is a versioned package: `Chart.yaml` metadata, default `values.yaml`, and a `templates/` directory of Go templates that render to Kubernetes manifests.
- A **release** is one installation of a chart into one namespace under a name you choose. The same chart installed twice with different names is two releases.
- A **repository** or **registry** stores charts. Classic repositories serve an `index.yaml` over HTTP; OCI registries store a chart as an artifact. This chapter uses OCI; chapters 19 and 20 cover both in depth.

Helm itself is only a command-line client. Nothing runs in the cluster on its behalf. When you run `helm install`, the client pulls the chart, merges values, renders the templates locally, sends the objects to the API server, and records the outcome as a release record. By default that record is a Secret named `sh.helm.release.v1.<release>.v<revision>` in the release namespace, which is why `helm list` works from any machine with cluster access. Chapter 04 opens one up.

## The chart you will install

`oci://ghcr.io/stefanprodan/charts/podinfo` is published by the podinfo maintainer and needs no login. The lab pins version `6.15.0`, the latest at the time of writing (2026-10-08). Always pass `--version`: without it Helm takes the newest tag, and your output stops matching this page the day a new release lands.

The chart is a `v1` chart (`apiVersion: v1` in its `Chart.yaml`). Helm 4 installs it unchanged, and the Helm 4 overview states that [v2 charts continue to work unchanged](https://helm.sh/docs/overview/) while a v3 chart API is experimental. Your own charts in the chapters that follow use `apiVersion: v2`.

## How the code works

The demo is one script and one values file.

### `values-tour.yaml`

```yaml
replicaCount: 2
ui:
  message: "Helm for Developers, chapter 02"
```

Values layer on top of the chart's `values.yaml`. Anything you do not set keeps the chart default, so these two keys are the only thing recorded as "your" values; `helm get values` later prints exactly them. Two replicas make the rollout visibly more than one pod. The `ui.message` key proves a value reaches a rendered template. Chapter 05 covers precedence rules for the real services.

### `demo.sh offline`

```
[host]$ helm show chart oci://ghcr.io/stefanprodan/charts/podinfo --version 6.15.0
[host]$ helm template podinfo oci://ghcr.io/stefanprodan/charts/podinfo --version 6.15.0 -n hfd-02 -f values-tour.yaml
```

`helm show chart` prints `Chart.yaml` and fails the demo unless `version: 6.15.0` is present. `helm show values` prints the defaults you may override; run it before writing any values file. `helm template` renders locally with no cluster connection, so the demo checks `replicas: 2` appears in the output. It then pipes the manifests through `kubeconform -strict`, which validates each object against the Kubernetes schemas. A run found five resources and all valid: one Service, one Deployment and three Pods. The Pods are the chart's test hooks, which `helm test` runs on demand.

### `demo.sh` (full run)

```
[host]$ helm install podinfo oci://ghcr.io/stefanprodan/charts/podinfo --version 6.15.0 --kube-context helm4dev -n hfd-02 --create-namespace -f values-tour.yaml --wait --rollback-on-failure --timeout 3m
```

Each flag has a job.

- `podinfo` is the release name. Charts derive object names from it; because the release name already contains the chart name, podinfo's naming helper does not repeat it, and the Deployment is named `podinfo` (a release named `pod` would give `pod-podinfo`). Chapter 07 writes that helper.
- `--kube-context helm4dev` pins the cluster. The lab pins it on every command so a stale current context cannot send an install to the wrong cluster.
- `-n hfd-02 --create-namespace` scopes the release and creates the namespace if absent.
- `--wait` makes Helm block until the resources are ready. In Helm 4 the wait is driven by a [kstatus-based watcher](https://helm.sh/docs/overview/); `helm install --help` lists three strategies, `watcher`, `hookOnly` and `legacy`, and `--wait` alone selects `watcher`.
- `--rollback-on-failure` is the Helm 4 name for what Helm 3 called `--atomic`. <!-- helm3-reference --> A failed install is removed instead of left in a `failed` state. `--timeout 3m` bounds the wait.

After the install the script runs `helm list`, `helm status`, `kubectl get secret -l owner=helm` and `helm get values`, then probes the application with `podcli check http localhost:9898/healthz` inside the pod, and finishes with `helm uninstall --wait`. The probe uses the in-pod `podcli` binary so the chapter needs no host access. `./demo.sh clean` runs `helm uninstall --ignore-not-found` and deletes the namespace.

Server-side apply is the other change visible here. For a new release Helm 4 now applies objects with [server-side apply by default](https://helm.sh/docs/overview/); `helm install --help` shows `--server-side` defaulting to true.

## Build, run, observe

```
[host]$ cd examples/02-helm-tour && ./demo.sh offline
```

Then, with the lab from chapter 01 running:

```
[host]$ ./demo.sh
```

Expect `helm list` to show `podinfo` in `hfd-02` with status `deployed` and chart `podinfo-6.15.0`. `helm status podinfo` prints the revision, the last deployed time and any NOTES. `kubectl get secret -l owner=helm` shows one release record. After `helm uninstall`, `helm list` returns an empty table and the Secret is gone.

## Cross-check

Compare what Helm says with what Kubernetes says. `helm get manifest podinfo -n hfd-02` prints the rendered objects Helm stored; `kubectl -n hfd-02 get deploy podinfo -o yaml` shows the live object, which should contain `replicas: 2` and the same image `ghcr.io/stefanprodan/podinfo:6.15.0`. The two differ in server-populated fields such as `status` and `managedFields`, and agree on everything you set.

## Helm 3 to Helm 4 at a glance

Changed behavior cites official sources. The full migration reference is chapter 28.

| Area | Helm 3 | Helm 4 | Source |
|---|---|---|---|
| Rollback on failure | `--atomic` | `--rollback-on-failure`; the old flag remains and warns that it is deprecated | [Overview](https://helm.sh/docs/overview/) <!-- helm3-reference --> |
| Replace on conflict | `--force` | `--force-replace`; the old flag remains and warns | [Overview](https://helm.sh/docs/overview/) |
| Apply method | Client-side three-way merge | Server-side apply for new releases; upgrades follow the release's previous method | [Overview](https://helm.sh/docs/overview/) |
| Waiting | Legacy readiness polling | kstatus-based watcher; `--wait` takes `watcher`, `hookOnly` or `legacy` | [`helm install`](https://helm.sh/docs/helm/helm_install/) |
| Plugins | One subprocess model | New plugin system with an optional Wasm runtime; CLI, getter and post-renderer types | [Overview](https://helm.sh/docs/overview/), [HIP-0026](https://github.com/helm/community/blob/main/hips/hip-0026.md) |
| Post-renderers | Any executable path | Plugin name only | [Overview](https://helm.sh/docs/overview/) |
| Registry login | Accepted a URL | Domain name only | [Overview](https://helm.sh/docs/overview/) |
| OCI install | By tag | Also by digest, `oci://...@sha256:...` | [Overview](https://helm.sh/docs/overview/) |
| Values | One YAML document per file | Multi-document values files | [Overview](https://helm.sh/docs/overview/) |
| Chart caching | Archive cache | Content-based local cache | [Overview](https://helm.sh/docs/overview/) |
| Chart API | `v2` | `v2` unchanged; experimental `v3` behind `HELM_EXPERIMENTAL_CHART_V3` | [Overview](https://helm.sh/docs/overview/) |
| Logging | Not `slog` based | `slog` | [Release post](https://helm.sh/blog/helm-4-released/) |

Helm 3 receives bug fixes until July 8th 2026 and security fixes until November 11th 2026, per the [release post](https://helm.sh/blog/helm-4-released/).

## What you learned

- A chart is a package, a release is one named installation of it, and the release record lives in the cluster as a Secret, so Helm itself needs no server.
- An install with a pinned `--version`, `--wait` and `--rollback-on-failure` is the baseline command later chapters extend.
- `helm show chart`, `show values` and `template` inspect a chart before anything touches a cluster.
- Helm 4 renamed `--atomic` and `--force`, defaults to server-side apply for new releases, and rebuilt plugins and post-renderers. <!-- helm3-reference -->

Chapter 03 returns to the shipping service and deploys it as raw manifests, so the problem a chart solves is concrete.

## Further reading

- Matt Butcher, Matt Farina, Josh Dolitsky, *Learning Helm* (O'Reilly, 2021), ISBN 9781492083641. Used here for: package-manager concepts, charts, releases and repositories.
- Helm project, [Helm 4 overview](https://helm.sh/docs/overview/) and [Helm 4 released](https://helm.sh/blog/helm-4-released/): the changes in the table above.
- Helm project, [Using Helm](https://helm.sh/docs/intro/using_helm/): the install, list and uninstall workflow.

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/02-helm-tour.txt`. The install reached `deployed` with two ready pods, the `sh.helm.release.v1.podinfo.v1` Secret existed and was gone after uninstall, `podcli check http` returned 200 in-pod, and `helm get manifest` matched the live Deployment (2 replicas, image `ghcr.io/stefanprodan/podinfo:6.15.0`).*
