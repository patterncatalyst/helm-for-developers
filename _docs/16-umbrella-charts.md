---
title: "Umbrella charts"
order: 16
part: "Multi-service applications"
description: "Combine the services, the database and Kafka into one release with aliases, conditions, tags, global values and import-values, and learn where an umbrella cannot order things."
duration: 45 minutes
---

Chapter 15 left you with three releases and a Kafka address copied between values files. An umbrella chart replaces them with one release, one `helm install`, and one rollback unit. It also introduces the first bugs that exist only because charts are composed.

The code is in `examples/16-umbrella/`. The `demo.sh` there installs and runs it; its `README.md` covers what it does and how to drive it.

{% include excalidraw.html
   file="16-umbrella-topology"
   alt="Diagram: the shipping-platform umbrella contains shipping and notification application subcharts and db and kafka infrastructure subcharts; global values flow to all of them and import-values carries the database host, Secret name and Kafka bootstrap address up into the application values"
   caption="Figure 16.1 — The umbrella: aliases, switches, global values and imported values" %}

## What the umbrella adds

`shipping-platform` has almost no templates of its own. Its `Chart.yaml` lists four dependencies, and each one uses an `alias`, so the values key and the object names read `shipping`, `notification`, `db` and `kafka` instead of the chart names. Because the alias also becomes `.Chart.Name` inside the subchart, the fullname helper yields `platform-shipping` for release `platform`, not `platform-shipping-service`.

Helm merges every subchart's rendered resources into one manifest and applies them as one release. Dependencies are a packaging relationship, not a start-up order.

## How the code works

**Dependencies and switches.** The four entries in `Chart.yaml`:

```yaml
dependencies:
  - name: shipping-service
    alias: shipping
    version: 0.16.0
    repository: file://../shipping-service
    condition: shipping.enabled
  - name: notification-service
    alias: notification
    tags: [messaging]
  - name: shipping-postgres
    alias: db
    condition: db.enabled
    import-values:
      - child: exports.postgres
        parent: shipping.postgres
  - name: shipping-kafka
    alias: kafka
    tags: [messaging]
    import-values:
      - child: exports.kafka
        parent: shipping.kafka
      - child: exports.kafka
        parent: notification.kafka
```

A `condition` is a single values path (`db.enabled`). A tag groups subcharts under one switch in the top-level `tags:` map: `tags.messaging: false` removes notification and kafka together. When a dependency has a `condition` that resolves to a value, the condition wins over its tags. Here shipping and db use conditions and notification and kafka use tags only, so the two mechanisms do not overlap.

**Global values.** `global:` is the one values key that every subchart sees under the same name. The umbrella sets `environment`, `otlpEndpoint`, `imageRegistry` and `partOf`; the services read them in their helpers (`global.environment` wins over `config.environment`, and `global.imageRegistry` prefixes the image). The umbrella's `values.schema.json` restricts `global.environment` to `dev`, `stage`, `prod` and `openshift`, so a typo fails at the top, before any subchart renders.

**import-values.** `shipping-postgres` and `shipping-kafka` each define an `exports:` block in their own `values.yaml`. `import-values` copies `exports.postgres` into `shipping.postgres` and `exports.kafka` into both application keys, so the umbrella never types a hostname. The exported strings are static: `shipping-postgres-rw` and `shipping-kafka-kafka-bootstrap:9092` must match `cluster.name` and `clusterName`. Chapter 9 introduced the mechanism; the trap is new.

**Dependency packaging.** The four dependencies use `file://` repositories, so `helm dependency build charts/shipping-platform` packs each sibling chart into `charts/*.tgz` and records digests in `Chart.lock`. The tarballs are build output and are git-ignored; run the command again on a fresh checkout and after any change to a subchart, because `helm install` renders the packed copy, not the sibling directory. Each version in `Chart.yaml` must equal the sibling's `version`, which is why every chart in this snapshot moves to `0.16.0` together.

**The environment file.** `values-dev.yaml` is the only overlay in this chapter. It sets `global.environment: dev`, turns OpenTelemetry on through `global.otlpEndpoint`, gives both Services a `NodePort` (30080 and 30081, the ports `scripts/tunnel.sh` forwards to 8080 and 8081) and sets `shipping.auth.token: dev-token`. Everything a subchart needs goes under its alias, so the file reads as one document about the whole platform. Chapter 24 adds stage and prod overlays on the same keys.

**Names the umbrella has to guess.** The release test in the umbrella (`templates/tests/test-connection.yaml`) must call the subchart Services by name, but a parent template cannot read a subchart's helpers. `shipping-platform.svcName` in `_helpers.tpl` repeats the fullname rule (`fullnameOverride`, then `nameOverride`, then release plus alias). If the rule in a subchart changes, this copy has to change with it; the platform unit tests catch that by asserting the rendered names.

## Two traps

