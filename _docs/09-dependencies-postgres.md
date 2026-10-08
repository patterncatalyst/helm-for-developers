---
title: "Dependencies and a Postgres subchart"
order: 9
part: "Data and lifecycle"
description: "Add a shipping-postgres subchart that renders a CloudNativePG Cluster, switch it with a condition, and wire the service to it with import-values."
duration: 35 minutes
---

Until now the shipping service kept its shipments in memory. This chapter gives it a database without giving the chart a second release to manage. A `shipping-postgres` chart renders a CloudNativePG `Cluster`, `shipping-service` declares it as a dependency, and `import-values` hands the service the host name and the name of the generated credentials Secret.

The code is in `examples/09-postgres-subchart/`. `./demo.sh offline` needs no cluster; `./demo.sh` runs the live install and its `README.md` lists the prerequisites.

{% include excalidraw.html
   file="09-subchart-tree"
   alt="Diagram of the shipping-service parent chart depending on the shipping-postgres subchart, importing its exported host and secret name into the parent values, and the resulting Deployment and CloudNativePG Cluster"
   caption="Figure 9.1 — The parent chart, its subchart and the values that flow between them" %}

## Dependencies are charts in `charts/`

A dependency is a chart that Helm renders as part of the parent release. You declare it under `dependencies:` in `Chart.yaml`. `helm dependency build` resolves the declaration, writes `Chart.lock`, and stores a packaged copy in the parent's `charts/` directory. A `file://` repository is a path relative to the parent chart, which suits charts that live in one repository. `Chart.lock` records each dependency's resolved version and a digest of the declaration, so a changed `Chart.yaml` is detectable. `helm dependency list` shows each entry and whether the packaged copy matches. The copy is a `.tgz`, so a fresh checkout needs `helm dependency build` before the first template or install. The example ignores `charts/*.tgz` in version control and commits `Chart.lock`, which is the usual split: the lock is source, the archive is a build product.

Subcharts are isolated. A subchart sees its own values plus `global`, and the parent overrides subchart values by nesting them under the subchart's name. Four `Chart.yaml` fields control how a dependency behaves:

- `condition` names a value path. When it resolves to false, Helm drops the dependency.
- `tags` groups dependencies so one key (`tags.messaging`) switches several. A condition that resolves takes precedence over tags. Chapter 16 uses tags on the umbrella.
- `alias` renders the same chart twice under different names, and is the reason the umbrella in chapter 16 can call `shipping-service` just `shipping`.
- `import-values` copies selected child values up into the parent.

## Overriding and sharing values

The parent reaches into a subchart by nesting values under the dependency's name:

```bash
[host]$ helm template shipping examples/09-postgres-subchart/shipping-service -f examples/09-postgres-subchart/values-postgres.yaml --set shipping-postgres.cluster.instances=3
```

The `--set` path is `<subchart name>.<subchart key>`, so the rendered `Cluster` gets `instances: 3` while the parent's own keys stay untouched. For values both charts need, `global` is the shared channel: every chart in the tree sees the same `global` map. The service already reads `global.environment` and `global.imageRegistry` this way.

`helm dependency update` and `helm dependency build` differ. `update` re-resolves versions from `Chart.yaml` and rewrites `Chart.lock`. `build` reinstalls exactly what `Chart.lock` records and fails if the lock and `Chart.yaml` disagree. Use `update` when you change a dependency declaration and `build` in CI and on a fresh checkout, so the build is repeatable.

## How the code works

The parent's dependency block is the whole contract:

```yaml
dependencies:
  - name: shipping-postgres
    version: 0.9.0
    repository: file://../shipping-postgres
    condition: shipping-postgres.enabled
    import-values:
      - child: exports.postgres
        parent: postgres
```

`version` must match the subchart's `Chart.yaml`; Helm also accepts SemVer ranges for remote repositories. `condition: shipping-postgres.enabled` reads `shipping-postgres: {enabled: false}` from the parent's `values.yaml`. That default is `false` because a chart whose default install needs a database operator is hostile to a first-time reader. `values-postgres.yaml` flips it to `true` and sets `config.storage: postgres`.

The subchart is a normal chart with one resource, `templates/cluster.yaml`, which renders `postgresql.cnpg.io/v1` `Cluster` from `cluster.*` values: instance count, storage size, the initial `database` and `owner`. CloudNativePG reacts to that object by creating the pod `shipping-postgres-1`, the Services `shipping-postgres-rw` and `-ro`, and the Secret `shipping-postgres-app` with the keys `dbname`, `username` and `password`. The chart never writes a password. The operator generates it, and the app reads it:

```yaml
exports:
  postgres:
    host: shipping-postgres-rw
    existingSecret: shipping-postgres-app
```

