---
title: "S5 live-run gotchas"
render_with_liquid: false
---
# Live-run gotchas (S5, 2026-10-08, Helm 4.3.0 on minikube helm4dev)

Evidence: `_plans/evidence/golden-*.txt`. Umbrella installed as release `platform` in namespace `hfd-26`.

- **Hooks vs `--wait` deadlock:** post-install hooks run only after `--wait` sees all resources ready. A readiness probe that depends on the hook (shipping `/healthz` needs migrated tables) deadlocks until timeout, then `--rollback-on-failure` uninstalls. Umbrella fix: `shipping.probes.readiness.path: /health`. Teach in ch11/ch16 as a trap.
- **Failed install output:** "context deadline exceeded" after the full timeout; with `--rollback-on-failure` the release is uninstalled; earlier events stay in the namespace.
- **`.helmignore` trap:** unanchored `tests/` also ignores `templates/tests/`; `helm test` then prints `TEST SUITE: None`. Use `/tests/`. Good ch14 teaching point.
- **Test pod image:** ubi-minimal+curl fails `runAsNonRoot` (no numeric USER). Test pods use the app image and a python urllib probe; subchart `tests.image` default `""` means own image.
- **Strimzi startup race:** shipping restarts ~3 times while Kafka comes up (aiokafka producer created in lifespan); converges within ~50s; startup probe + `--wait` absorb it. Mention, don't hide.
- **API:** `orderId` is an integer; dispatch payload `{orderId, shipmentId, address, status, occurredAt}`; dev token `dev-token`, writes need `Authorization: Bearer dev-token`.
- **Failed upgrade (bad tag):** old ReplicaSet keeps serving; new pod ImagePullBackOff then Terminating; Helm says "Pending termination: 1", not an image-pull error. Tell readers to `kubectl describe pod`.
- **OTel:** `global.otlpEndpoint` in values-dev turns OTel on. Tempo chart 1.10.0 serves HTTP on 3100 (datasource fixed). TraceQL attr `span.http.target`; filter on `dispatch` to skip `/healthz` noise. One trace contains spans from `platform-shipping` and `platform-notification`.
- **Migration hook Job** is deleted on success (`hook-succeeded`); prove completion with events and `shipping.schema_migrations`.
- **Timestamps:** helm prints local EDT, services log UTC.
