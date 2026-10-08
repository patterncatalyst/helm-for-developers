---
title: "Hooks and database migrations"
order: 11
part: "Data and lifecycle"
description: "Run the schema migration as a Helm hook Job, choose between pre-install and post-install, and avoid the deadlock between hooks and --wait."
duration: 40 minutes
---

The service now has a database, but an empty one: the tables are created by `python -m app.migrate`, and chapter 09 ran that by hand. A Helm hook turns the step into part of the release. The Job itself is routine. Where the hook runs relative to the rest of the release decides whether the install works at all, and one combination hangs until the timeout.

The code is in `examples/11-hooks-migrations/`. `./demo.sh offline` needs no cluster. The live modes are `./demo.sh`, `./demo.sh deadlock` and `./demo.sh preinstall`.

{% include excalidraw.html
   file="11-hook-timeline"
   alt="Two timelines. Option A runs a pre-install migration hook before the release resources, which fails when the database is created by the same release. Option B waits for all resources to be ready before the post-install hook, which deadlocks when readiness needs the migrated tables"
   caption="Figure 11.1 — Where the migration hook runs, and what each placement breaks" %}

## What a hook is

A hook is an ordinary manifest in `templates/` with a `helm.sh/hook` annotation. Helm renders it, but keeps it out of the release's resource list and runs it at a named point of the lifecycle: `pre-install`, `post-install`, `pre-upgrade`, `post-upgrade` (plus delete, rollback and test phases). Several phases can share one annotation, separated by commas. Three more annotations tune it, all described in the [Helm hooks documentation](https://helm.sh/docs/topics/charts_hooks/):

- `helm.sh/hook-weight` orders hooks inside one phase, ascending, as a string holding an integer. Helm sorts by weight, then kind, then name.
- `helm.sh/hook-delete-policy` says when Helm deletes the hook object. The default is `before-hook-creation`. `hook-succeeded` and `hook-failed` delete after the outcome.
- Helm waits for a Job hook to finish. A failed hook fails the release.

Because hooks are not in the release manifest, `helm get manifest` omits them. `helm get hooks` prints them.

## Hooks and `--wait`

