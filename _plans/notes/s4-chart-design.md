---
title: "S4 chart design notes"
render_with_liquid: false
---
# Golden chart design notes (S4, 2026-10-08)

Notes the chapter executors (S6) and the live run (S5) depend on.

- **Fullname rule:** `<release>-<chartname>` unless the release name contains the chart name. Standalone `helm install shipping charts/shipping-service` gives Service `shipping-shipping-service`. Umbrella release `platform` gives `platform-shipping`, `platform-notification`.
- **Umbrella hook phases:** umbrella sets `shipping.migration.hooks: post-install,post-upgrade` because the CNPG Cluster and its `-app` Secret are in the same release; a pre-install hook would not find them. Standalone shipping-service keeps `pre-install,pre-upgrade`. Teach this in ch11/ch16.
- **import-values trap:** cannot override a key the subchart defaults in its own values.yaml. So `postgres.host`, `postgres.existingSecret`, `kafka.bootstrap` have no defaults in app charts. Kafka chart's topic value is `kafkaTopic` to avoid a collision. Exports are static and must match `cluster.name` / `clusterName`.
- **Tags:** `tags.messaging` controls kafka + notification (tags only, no condition). With `tags.messaging=false` also set `shipping.kafka.enabled=false` (see `ci/ci-values.yaml`).
- **Schemas:** app charts use `additionalProperties: false`; `pc-lib`, `global`, `enabled` allowed explicitly.
- **Test image:** `ubi10/ubi-minimal:latest` with curl, override via `tests.image`.
- **Strimzi:** default `kafka.strimzi.io/v1` (`strimzi.apiVersion`, enum v1|v1beta2). node-pools/kraft annotations only emitted for v1beta2.
- **Starter:** `helm create --starter` rewrites Chart.yaml, so pc-lib dependency ships as `pc-lib-dependency.yaml` to append.
- **Helm 4.3 facts confirmed:** `--rollback-on-failure` (implies `--wait=watcher`); `--wait` = watcher|hookOnly|legacy, default hookOnly; `install --server-side` bool default true; `upgrade --server-side` true|false|auto default auto; `--force-replace`, `--force-conflicts`, `--take-ownership`; `--post-renderer NAME` + `--post-renderer-args`. `helm plugin install` verifies by default; git URL installs need `--verify=false`; local-dir installs are dev installs. plugin.yaml: `apiVersion: v1`, `type` cli/v1|getter/v1|postrenderer/v1, `runtime` subprocess|extism/v1, `runtimeConfig.platformCommand`. cli/v1 `ignoreFlags: true` passes no args. Extism: module `plugin.wasm`, export `helm_plugin_main`, return JSON `{}`, `maxPages` 256.
- **Fresh checkout:** run `helm dependency build` (dependency .tgz ignored).
