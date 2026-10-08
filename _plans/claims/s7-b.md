---
title: "S7b results (chapters 13-21)"
render_with_liquid: false
---
# S7b results, 2026-10-08, Helm 4.3.0, minikube helm4dev

All `hfd-*` namespaces, releases, local registry containers, tunnels and the throwaway GPG key were removed afterwards. Operators and LGTM untouched.

| Claim | Chapter | Result | Evidence | Note |
|---|---|---|---|---|
| `--dry-run=client` accepts string `containerPort`, `--dry-run=server` rejects it | 13 | failed then fixed | 13-debugging.txt | Helm 4.3.0 `--dry-run=server` also accepts it (and negative replicas, unknown field, PSA-violating Pod). It does reject an unknown kind (`resource mapping not found`). `kubectl apply --server-side --dry-run=server` rejects the string (`expected numeric`). Demo and chapter rewritten |
| `helm diff upgrade` shows both changes | 13 | verified | 13-debugging.txt | `replicaCount` and `LOG_LEVEL` |
| `helm get manifest` passes kubeconform; same resources as `helm template` | 13 | verified | 13-debugging.txt | Differs only by two trailing blank lines |
| `Pending termination: 1` and `context deadline exceeded` | 13 | verified | 13-debugging.txt | Bad-tag upgrade with `--wait --timeout 60s` |
| `helm test` prints `Phase: Succeeded` | 14 | verified | 14-chart-testing.txt | |
| Unanchored `tests/` gives `TEST SUITE: None` on an installed release | 14 | verified | 14-chart-testing.txt | Upgrade to trap copy printed `TEST SUITE: None` |
| `ct install` installs with `ci/ci-values.yaml`, tests, cleans namespace | 14 | verified | 14-chart-testing.txt | Used `ct.yaml` in the example dir; namespace deleted |
| `charts-ci.yml` on GitHub Actions; `ct-install` job | 14 | not verified | | No remote; left to the CI step |
| `ct` finds `chart_schema.yaml` through `ct.yaml` | 14 | verified | 14-chart-testing.txt | `ct lint --config ct.yaml` passed in the demo |
| Kafka, KafkaNodePool, KafkaTopic Ready on `kafka.strimzi.io/v1` | 15 | verified | 15-kafka-notification.txt | Strimzi 1.2.0; Kafka shows `WARNINGS True` (single broker, ephemeral storage) |
| Without `entityOperator.topicOperator` the KafkaTopic is not reconciled | 15 | verified | 15-kafka-notification.txt | READY empty, no `status` |
| Three releases install in order; dispatch reaches `/api/notifications` | 15 | verified | 15-kafka-notification.txt | Cross-service notification captured: `shipmentId` 1, `orderId` 1501, topic `shipment.dispatched`, offset 0; consumer log "shipment 1 for order 1501 dispatched" |
| shipping restarts about 3 times while Kafka starts | 15 | verified with qualification | 15-kafka-notification.txt | 3 restarts when installed concurrently with Kafka; 0 in the demo because `kubectl wait` precedes it. Chapter updated |
| Wrong bootstrap: notification Live, not Ready | 15 | verified | 15-kafka-notification.txt | New pod Running 0/1, old pod kept serving, upgrade `context deadline exceeded` |
| Fullnames, log line, `helm test` for both | 15 | verified | 15-kafka-notification.txt | |
| `platform` installs with post-install hook and `/health` readiness | 16 | verified | 16-umbrella.txt | Hooks: migrate Job post-install,post-upgrade plus test pods; 3 shipping restarts during Kafka start |
| `/healthz` readiness waits then `--rollback-on-failure` uninstalls | 16 | verified | 16-umbrella.txt | 3 min; message `Available: 0/1` / `context deadline exceeded`; namespace emptied |
| `tags.messaging=false` + `shipping.kafka.enabled=false` installs without Kafka and notification | 16 | verified | 16-umbrella.txt | Only shipping and Postgres pods |
| Subchart default beats imported `kafka.bootstrap` | 16 | verified | 16-umbrella.txt | Offline step in the demo (`stale:9092`) |
| `condition` wins over `tags` | 16 | verified | 16-umbrella.txt | Scratch chart, db with both: `db.enabled=true` rendered Cluster despite tag false, `false` removed it |
| Helm sorts by kind, unknown kinds last | 16 | partial | 16-umbrella.txt | `get manifest` order Secret, ConfigMap, Service, Deployment, Cluster, Kafka...; application order not traced |
| `helm test platform` passes | 16 | verified | 16-umbrella.txt | Three test pods |
| Library and copied charts render identically; 224 to 16, 295 to 87 | 17 | verified | 17-library-chart.txt | |
| `platform` installs from library charts with `patterncatalyst.io/*` | 17 | verified | 17-library-chart.txt | |
| `helm create --starter` behavior; `<CHARTNAME>` only in README | 18 | verified | 18-starters.txt | One file listed by the demo; chapter lists README. Starter files carry the placeholder as designed |
| Generated chart installs; `helm test` passes | 18 | verified | 18-starters.txt | |
| Packaging claims (no `--dependency-update`, version flags, digest, `--devel`, `1.0`/`v1.0.2`, `pull -d`, `/tests/`) | 19 | verified | 19-packaging-repos.txt | |
| Install from `hfd-local` Ready; metadata 1.0.0/0.1.0; NodePort answers | 19 | verified | 19-packaging-repos.txt | |
| OCI push, digests, auth, dependency, plain-http claims | 20 | verified | 20-oci.txt | Manifest digest in this run `sha256:d3392d33...` (chapter no longer quotes the old value) |
| Registry addon via `tunnel.sh start registry` | 20 | verified | 20-oci.txt | Push to 127.0.0.1:5000 gave the same digest; template and install by digest from it Ready |
| Install by digest into `hfd-20` | 20 | verified | 20-oci.txt | From 5001 and from the addon registry |
| Tag re-push moves the tag, digest install unaffected | 20 | verified | 20-oci.txt | Tag showed 9.9.9, digest 0.1.0 |
| Signing, verify, tamper, `.prov` layer, cosign claims | 21 | verified | 21-signing.txt | |
| `upgrade --install --verify` of signed chart Ready | 21 | verified | 21-signing.txt | `/api/info` answered |
| Content cache lets a byte-identical unsigned chart pass `--verify` | 21 | reproduced (kept, sharpened) | 21-signing.txt | Cache keyed by chart digest holds the `.prov`. Warm cache: `pull --verify` fails, `install --verify` passes (real install deployed). Empty `HELM_CACHE_HOME`: install fails `failed to fetch provenance`. Different-bytes unsigned chart fails with warm cache. Chapter now states the precise behavior; demo has a `cache_caveat` step |
| Keyless signing | 21 | not run | | Described only |

## Fixes

- `examples/13-debugging/demo.sh` and `_docs/13`: server dry-run claim replaced with observed behavior; README and footer updated.
- `examples/15, 16/demo.sh`: curl retry flags after a fresh tunnel.
- `examples/19, 20, 21/demo.sh`: `clean` now deletes the namespace.
- `examples/21-signing/demo.sh`: new `cache_caveat` step; ch21 prose and troubleshooting updated.
- Chapters 15 (restart wording, topicOperator), 16 (message note), 20 (digest example) edited. Footers and READMEs promoted to verified for 13, 15-21; 14 partially verified (GitHub Actions not run).

## Notes

- `_docs/28-appendix-helm3-to-helm4.md` line 69 and `_docs/06-templates.md` describe `--dry-run=server` as a server-side check; they remain accurate for `lookup` and kind resolution, but readers should not expect schema validation on 4.3.0.
- Golden notes from S6.4 (starter `tests.image` default, README `helm create` line) still open; not touched.
- Cluster: no `hfd-*` namespaces, no example releases, ports free, no registry containers, no tunnels.
