---
title: "The release lifecycle"
order: 12
part: "Data and lifecycle"
description: "Drive one release through good upgrades, failed upgrades and rollbacks with --wait, --rollback-on-failure and --cleanup-on-fail, and see what Helm 4 stores and how server-side apply changes conflicts."
duration: 45 minutes
---

Installing a chart is the easy half of Helm. The other half is what a release does when an upgrade goes wrong: which revision is live, what Helm cleans up, who owns each field of each object. This chapter takes the chart from chapter 11, switches it back to memory mode so every step is fast, and walks it through the failure paths that Helm 4 changed.

The code is in `examples/12-release-lifecycle/`. `./demo.sh offline` needs no cluster, and `./demo.sh` runs eleven numbered steps against minikube.

{% include excalidraw.html
   file="12-upgrade-failure-paths"
   alt="Flowchart of helm upgrade: render and apply, then wait; success supersedes the old revision, a timeout marks the revision failed, and the failed path leads to cleanup-on-fail, rollback-on-failure or a manual rollback, with history-max pruning old revisions"
   caption="Figure 12.1 — The paths out of a helm upgrade" %}

## Revisions live in Secrets

Each `helm install` or `helm upgrade` writes a new revision into a Secret named `sh.helm.release.v1.<release>.v<N>`, with the labels `owner=helm`, `name`, `status` and `version`. The `release` key holds the whole record: chart, values, manifest and status. It is a JSON document, gzipped, then base64-encoded by Helm, then base64-encoded again by the Kubernetes API when it serves the Secret. So decoding takes two `base64 -d` calls and a `gunzip`. `helm history` reads these Secrets, and `--history-max` (default 10) prunes the oldest. The status of a revision is one of `deployed`, `superseded`, `failed`, `uninstalled` and a few pending states, and exactly one revision per release is `deployed`.

The read commands expose pieces of that record: `helm status` (current state and notes), `helm get values` (user values, or `--all` for the merged set), `helm get manifest` (rendered objects, hooks excluded), `helm get hooks`, `helm get notes`, `helm get metadata` (chart name, version, app version, namespace, revision) and `helm get all` for the combination. These are per-revision, selectable with `--revision`. They show what Helm applied, not what the cluster holds now.

## Waiting, and what a timeout means