**An imported key cannot override a subchart default.** In the render the subchart's own default beats the imported value. If notification-service sets `kafka.bootstrap: "stale:9092"` as a default, the umbrella renders `stale:9092` and the imported address is ignored. That is why the service charts leave `postgres.host`, `postgres.existingSecret` and `kafka.bootstrap` out of `values.yaml` and use `required`. The demo reproduces it on a temporary copy:

```text
- name: KAFKA_BOOTSTRAP
  value: "stale:9092"
```

**A tag does not switch off a value that points at the subchart.** `tags.messaging: false` removes the kafka chart, but `shipping.kafka.enabled` is still `true`, so shipping asks for an address that is no longer imported and the render stops with `kafka.bootstrap is required when kafka.enabled=true`. Pair the two settings: `--set tags.messaging=false --set shipping.kafka.enabled=false`. The unit suite `toggles_test.yaml` and `ci/ci-values.yaml` both encode the pair.

## Ordering limits

Within a release Helm sorts resources by kind, not by chart: Secrets, ConfigMaps and Services first, workloads after, and kinds it does not know, such as `Cluster` and `Kafka`, last. All of it is submitted in one pass. The operators reconcile their resources while the application pods are already starting, which is why shipping can start before Kafka accepts connections and restart until it does. Nothing in `dependencies` changes this. Three tools do shape order: readiness probes (a pod is not Ready until it works), hooks with weights, and `--wait`. Use them for what must happen first, and make each service retry its own connections.

## What `--wait` cannot order

The umbrella owns the CloudNativePG `Cluster`, so the `<cluster>-app` Secret that the migration Job reads does not exist before install. A `pre-install` hook would run before the Secret does. The umbrella therefore sets `shipping.migration.hooks: post-install,post-upgrade`, which the shipping template writes into the Job's `helm.sh/hook` annotation.

That choice interacts with `--wait`. Post-install hooks run after Helm sees every resource ready. shipping's default readiness path, `/healthz`, fails until the tables exist, and the tables are created by the hook. In the first platform run the release waited on the pod and the hook waited on the release; after the full `--timeout 3m` Helm reported:

```text
Error: release platform failed, and has been uninstalled due to rollback-on-failure being set: resource Deployment/hfd-16/platform-shipping not ready. status: InProgress, message: Available: 0/1
context deadline exceeded
```

The fix is in `values.yaml`: `shipping.probes.readiness.path: /health` checks process health, the pod becomes ready, the hook runs, and `/healthz` turns green on its own. Both `--wait` modes and `--rollback-on-failure` are Helm 4 behavior; see the [Helm 4 announcement](https://helm.sh/blog/helm-4-released/) and the [hooks documentation](https://helm.sh/docs/topics/charts_hooks/).

## Build, run, observe

```bash
cd examples/16-umbrella && ./demo.sh
```

`./demo.sh offline` runs `helm dependency build`, lint, 13 unit tests and kubeconform on all 15 rendered resources, then replays both traps. The full run installs release `platform` into `hfd-16` and repeats chapter 15's dispatch check against one release.

## Cross-check

Rendering with and without `--set tags.messaging=false --set shipping.kafka.enabled=false` should differ by exactly the notification and Kafka objects. After an install, `helm get manifest platform -n hfd-16 | grep '^kind:' | sort | uniq -c` lists the same kinds `kubeconform` validated. A third check needs no cluster: `helm unittest charts/shipping-platform` renders the subcharts through their aliases (`charts/shipping/...`, `charts/db/...`) and asserts the imported host, the hook phase and the image registry in one pass.

## What you learned

- Aliases rename both the values key and the object names; `condition` and `tags` switch subcharts; `global` reaches all of them.
- `import-values` fills keys the subchart leaves undefined and loses to any default.
- Hooks plus `--wait` order resources only if readiness does not depend on the hook.

Chapter 17 removes the helper code the two service charts still duplicate.

## Further reading

- Matt Butcher, Matt Farina, Josh Dolitsky, *Learning Helm* (O'Reilly, 2021), ISBN 9781492083641. Used here for: subcharts, global values and the dependency model.
- Andrew Block and Austin Dewey, *Managing Kubernetes Resources Using Helm, 2nd ed.* (Packt, 2022), ISBN 9781803242897. Used here for: umbrella chart structure and subchart value overrides.

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/16-umbrella.txt`. Observed on Helm 4.3.0 and minikube: release `platform` installed with the `post-install` migration Job hook and `/health` readiness; a shipment dispatched through shipping appeared in notification with the same `shipmentId`; `helm test platform` passed three test pods; with readiness `/healthz` the install timed out at 3 minutes and `--rollback-on-failure` uninstalled it; `tags.messaging=false` with `shipping.kafka.enabled=false` installed only shipping and Postgres; a `condition` that is set overrode a `tags` switch. The `import-values` default trap and the kind ordering were checked at template level only (the manifest lists Secret, ConfigMap, Service, Deployment, then Cluster and the Strimzi kinds).*