In Helm 4, `--wait` takes a strategy: `watcher` (the default when you pass `--wait` alone) uses kstatus to wait until resources report ready, `hookOnly` is the default when you omit the flag and waits only for hooks, and `legacy` keeps the Helm 3 polling. [HIP-0022](https://github.com/helm/community/blob/main/hips/hip-0022.md) describes the kstatus design, and `--rollback-on-failure` implies `watcher`. The order of events matters here: with a `post-install` hook, Helm applies the resources, **waits for them to be ready, and only then** runs the hook.

That order creates a deadlock when readiness depends on the hook. The shipping service reports ready on `/healthz`, which checks the database and returns 503 until the tables exist. With `--wait`, the Deployment never becomes ready, so the hook never starts, so the tables never appear. The umbrella chart of chapter 16 hit exactly this. The log below comes from the same chart installed into `hfd-26` for chapter 26 with `--timeout 8m`, and records the outcome after the full eight minutes:

```text
Error: release platform failed, and has been uninstalled due to rollback-on-failure being set: resource Deployment/hfd-26/platform-shipping not ready. status: InProgress, message: Available: 0/1
context deadline exceeded
```

(`--rollback-on-failure` explains "uninstalled" on a first install. Chapter 12 covers it.) `./demo.sh deadlock` reproduces the same failure at example scale. It omits `--rollback-on-failure`, so the release stays in the `failed` state, and after 90 seconds it printed:

```text
Release "shipping" does not exist. Installing it now.
Error: resource Deployment/hfd-11/shipping-shipping-service not ready. status: InProgress, message: Available: 0/1
context deadline exceeded
install failed as expected (rc=1)
NAME                                         READY   STATUS    RESTARTS   AGE
shipping-postgres-1                          1/1     Running   0          86s
shipping-shipping-service-755c7f94cd-bksx4   0/1     Running   0          90s
```

`kubectl get jobs` returned nothing, because the hook never started, the namespace events showed `Readiness probe failed: HTTP probe failed with statuscode: 503`, and `helm status` reported `STATUS: failed`. The fix was to point the readiness probe at `/health`, which does not touch the database. The other way out is a `pre-install` hook, which runs before the resources and so never waits on readiness. That works only when the database already exists. Here the `Cluster` and its `shipping-postgres-app` Secret are created by the same release, so a `pre-install` Job cannot start: its pod references a Secret that does not exist yet. `./demo.sh preinstall` reproduces that, and the Job waits until Helm's timeout. After 90 seconds it printed:

```text
Error: failed pre-install: resource Job/hfd-11/shipping-shipping-service-migrate not ready. status: InProgress, message: Job in progress
context deadline exceeded
install failed as expected (rc=1)
NAME                                      READY   STATUS                       RESTARTS   AGE
shipping-shipping-service-migrate-fqcp9   0/1     CreateContainerConfigError   0          90s
```

The pod event names the cause: `Error: secret "shipping-postgres-app" not found`. No Deployment, Service or CNPG `Cluster` exists at that point, because a failed pre-install hook stops the release before it applies them, so the Secret never appears.

| Placement | Works when | Breaks when |
|---|---|---|
| `pre-install,pre-upgrade` | the database exists before the release | the release creates the database (fresh install) |
| `post-install,post-upgrade` | readiness does not need the migration | `--wait` and a readiness probe on migrated data |

Chart default is `pre-install,pre-upgrade`, which is right for an external database or a database created by a different release. The values file for this chapter overrides it with `post-install,post-upgrade` and moves readiness to `/health`.

## How the code works

`templates/migration-job.yaml` renders only when `migration.enabled` is true **and** `config.storage` is `postgres`; a memory-mode release has nothing to migrate. The annotations come from values: `"helm.sh/hook": {% raw %}{{ .Values.migration.hooks | quote }}{% endraw %}` and the weight, quoted because annotation values must be strings. The delete policy is fixed at `before-hook-creation,hook-succeeded`. `before-hook-creation` removes the previous run's Job so a second upgrade can create a new one under the same name. `hook-succeeded` cleans up after success. There is no `hook-failed`, so a failed Job stays for `kubectl logs`.

The Job spec sets `restartPolicy: Never` with `backoffLimit: 3`, so a failed pod is replaced up to three times, each with its own logs, rather than restarted in place. `activeDeadlineSeconds: 600` caps the whole Job. The container runs the same image as the app, `command: ["python", "-m", "app.migrate"]`, with `SHIPPING_STORAGE=postgres` and the `PG_*` variables from the shared `shipping-service.pgEnv` helper. Reusing the helper means the Job and the Deployment cannot disagree about the database. The migration is idempotent and takes an advisory lock, so a repeated or concurrent run is safe. The Job carries the same security context as the app, with `readOnlyRootFilesystem` and an `emptyDir` on `/tmp`, so it passes the same admission rules.

`templates/warm-job.yaml` is a second hook. With `warm.enabled=true` it runs on `post-upgrade` at weight `10` and calls `/api/info` once, a stand-in for cache warming. Because the migration hook uses `post-upgrade` at weight `0` in this chapter's values, Helm runs the migration first and the warm Job second. `helm.sh/hook-weight` is the only ordering control inside a phase.

An init container is the alternative to a hook. It runs on every pod start and blocks that pod until the migration is done. The migration then runs once per replica, with a lock, and not once per release. A hook runs once per release and does not run on a plain pod restart or a scale-out. Use a hook for a schema change that must precede the new code, and an init container for per-pod readiness checks such as waiting for a dependency.

## Build, run, observe

```bash
[host]$ cd examples/11-hooks-migrations && ./demo.sh offline
```

The offline run prints the hook annotations of the rendered Job for the postgres values (`post-install,post-upgrade`) and for the chart default (`pre-install,pre-upgrade`), then runs 13 unit tests across the three suites and validates with kubeconform.

```bash
[host]$ ./demo.sh
```

The live run installs with `--wait --timeout 8m`. The Job is gone by the time it returns, so the script reads the events and queries the database. The umbrella run produced this (abridged), and your run should show the same shape:

```text
LAST SEEN   TYPE     REASON             OBJECT                          MESSAGE
11m         Normal   SuccessfulCreate   job/platform-shipping-migrate   Created pod: platform-shipping-migrate-zvgmf
11m         Normal   Completed          job/platform-shipping-migrate   Job completed
```

The standalone run behaves the same way: the install Job created two pods (`9xxcn`, then `fxcpq`), and the second completed. Watching a repeat install showed why. The first pod's log ended with `ConnectionRefusedError: [Errno 111] Connect call failed ('10.106.152.53', 5432)`: the likely cause, inferred from the timing and not observed directly, is that Helm's wait treated the CNPG `Cluster` as ready before the PostgreSQL instance accepted connections; the migration container failed, and the Job's `backoffLimit: 3` started a second pod that logged `migrate applied V1__create_shipments.sql` and `V2__unique_order_id.sql`. The retry is the Job's backoff, not an error to fix. The events below span the end of the install and the following upgrade with `warm.enabled=true`; in the upgrade Helm ran the migration Job (weight 0) before the warm Job (weight 10):

```text
LAST SEEN   TYPE     REASON             OBJECT                                  MESSAGE
10s         Normal   SuccessfulCreate   job/shipping-shipping-service-migrate   Created pod: shipping-shipping-service-migrate-fxcpq
8s          Normal   Completed          job/shipping-shipping-service-migrate   Job completed
7s          Normal   SuccessfulCreate   job/shipping-shipping-service-migrate   Created pod: shipping-shipping-service-migrate-g5qsw
4s          Normal   Completed          job/shipping-shipping-service-migrate   Job completed
4s          Normal   SuccessfulCreate   job/shipping-shipping-service-warm      Created pod: shipping-shipping-service-warm-nhqb6
1s          Normal   Completed          job/shipping-shipping-service-warm      Job completed
```

The upgrade's migration Job completed after one pod. `shipping.schema_migrations` then lists versions 1 and 2.

## Cross-check

The command `helm get hooks shipping -n hfd-11` prints the Job with its annotations from the stored release, independent of the template files. Compare it to the Job from `helm template --show-only templates/migration-job.yaml`; the two agree because the release stores the rendered output. For the database side, `psql -d shipping -c 'select * from shipping.schema_migrations'` inside `shipping-postgres-1` is the proof that the migration ran, since the Job object is deleted.

## What you learned

- A hook is a manifest with `helm.sh/hook`, `hook-weight` and `hook-delete-policy` annotations that Helm runs at a lifecycle point and waits for.
- `post-install` hooks start only after `--wait` sees the release ready, so readiness must not depend on them.
- `pre-install` hooks need their dependencies to exist already. A database created by the same release forces `post-install`.
- `hook-succeeded` keeps the namespace clean, and omitting `hook-failed` keeps failures debuggable.

Chapter 12 uses the same chart to walk the failure paths of `helm upgrade`.

## Further reading

- Matt Butcher, Matt Farina, Josh Dolitsky, *Learning Helm* (O'Reilly, 2021), ISBN 9781492083641. Used here for: the hook lifecycle model, weights and delete policies as concepts.
- William Denniss, *Kubernetes for Developers* (Manning, 2024), ISBN 9781617297175. Used here for: Kubernetes Jobs and completion semantics.
- Bilgin Ibryam and Roland Huß, *Kubernetes Patterns, 2nd ed.* (O'Reilly, 2023), ISBN 9781098131678. Used here for: the Init Container pattern.
- Helm project, [Chart hooks](https://helm.sh/docs/topics/charts_hooks/). Used here for: hook phases, weights and delete policies.
- Helm community, [HIP-0022, Wait with kstatus](https://github.com/helm/community/blob/main/hips/hip-0022.md). Used here for: the Helm 4 `--wait` watcher.

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/11-hooks-migrations.txt`. Observed on Helm 4.3.0: the post-install migration succeeded under `--wait`, the Job was deleted on success and `shipping.schema_migrations` held versions 1 and 2, the warm hook ran after the migration, `deadlock` failed with `context deadline exceeded` and no Job, and `preinstall` failed with `secret "shipping-postgres-app" not found` (evidence also in `_plans/evidence/11-hooks-migrations-deadlock.txt` and `-preinstall.txt`).*