`--wait` accepts a strategy in Helm 4: `watcher` (kstatus-based, the value when you pass `--wait` alone), `hookOnly` (the default when the flag is absent) and `legacy` (the Helm 3 polling). See the [Helm 4 overview](https://helm.sh/docs/overview/) and [HIP-0022](https://github.com/helm/community/blob/main/hips/hip-0022.md). `--timeout` bounds each individual wait and defaults to five minutes. `--wait-for-jobs` adds Jobs to the wait. A wait that reaches the timeout fails the upgrade and marks the new revision `failed`.

`--rollback-on-failure` is the Helm 4 name for the rollback-on-failure behavior of Helm 3's atomic flag, as the [Helm 4 overview](https://helm.sh/docs/overview/) lists, and implies `--wait=watcher`. On failure Helm rolls back to the last successful revision. On a first install there is nothing to roll back to, so the release is uninstalled. `--cleanup-on-fail` is the milder option: it deletes only the resources that this upgrade created, and leaves the release in `failed` state.

## Server-side apply, ownership and conflicts

Helm 4 applies manifests with server-side apply by default for new releases, per the [Helm 4 overview](https://helm.sh/docs/overview/) and [HIP-0023](https://github.com/helm/community/blob/main/hips/hip-0023.md). Upgrades and rollbacks follow the method the previous revision used, so a release created by Helm 3 stays on client-side apply until you set `--server-side` yourself (`true`, `false` or `auto`, which is the default on `upgrade`). With server-side apply, the API server tracks which manager owns which field. If another manager, such as `kubectl scale` or an autoscaler, owns a field Helm wants to set to a different value, Helm stops with a conflict. `--force-conflicts` takes the fields over.

Two more flags cover objects Helm should not normally touch. `--take-ownership` lets an upgrade adopt resources that exist but lack Helm's ownership annotations (Helm normally refuses to overwrite them). `--force-replace` (the renamed Helm 3 force flag) deletes and recreates objects instead of patching them, which is how you change an immutable field, at the cost of downtime for that object.

## How the code works

The chart is chapter 11's, plus `templates/extra-configmap.yaml`: a second ConfigMap, gated by `extras.configMap` (default `false`) and named `<fullname>-extra`. Its only purpose is to exist in some revisions and not others, so there is something for `--cleanup-on-fail` to remove and for `--take-ownership` to adopt. The release runs in memory mode, with no database, so the failure cases depend on the image tag and not on Postgres.

`demo.sh` is a straight line of steps. Step 1 installs with `--wait --timeout 3m --history-max 5`; step 2 changes `config.defaultCarrier`, which changes the ConfigMap checksum, and the Deployment rolls. Step 3 is the failure that matters. It sets `image.tag=doesnotexist` with `--wait --timeout 60s --rollback-on-failure`. Step 4 repeats the bad tag but also sets `extras.configMap=true` and uses `--cleanup-on-fail`, then checks that `kubectl get configmap` reports the extra ConfigMap missing while `helm history` shows the revision as failed. Step 5 runs `helm rollback shipping 2`; step 6 reads everything back with `helm get`; step 7 decodes the newest release Secret with `base64 -d | base64 -d | gunzip` and prints its status, revision and chart version. Step 8 patches `spec.replicas` with `kubectl patch --field-manager=hfd-demo`, so that manager owns the field. A plain `helm upgrade` should stop on a conflict, and `--force-conflicts` takes the field back. Step 9 creates the `-extra` ConfigMap by hand, shows the upgrade refusing to adopt it, then repeats with `--take-ownership`. Step 10 runs `--force-replace`, and step 11 prints `helm history`.

## Observed failure path

The golden umbrella run recorded the negative control for step 3 in `_plans/evidence/golden-08-negative-control.txt`. It upgraded release `platform` with a nonexistent image tag:

```text
$ helm upgrade platform charts/shipping-platform -n hfd-26 -f values-dev.yaml --set shipping.image.tag=doesnotexist --wait --timeout 90s --rollback-on-failure
level=WARN msg="upgrade failed" name=platform error="resource Deployment/hfd-26/platform-shipping not ready. status: InProgress, message: Pending termination: 1\ncontext deadline exceeded"
Error: UPGRADE FAILED: release platform failed, and has been rolled back due to rollback-on-failure being set: resource Deployment/hfd-26/platform-shipping not ready. status: InProgress, message: Pending termination: 1
context deadline exceeded
rc=1
```

The history afterwards, trimmed to three rows and three columns, shows how Helm counts:

```text
REVISION  STATUS      DESCRIPTION
3         superseded  Upgrade complete
4         failed      Upgrade "platform" failed: resource Deployment/hfd-26/platform-shipping not ready. status: InProgress, message: Pending termination...
5         deployed    Rollback to 3
```

Three things stand out. The failed attempt keeps its own revision, 4. The rollback is a new revision, 5, whose description is `Rollback to 3`, not a return to revision 3. And the live image afterwards was `shipping-service:0.1.0` while the API still answered, because the old ReplicaSet kept serving during the whole failure.

The message deserves a warning. Helm said `Pending termination: 1`, which is kstatus describing the Deployment, not the cause. The image-pull error is on the pod, so `kubectl describe pod` is the next command after any `--wait` failure.

## Build, run, observe

```bash
[host]$ cd examples/12-release-lifecycle && ./demo.sh offline
```

The offline run lints, renders the chart with and without `extras.configMap`, runs the unit tests (15 across four suites) and validates with kubeconform. The live run needs a cluster:

```bash
[host]$ ./demo.sh
```

Read the history after steps 3 and 4. You should see a `failed` revision for each, and after step 5 a `deployed` revision described as `Rollback to 2`. Step 4 should show no `-extra` ConfigMap, because the cleanup removed it.

## Cross-check

Compare Helm's record with the live objects. `helm get manifest shipping -n hfd-12` lists the Deployment that Helm applied last, and `kubectl get deployment -o yaml` shows what runs now. After step 8's patch they differ in `spec.replicas` until the forced upgrade. The decoded Secret in step 7 must agree with `helm get metadata`, since both read the same record.

## What you learned

- Each revision is a Secret, `helm history` lists them, and a rollback adds a revision and does not rewind one.
- `--wait` has three strategies, `--rollback-on-failure` implies the watcher, and a failed first install is uninstalled.
- `--cleanup-on-fail` removes only what the upgrade added.
- Server-side apply is the default for new releases. Conflicts are resolved with `--force-conflicts`, adoption needs `--take-ownership`, and `--force-replace` recreates objects.

Chapter 13 turns from running releases to debugging charts before they run.

## Further reading

- Helm project, [Helm 4 overview](https://helm.sh/docs/overview/). Used here for: renamed flags, server-side apply default and the kstatus watcher.
- Helm project, [Helm 4 released](https://helm.sh/blog/helm-4-released/). Used here for: the release announcement and migration context.
- Helm project, [helm upgrade](https://helm.sh/docs/helm/helm_upgrade/) and [helm rollback](https://helm.sh/docs/helm/helm_rollback/). Used here for: `--wait`, `--timeout`, `--cleanup-on-fail`, `--history-max` and rollback semantics.
- Helm project, [helm history](https://helm.sh/docs/helm/helm_history/) and [helm get all](https://helm.sh/docs/helm/helm_get_all/). Used here for: revision listing and the read commands.
- Helm community, [HIP-0022, Wait with kstatus](https://github.com/helm/community/blob/main/hips/hip-0022.md) and [HIP-0023, Server-side apply](https://github.com/helm/community/blob/main/hips/hip-0023.md). Used here for: the design of the wait and apply changes.

---

*Verification status: <span class="status status--unverified">unverified</span>. A live run must confirm each of the eleven steps, in particular the field-manager conflict message in step 8, the refusal then adoption in step 9, and that `--cleanup-on-fail` removes only the new ConfigMap in step 4.*