`exports` is a plain key with no meaning to Helm. `import-values` maps `exports.postgres` onto the parent's `postgres` key, so the parent behaves as if `postgres.host` and `postgres.existingSecret` were in its own `values.yaml`. Those two keys have no default in the parent for a reason: imported values lose to anything the parent already sets. The exports are static strings, so they must equal `cluster.name` plus `-rw` and `-app`. Rename the cluster and you must edit `exports`.

On the parent side, the helper `shipping-service.pgEnv` builds the container environment. With `postgres.existingSecret` set it emits `PG_DATABASE`, `PG_USER` and `PG_PASSWORD` as `secretKeyRef` entries pointing at the generated Secret, using the key names from `postgres.existingSecretKeys`. Without it, it falls back to `postgres.database`, `postgres.user` and an optional chart-owned password from chapter 08. `PG_HOST` uses `required`, so `config.storage=postgres` with no host stops at render time. `values.schema.json` enforces the same rule earlier with an `if/then` on `config.storage`, and it lists `shipping-postgres` as an allowed key because the schema sets `additionalProperties: false`.

Two details to know. The schema's host rule runs on the coalesced values, which include imports for `helm template` and `helm install`. `helm lint` does not resolve `import-values`, so the postgres lint run in `demo.sh` passes `--set postgres.host=shipping-postgres-rw`; without it, lint fails with `at '/postgres': missing property 'host'`. And in this chapter the readiness probe is switched to `/health`, because the tables do not exist yet. Chapter 11 fixes that properly.

## Build, run, observe

```bash
[host]$ cd examples/09-postgres-subchart && ./demo.sh offline
```

The offline run builds the dependency, lints both value sets, renders memory mode (three objects) and postgres mode (four, the extra one being the `Cluster`), runs four unit tests, and validates the manifests with kubeconform. The CNPG `Cluster` has no schema in the default catalog, so kubeconform skips it and says so in its summary.

```bash
[host]$ ./demo.sh
```

The live run installs release `shipping` into `hfd-09` with `--wait`, so Helm blocks until the Deployment is ready. It then runs `python -m app.migrate` inside the app container by hand, opens the tunnel, and creates a shipment through `http://127.0.0.1:8080/api/shipments`. The manual migration is a stand-in that chapter 11 replaces.

## Cross-check

The most common surprise with `file://` dependencies: Helm renders the packaged copy in `charts/`, not the directory you are editing. Change `shipping-postgres/templates/cluster.yaml`, run `helm template`, and the old output comes back until you run `helm dependency build` again. `demo.sh` rebuilds at the start of every mode for that reason.

Then compare what Helm believes with what the cluster holds:

```bash
[host]$ helm get manifest shipping -n hfd-09 | grep -A3 'kind: Cluster'
[host]$ kubectl -n hfd-09 get cluster.postgresql.cnpg.io,secret shipping-postgres-app
```

The `Cluster` name in the manifest must equal `exports.postgres.existingSecret` minus `-app`. If they differ, the pod starts and then fails to find its credentials. The Secret key list from `kubectl` (`dbname`, `password`, `username` and the rest CNPG adds) must include the three names in `postgres.existingSecretKeys`.

## What you learned

- A dependency is a chart rendered into the parent release. `file://` suits one repository, and `helm dependency build` creates the `.tgz` you must rebuild on a fresh checkout.
- `condition` switches a subchart from a value, with `tags` as the group version. `import-values` moves child values up and loses to any parent default.
- Credentials never pass through Helm here. The operator creates the Secret and the pod reads it by `secretKeyRef`.
- Lint ignores imports, so give `helm lint` the values the import would supply.

Chapter 10 looks at what happens when the CRD behind that `Cluster` is missing, and at the one directory Helm treats specially for CRDs.

## Further reading

- Matt Butcher, Matt Farina, and Josh Dolitsky, *Learning Helm* (O'Reilly, 2021), ISBN 9781492083641. Used here for: chart dependencies, subchart values scoping and `global`.
- Andrew Block and Austin Dewey, *Managing Kubernetes Resources Using Helm, 2nd ed.* (Packt, 2022), ISBN 9781803242897. Used here for: chart dependencies and conditional subcharts.
- Bilgin Ibryam and Roland Huß, *Kubernetes Patterns, 2nd ed.* (O'Reilly, 2023), ISBN 9781098131678. Used here for: the Operator pattern behind the CloudNativePG `Cluster`.

---

*Verification status: <span class="status status--unverified">unverified</span>. A live run must confirm that `--wait` succeeds with the CNPG `Cluster`, that the pod authenticates with the generated Secret, and that the manual migration followed by a POST stores a row.*
