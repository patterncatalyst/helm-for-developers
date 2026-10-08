---
title: "Reconciliation plan"
layout: plan
render_with_liquid: false
---

# Reconciliation plan

Tracks every claim the tutorial makes about behavior that a real run must confirm. A claim starts as `unverified` and moves to `verified` only with an evidence file under `_plans/evidence/` that records what changed and what was observed. Per-part claims are authored in `_plans/claims/partN.md` and merged here during the live verification sweep.

## Runtime decisions

| Decision | Choice | Reason | Date |
|---|---|---|---|
| Python base | UBI 10 minimal with uv-installed CPython 3.15.0 | No UBI Python 3.15 image exists | 2026-10-08 |
| Fallbacks | F1: `PYTHON_VERSION=3.14`; F2: `ubi9/python-314` | Used only if 3.15 wheels or builds are unavailable; record here when applied | 2026-10-08 |

## Claims

One row per claim in `_plans/claims/s6-*.md`, merged with the S7 results in `_plans/claims/s7-a.md`, `s7-b.md` and `s7-c.md` (Helm 4.3.0, minikube `helm4dev`, 2026-10-08). Statuses: verified, partial, not verified, failed (none left open), refuted-and-fixed (the first live run disagreed and the chapter, demo or script was corrected). Chapter 27 was verified on CRC in the final phase (`_plans/claims/s7-d.md`).

| Claim | Chapter | Status | Evidence | Note |
|---|---|---|---|---|
| `examples/01-lab-setup/demo.sh` full run exits 0 from a deleted `helm4dev` profile and ends with `cluster-status.sh` reporting healthy | 01 | not verified | `_plans/evidence/01-lab-setup.txt` | Not re-bootstrapped by instruction. Preflight (`offline`) passes and `cluster-status.sh` reports "platform healthy" on the live profile |
| Global `~/.local/bin/helm` still reports v3.18.3 after the full run (isolation holds in both directions) | 01 | verified | `_plans/evidence/01-lab-setup.txt` | Run with a clean env |
| `helm env` shows all four `HELM_*` locations under the repository | 01 | verified | `_plans/evidence/01-lab-setup.txt` |  |
| `helm plugin list` shows diff 3.15.15 and unittest 1.2.1, type cli/v1, provenance unknown | 01 | verified | `_plans/evidence/01-lab-setup.txt` | Also shows an APIVERSION column value `legacy` |
| `helm plugin install` defaults to `--verify=true` against `$GNUPGHOME/pubring.kbx` | 01 | verified | `_plans/evidence/01-lab-setup.txt` | Help text; also seen in 08 (install refused without `--verify=false`) |
| The service images build on CPython 3.14.8 (fallback F1) | 01 | verified | `_plans/evidence/01-lab-setup.txt` | `python --version` in the image |
| `oci://ghcr.io/stefanprodan/charts/podinfo` version 6.15.0 exists, anonymous pull works, renders Service, Deployment (named `podinfo` for release `po… | 02 | verified | `_plans/evidence/02-helm-tour.txt` | Pull + install in the live run |
| Full run: install reaches `deployed` with 2 ready pods; `helm list`, `helm status`, `helm get values` (two overridden keys only) output as described | 02 | verified | `_plans/evidence/02-helm-tour.txt` |  |
| Release record is Secret `sh.helm.release.v1.podinfo.v1` with label `owner=helm` | 02 | verified | `_plans/evidence/02-helm-tour.txt` |  |
| `podcli check http localhost:9898/healthz` exists in the podinfo 6.15.0 image and succeeds via `kubectl exec deploy/podinfo` | 02 | verified | `_plans/evidence/02-helm-tour.txt` | status 200 |
| `helm uninstall --wait` removes the release Secret; `helm list` is then empty | 02 | verified | `_plans/evidence/02-helm-tour.txt` |  |
| `helm get manifest` vs live Deployment agree on replicas 2 and image `ghcr.io/stefanprodan/podinfo:6.15.0` (cross-check) | 02 | verified | `_plans/evidence/02-helm-tour.txt` |  |
| Helm 4 table rows (renamed flags, SSA, watcher, plugins, registry login, digest install, multi-doc values, content cache, chart v3, slog) match the H… | 02 | not verified |  | Web re-read not done in this sweep |
| Helm 3 support dates (bug fixes to July 8th 2026, security to November 11th 2026) | 02 | not verified |  | Web re-read not done in this sweep |
| The three raw manifests apply and roll out one ready pod; `/api/info` reports `storage: memory` | 03 | verified | `_plans/evidence/03-raw-manifests.txt` |  |
| Pod is admitted with the non-root securityContext (no `runAsUser`) and readOnlyRootFilesystem plus `/tmp` emptyDir runs | 03 | verified | `_plans/evidence/03-raw-manifests.txt` |  |
| Re-applying a changed image tag creates a second ReplicaSet (rolling update) | 03 | verified | `_plans/evidence/03-raw-manifests.txt` | Tag 0.1.1 does not exist; new pod ImagePullBackOff, old RS kept serving, `rollout undo` restored |
| `helm upgrade --install` of the 0.4.0 chart creates Deployment, Service and ConfigMap named `shipping-shipping-service` | 04 | verified | `_plans/evidence/04-first-chart.txt` |  |
| Upgrade then `helm rollback shipping 1` yields history revisions 1, 2, 3 (3 = rollback to 1) | 04 | verified | `_plans/evidence/04-first-chart.txt` |  |
| One Secret `sh.helm.release.v1.shipping.vN` of type `helm.sh/release.v1` per revision, label `owner=helm` | 04 | verified | `_plans/evidence/04-first-chart.txt` |  |
| `helm uninstall --keep-history` leaves an `uninstalled` release visible with `helm list --uninstalled` | 04 | verified | `_plans/evidence/04-first-chart.txt` | Plain `helm list` also showed it on 4.3.0; chapter updated |
| `helm upgrade --install` sets `--wait` strategy as documented; install is server-side apply by default and upgrade `auto` follows the previous method | 04 | verified | `_plans/evidence/04-first-chart.txt` |  |
| Default revision cap is 10 (`--history-max`) | 04 | verified | `_plans/evidence/04-first-chart.txt` | 12 upgrades left 10 revisions and 10 Secrets |
| `helm create` in Helm 4.3.0 generates deployment, service, serviceaccount, hpa, ingress, httproute, `_helpers.tpl`, NOTES, test pod | 04 | verified | `_plans/evidence/04-first-chart.txt` |  |
| Layered `-f values-dev.yaml -f values-prod.yaml` upgrade yields 3 replicas and `helm get values --all` shows merged values | 05 | verified | `_plans/evidence/05-values.txt` |  |
| `--reset-then-reuse-values` keeps earlier overrides and applies new chart defaults | 05 | verified | `_plans/evidence/05-values.txt` | replicas 3, LOG_LEVEL ERROR |
| `--reuse-values` does not pick up new chart defaults | 05 | verified | `_plans/evidence/05-values.txt` | Scratch chart copy with an added default |
| Schema with `$schema` draft 2020-12 is accepted by Helm 4.3.0 (observed once with `helm lint` on a scratch chart) | 05 | verified | `_plans/evidence/05-values.txt` | Only with the `/draft/` URI; the shortened URI 404s (added to chapter) |
| `--set image.tag=12345` fails the schema, `--set-string` works; `--set-literal` keeps commas; `--set-file` keeps trailing newline (observed offline) | 05 | verified | `_plans/evidence/05-values.txt` |  |
| `tpl` annotation renders with the install namespace and appears on the running pod | 06 | verified | `_plans/evidence/06-templates.txt` |  |
| `lookup` returns an empty map under `helm template` and `--dry-run=client` and the live object under `--dry-run=server` | 06 | verified | `_plans/evidence/08-config-secrets.txt` | Generated token compared |
| `required` fires only when schema validation is skipped (schema minLength fires first) | 06 | verified | `_plans/evidence/06-templates.txt` |  |
| `helm get notes shipping` prints the NOTES and every resource carries recommended labels; Service has one endpoint | 07 | verified | `_plans/evidence/07-helpers-notes.txt` |  |
| Release names over 53 chars are rejected; `fullname` contains-rule keeps `shipping` when `nameOverride=ship` (observed offline) | 07 | verified | `_plans/evidence/07-helpers-notes.txt` |  |
| Bumping chart `version` changes the pod template (chart label) and rolls pods | 07 | verified | `_plans/evidence/07-helpers-notes.txt` | New RS, chart label 0.7.1 |
| Writes return 401 without the token and succeed with `Bearer dev-token` (token from `values-dev.yaml`) | 08 | verified | `_plans/evidence/08-config-secrets.txt` |  |
| A ConfigMap change (`config.defaultCarrier=Globex`) replaces pods through `checksum/config` | 08 | verified | `_plans/evidence/08-config-secrets.txt` |  |
| With only `auth.generate=true`, the stored token is identical after a second upgrade (lookup preserves it) | 08 | verified | `_plans/evidence/08-config-secrets.txt` | Fresh install with generate only (the demo's own check reuses the dev token) |
| `auth.existingSecret` renders no Secret and the Deployment references the named Secret and key | 08 | verified | `_plans/evidence/08-config-secrets.txt` | 201 with external value, 401 with dev-token |
| `helm get values` prints `auth.token` (values are stored in the release record) | 08 | verified | `_plans/evidence/08-config-secrets.txt` |  |
| helm-secrets: README states Helm 3.9+ and does not mention Helm 4; compatibility not verified | 08 | partial | `_plans/evidence/08-config-secrets.txt` | Installs with `--verify=false` (4.8.0-dev, getter/v1); decryption not tested (no sops/age). Chapter updated |
| `helm install` of shipping-service with the shipping-postgres subchart under `--wait --timeout 5m` succeeds (CNPG Cluster counts as ready, app pod st… | 09 | verified | `_plans/evidence/09-postgres-subchart.txt` |  |
| The app pod reads PG_PASSWORD from the generated `shipping-postgres-app` Secret and connects | 09 | verified | `_plans/evidence/09-postgres-subchart.txt` |  |
| `import-values` supplies `postgres.host` and `postgres.existingSecret` (verified offline by template; live check that names match the CNPG-created Se… | 09 | verified | `_plans/evidence/09-postgres-subchart.txt` |  |
| `helm lint` does not resolve import-values (observed offline: `at '/postgres': missing property 'host'`) | 09 | verified | `_plans/evidence/09-postgres-subchart.txt` |  |
| `helm template` renders the packaged copy in `charts/`, not the edited subchart directory | 09 | verified | `_plans/evidence/09-postgres-subchart.txt` | Source restored and rebuilt afterwards |
| `helm upgrade` leaves the ShippingRoute CRD unchanged when `crds/` changes | 10 | verified | `_plans/evidence/10-crds-operators.txt` |  |
| `kubectl apply -f shippingroute-v2.crd.yaml` updates a CRD that Helm created without a conflict; managedFields gains `kubectl-client-side-apply` | 10 | verified | `_plans/evidence/10-crds-operators.txt` | Managers: helm (Apply), kube-apiserver, kubectl-client-side-apply. kubectl prints a last-applied-annotation warning (added to chapter) |
| `helm uninstall` keeps the CRD and the sample `ShippingRoute` object | 10 | verified | `_plans/evidence/10-crds-operators.txt` |  |
| `helm lint` reports `level=INFO msg="funcMap fail"` and 0 failures for the operator guard when the API is not declared (observed offline) | 10 | verified | `_plans/evidence/10-crds-operators.txt` |  |
| On a cluster with the CNPG operator, the guard passes without `--api-versions` (Capabilities discovery lists `postgresql.cnpg.io/v1`) | 10 | verified | `_plans/evidence/10-crds-operators.txt` | `--dry-run=server` rendered the Cluster |
| A post-install migration hook succeeds under `--wait` when readiness uses `/health` | 11 | verified | `_plans/evidence/11-hooks-migrations.txt` | Job retried once: first pod got ConnectionRefused (Postgres not accepting yet), backoff started a second. Chapter updated |
| The migration Job is deleted after success (`hook-succeeded`) | 11 | verified | `_plans/evidence/11-hooks-migrations.txt` |  |
| `./demo.sh deadlock` (readiness `/healthz` + post-install hook + `--wait --timeout 90s`) fails with `context deadline exceeded` and no migration Job… | 11 | verified | `_plans/evidence/11-hooks-migrations-deadlock.txt` | Real text added to chapter. Release stays `failed` (no rollback flag) |
| `./demo.sh preinstall` leaves the pre-install hook Job pod unable to start (missing `shipping-postgres-app` Secret) and Helm times out after 90s | 11 | verified | `_plans/evidence/11-hooks-migrations-preinstall.txt` | Needed a demo fix (see below). Event: `secret "shipping-postgres-app" not found` |
| With `warm.enabled=true`, the post-upgrade warm Job runs after the migration Job (weight 10 after 0) | 11 | verified | `_plans/evidence/11-hooks-migrations.txt` |  |
| `--wait` alone selects `watcher`, no flag is `hookOnly`, `--rollback-on-failure` implies watcher (from `helm upgrade --help` 4.3.0; docs-sourced) | 11, 12 | verified | (help text) | `helm upgrade --help` 4.3.0 |
| Step 3: a bad image tag with `--wait --timeout 60s --rollback-on-failure` fails, history shows a `failed` revision then a `deployed` rollback revision | 12 | verified | `_plans/evidence/12-release-lifecycle.txt` | Standalone text now in chapter |
| Step 4: `--cleanup-on-fail` deletes only the ConfigMap created by the failing upgrade and leaves the revision `failed` | 12 | verified | `_plans/evidence/12-release-lifecycle.txt` |  |
| Step 5: `helm rollback shipping 2` creates a new revision described `Rollback to 2` | 12 | verified | `_plans/evidence/12-release-lifecycle.txt` |  |
| Step 7: release Secret decodes with two `base64 -d` calls then `gunzip` into JSON with `info.status`, `version`, `chart.metadata` | 12 | verified | `_plans/evidence/12-release-lifecycle.txt` | Output: `deployed 6 shipping-service 0.12.0` |
| Step 8: after `kubectl patch --field-manager=hfd-demo` on `spec.replicas`, a plain `helm upgrade` stops on a field-manager conflict and `--force-conf… | 12 | verified | `_plans/evidence/12-release-lifecycle.txt` | Real text in chapter |
| Step 9: upgrade refuses to adopt an unmanaged ConfigMap; `--take-ownership` adopts it and adds Helm annotations | 12 | refuted-and-fixed | `_plans/evidence/12-release-lifecycle.txt` | `--take-ownership` alone hits an SSA conflict with `kubectl-create`; adoption needs `--force-conflicts` too. Demo and chapter corrected. Repair round: only the two `meta.helm.sh` annotations are evidenced after adoption; the `managed-by` label, `data.purpose` replacement and `managedFields` are marked as not captured in ch12 |
| Step 10: `--force-replace` succeeds on the release | 12 | refuted-and-fixed | `_plans/evidence/12-release-lifecycle.txt` | Rejected with SSA ("cannot use server-side apply and force replace together"); works with `--server-side=false`. ConfigMap UID unchanged, so it is replacement not delete-and-recreate. Chapter corrected |
| Release Secrets are named `sh.helm.release.v1.<release>.v<N>` with labels `owner=helm`, `name`, `status`, `version` | 12 | verified | `_plans/evidence/12-release-lifecycle.txt` | Plus `modifiedAt` |
| Upgrades and rollbacks follow the previous revision's apply method (server-side for new releases) per the Helm 4 overview | 12 | verified | `_plans/evidence/12-release-lifecycle.txt` | `APPLY_METHOD` and managedFields |
| `helm upgrade --dry-run=client` accepts a chart whose Deployment has `containerPort: "8080"` (string) and `--dry-run=server` rejects it | 13 | refuted-and-fixed | `_plans/evidence/13-debugging.txt` | Helm 4.3.0 `--dry-run=server` also accepts it (and negative replicas, unknown field, PSA-violating Pod). It does reject an unknown kind (`resource mapping not found`). `kubectl apply --server-side --dry-run=server` rejects the string (`expected numeric`). Demo and chapter rewritten |
| `helm diff upgrade shipping charts/shipping-service -n hfd-13 --set replicaCount=2 --set config.logLevel=DEBUG` shows both changes against the live r… | 13 | verified | `_plans/evidence/13-debugging.txt` | `replicaCount` and `LOG_LEVEL` |
| `helm get manifest shipping -n hfd-13` passes kubeconform with the datree CRDs-catalog, and lists the same resources as `helm template shipping chart… | 13 | verified | `_plans/evidence/13-debugging.txt` | Differs only by two trailing blank lines |
| "Pending termination: 1" and "context deadline exceeded" rows in the common-errors table (from s5 gotchas) | 13 | verified | `_plans/evidence/13-debugging.txt` | Bad-tag upgrade with `--wait --timeout 60s` |
| `helm test shipping -n hfd-14` prints `Phase: Succeeded` for `shipping-shipping-service-test-connection` | 14 | verified | `_plans/evidence/14-chart-testing.txt` |  |
| With unanchored `tests/` in `.helmignore`, an installed release prints `TEST SUITE: None` on `helm test` (offline half observed: `could not find temp… | 14 | verified | `_plans/evidence/14-chart-testing.txt` | Upgrade to trap copy printed `TEST SUITE: None` |
| `ct install --charts charts/shipping-service --helm-extra-args '--timeout 3m'` installs with `ci/ci-values.yaml`, runs the test pod and cleans up its… | 14 | verified | `_plans/evidence/14-chart-testing.txt` | Used `ct.yaml` in the example dir; namespace deleted |
| `.github/workflows/charts-ci.yml` `lint-test` job passes on GitHub Actions (tool cache, `scripts/install-tools.sh`, all steps, every example `offline… | 14 | not verified |  | No remote; left to the CI step |
| `ct-install` job (manual dispatch, kind, image built with docker and loaded) passes | 14 | not verified |  | No remote; left to the CI step |
| `ct` finds `chart_schema.yaml` through `ct.yaml` in the current directory; with `HOME` unset and no `ct.yaml` it stops with "neither specified nor fo… | 14 | verified | `_plans/evidence/14-chart-testing.txt` | `ct lint --config ct.yaml` passed in the demo |
| Strimzi 1.2.0 serves `kafka.strimzi.io/v1`; the chart's Kafka, KafkaNodePool and KafkaTopic reconcile to Ready | 15 | verified | `_plans/evidence/15-kafka-notification.txt` | Strimzi 1.2.0; Kafka shows `WARNINGS True` (single broker, ephemeral storage) |
| Without `entityOperator.topicOperator` the KafkaTopic is not reconciled | 15 | verified | `_plans/evidence/15-kafka-notification.txt` | READY empty, no `status` |
| Three separate releases install in order (kafka, notification, shipping) and dispatch reaches `/api/notifications` | 15 | verified | `_plans/evidence/15-kafka-notification.txt` | Cross-service notification captured: `shipmentId` 1, `orderId` 1501, topic `shipment.dispatched`, offset 0; consumer log "shipment 1 for order 1501 dispatched" |
| shipping restarts a few times (about 3, settling in about 50 s in the umbrella run) while Kafka starts when installed as a separate release | 15 | verified | `_plans/evidence/15-kafka-notification.txt` | 3 restarts when installed concurrently with Kafka; 0 in the demo because `kubectl wait` precedes it. Chapter updated (S7 row: s7-b; result "verified with qualification") |
| notification pod stays Live but not Ready with a wrong bootstrap address | 15 | verified | `_plans/evidence/15-kafka-notification.txt` | New pod Running 0/1, old pod kept serving, upgrade `context deadline exceeded` |
| Fullnames in ch15 are `notification-notification-service` and `shipping-shipping-service` | 15 | verified | `_plans/evidence/15-kafka-notification.txt` |  |
| `kubectl logs deploy/notification-notification-service` shows the dispatched log line | 15 | verified | `_plans/evidence/15-kafka-notification.txt` |  |
| `helm test shipping` and `helm test notification` pass in hfd-15 | 15 | verified | `_plans/evidence/15-kafka-notification.txt` |  |
| Release `platform` installs from the ch16 (pre-library) charts with post-install hook and `/health` readiness | 16 | verified | `_plans/evidence/16-umbrella.txt` | Hooks: migrate Job post-install,post-upgrade plus test pods; 3 shipping restarts during Kafka start |
| With readiness `/healthz` the install waits until the timeout and `--rollback-on-failure` uninstalls (quoted message from the golden run in hfd-26) | 16 | verified | `_plans/evidence/16-umbrella.txt` | 3 min; message `Available: 0/1` / `context deadline exceeded`; namespace emptied |
| `tags.messaging=false` + `shipping.kafka.enabled=false` installs without Kafka and notification | 16 | verified | `_plans/evidence/16-umbrella.txt` | Only shipping and Postgres pods |
| A subchart default for `kafka.bootstrap` beats the imported value (offline, template-level) | 16 | verified | `_plans/evidence/16-umbrella.txt` | Offline step in the demo (`stale:9092`) |
| `condition` wins over `tags` when both are set | 16 | verified | `_plans/evidence/16-umbrella.txt` | Scratch chart, db with both: `db.enabled=true` rendered Cluster despite tag false, `false` removed it |
| Helm sorts resources by kind (unknown kinds last) in a release under Helm 4 SSA | 16 | partial | `_plans/evidence/16-umbrella.txt` | `get manifest` order Secret, ConfigMap, Service, Deployment, Cluster, Kafka...; application order not traced |
| `helm test platform` passes in hfd-16 | 16 | verified | `_plans/evidence/16-umbrella.txt` | Three test pods |
| Library-based and copied charts render identical manifests except `helm.sh/chart` and `checksum/config` | 17 | verified | `_plans/evidence/17-library-chart.txt` |  |
| Line counts 224 to 16 (notification) and 295 to 87 (shipping) | 17 | verified | `_plans/evidence/17-library-chart.txt` |  |
| Release `platform` installs from library charts; Deployments and Services carry `patterncatalyst.io/*` | 17 | verified | `_plans/evidence/17-library-chart.txt` |  |
| `helm create --starter pc-fastapi` (by name, from `$HELM_DATA_HOME/starters`) rewrites Chart.yaml (no dependencies) and copies `pc-lib-dependency.yam… | 18 | verified | `_plans/evidence/18-starters.txt` | S7 reports these claims as a group. One file listed by the demo; chapter lists README. Starter files carry the placeholder as designed |
| `<CHARTNAME>` remains only in the generated README.md | 18 | verified | `_plans/evidence/18-starters.txt` | S7 reports these claims as a group. One file listed by the demo; chapter lists README. Starter files carry the placeholder as designed |
| The generated chart installs and its `helm test` passes with `image.repository=shipping-service` | 18 | verified | `_plans/evidence/18-starters.txt` | S7 reports these claims as a group. One file listed by the demo; chapter lists README. Starter files carry the placeholder as designed |
| `helm package` without `--dependency-update` fails on a fresh checkout | 19 | verified | `_plans/evidence/19-packaging-repos.txt` | S7 reports these claims as a group. |
| `--version`/`--app-version` change file name, index and default image tag | 19 | verified | `_plans/evidence/19-packaging-repos.txt` | S7 reports these claims as a group. |
| Index digest equals `sha256sum` of the `.tgz` | 19 | verified | `_plans/evidence/19-packaging-repos.txt` | S7 reports these claims as a group. |
| `helm search repo` hides `1.1.0-rc.1` until `--devel` | 19 | verified | `_plans/evidence/19-packaging-repos.txt` | S7 reports these claims as a group. |
| Helm accepts `--version 1.0` and `v1.0.2` | 19 | verified | `_plans/evidence/19-packaging-repos.txt` | S7 reports these claims as a group. |
| `helm pull -d <missing dir>` fails | 19 | verified | `_plans/evidence/19-packaging-repos.txt` | S7 reports these claims as a group. |
| `.helmignore` `/tests/` keeps `templates/tests/` and drops `tests/` | 19 | verified | `_plans/evidence/19-packaging-repos.txt` | S7 reports these claims as a group. |
| Install from `hfd-local/shipping-service --version 1.0.0` reaches Ready in `hfd-19`; `helm get metadata` shows 1.0.0/0.1.0; NodePort 30080 answers `/… | 19 | verified | `_plans/evidence/19-packaging-repos.txt` | S7 reports these claims as a group. |
| `helm push` without `--plain-http` to an HTTP registry fails with "server gave HTTP response to HTTPS client" | 20 | verified | `_plans/evidence/20-oci.txt` | S7 reports these claims as a group. Manifest digest in this run `sha256:d3392d33...` (chapter no longer quotes the old value) |
| Push creates `charts/shipping-service:1.0.0`; chart layer digest = sha256 of `.tgz`; manifest digest differs | 20 | verified | `_plans/evidence/20-oci.txt` | S7 reports these claims as a group. Manifest digest in this run `sha256:d3392d33...` (chapter no longer quotes the old value) |
| `oci://host/path/chart@sha256:<manifest digest>` works on pull, template, install `--dry-run=client` | 20 | verified | `_plans/evidence/20-oci.txt` | S7 reports these claims as a group. From 5001 and from the addon registry |
| Same archive pushed to two registries has the same manifest digest | 20 | verified | `_plans/evidence/20-oci.txt` | S7 reports these claims as a group. Manifest digest in this run `sha256:d3392d33...` (chapter no longer quotes the old value) |
| Auth registry: push before login fails `basic credential not found`; `helm registry login --password-stdin --plain-http` succeeds | 20 | verified | `_plans/evidence/20-oci.txt` | S7 reports these claims as a group. Manifest digest in this run `sha256:d3392d33...` (chapter no longer quotes the old value) |
| `helm dependency update --skip-refresh --plain-http` pulls `pc-lib` from `oci://127.0.0.1:5001/charts` | 20 | verified | `_plans/evidence/20-oci.txt` | S7 reports these claims as a group. Manifest digest in this run `sha256:d3392d33...` (chapter no longer quotes the old value) |
| minikube registry addon reachable at 127.0.0.1:5000 via `scripts/tunnel.sh start registry`; `helm push ... --plain-http` works | 20 | verified | `_plans/evidence/20-oci.txt` | S7 reports these claims as a group. Push to 127.0.0.1:5000 gave the same digest; template and install by digest from it Ready |
| `docker create`+`cp`+`start` is needed for the htpasswd file (bind mount from scratch dir denied) | 20 | verified | `_plans/evidence/20-oci.txt` | S7 reports these claims as a group. Manifest digest in this run `sha256:d3392d33...` (chapter no longer quotes the old value) |
| `helm package --sign` with default `pubring.kbx` fails "provided key is not a private key" | 21 | verified | `_plans/evidence/21-signing.txt` | S7 reports these claims as a group. |
| Legacy `gpg --export-secret-keys > secring.gpg` + `--keyring` signs; `.prov` written | 21 | verified | `_plans/evidence/21-signing.txt` | S7 reports these claims as a group. |
| `helm verify` works with default `pubring.kbx` (public keys only) | 21 | verified | `_plans/evidence/21-signing.txt` | S7 reports these claims as a group. |
| Tampered archive fails `sha256 sum does not match` | 21 | verified | `_plans/evidence/21-signing.txt` | S7 reports these claims as a group. |
| `helm push` of a signed chart uploads `.prov` as layer `application/vnd.cncf.helm.chart.provenance.v1.prov` | 21 | verified | `_plans/evidence/21-signing.txt` | S7 reports these claims as a group. |
| `helm pull --verify` / `install --verify` pass for signed OCI chart, fail `failed to fetch provenance` for unsigned (fresh cache) | 21 | verified | `_plans/evidence/21-signing.txt` | S7 reports these claims as a group. Cache keyed by chart digest holds the `.prov`. Warm cache: `pull --verify` fails, `install --verify --dry-run=client` reaches `STATUS: pending-install` (a client dry run, not a deployed install). Empty `HELM_CACHE_HOME`: install fails `failed to fetch provenance`. Different-bytes unsigned chart fails with warm cache. Chapter… |
| Content cache lets a byte-identical unsigned chart pass `--verify` | 21 | verified | `_plans/evidence/21-signing.txt` | S7 reports these claims as a group. Cache keyed by chart digest holds the `.prov`. Warm cache: `pull --verify` fails, `install --verify --dry-run=client` reaches `STATUS: pending-install` (a client dry run, not a deployed install). Empty `HELM_CACHE_HOME`: install fails `failed to fetch provenance`. Different-bytes unsigned chart fails with warm cache. Chapter… |
| `cosign sign --key ... --allow-http-registry --use-signing-config=false --tlog-upload=false` by digest and `cosign verify --insecure-ignore-tlog` suc… | 21 | verified | `_plans/evidence/21-signing.txt` | S7 reports these claims as a group. |
| After pushing tampered chart to tag 1.0.0, `cosign verify :1.0.0` -> `no signatures found`; original digest still verifies | 21 | verified | `_plans/evidence/21-signing.txt` | S7 reports these claims as a group. |
| `helm upgrade --install ... --verify` of the signed OCI chart reaches Ready in `hfd-21` | 21 | verified | `_plans/evidence/21-signing.txt` | S7 reports these claims as a group. `/api/info` answered |
| Keyless signing | 21 | not verified |  | S7 reports these claims as a group. Described only (S7 row: s7-b; result "not run") |
| `helm shipping-env RELEASE -n NS` reads `helm get manifest` of a deployed release and prints the same env list as the `--chart` form | 22 | verified | `_plans/evidence/22-plugins.txt` | Installed chart in `hfd-22`; diff identical; matches `kubectl get deploy -o yaml` |
| `plugin.wasm` builds on a clean Go module cache (`make -C examples/22-plugins/plugins/wasm-hello`) | 22 | verified | `_plans/evidence/22-plugins.txt` | Empty GOPATH, downloads `go-pdk v1.1.3`, Go 1.26.8 |
| `maxPages: 16` fails with `min 42 pages (2 Mi) over limit of 16 pages (1 Mi)` | 22 | verified | `_plans/evidence/22-plugins.txt` | Real text has an `Error: failed to create existing plugin:` prefix; chapter updated |
| `ignoreFlags: true` leaves `extraArgs` empty for the Wasm plugin | 22 | verified | `_plans/evidence/22-plugins.txt` | `Hello, world!` |
| Tarball install without `.prov` fails with `no provenance file (.prov) found`; `--verify=false` installs and lists provenance `unsigned` | 22 | verified | `_plans/evidence/22-plugins.txt` | In the demo |
| Directory installs show provenance `local dev` only when `HELM_DATA_HOME` is set to the dir holding the install | 22 | partial | `_plans/evidence/22-plugins.txt` | The Wasm plugin (symlinked dir) shows `local dev`; shipping-env shows `unknown` in the demo. Chapter already prints exactly this |
| Helm exports `HELM_BIN`, `HELM_NAMESPACE`, `HELM_PLUGIN_DIR` to subprocess plugins | 22 | verified | `_plans/evidence/22-plugins.txt` | `HELM_BIN=helm` (not an absolute path); also `HELM_PLUGIN_NAME` |
| `ignoreFlags: false` passes args after the plugin name; `true` passes none | 22 | verified | `_plans/evidence/22-plugins.txt` | `true`: usage message, exit 2 |
| `helm install --post-renderer kustomize-postrender` applies the labelled objects and the label is visible on live objects and in the stored release m… | 23 | verified | `_plans/evidence/23-post-renderers.txt` | Deployment, Service, ConfigMap, Secret; install and upgrade manifests |
| Figure 23.1 note: install and upgrade store the post-rendered manifest | 23 | verified | `_plans/evidence/23-post-renderers.txt` | Deployment, Service, ConfigMap, Secret; install and upgrade manifests |
| `includeSelectors: false` keeps `spec.selector.matchLabels` unchanged | 23 | verified | `_plans/evidence/23-post-renderers.txt` | Live `matchLabels` unchanged |
| Two `--post-renderer-args` arrive as `$1` and `$2` | 23 | verified | `_plans/evidence/23-post-renderers.txt` | Throwaway plugin |
| `postrender.sh` exits 1 with `add operation does not apply: doc is missing path` on a Deployment without pod-template annotations | 23 | verified | `_plans/evidence/23-post-renderers.txt` | Demo |
| A path to an executable and an unknown name both fail with `plugin: {Name:... Type:postrenderer/v1} not found` | 23 | verified | `_plans/evidence/23-post-renderers.txt` | Demo |
| `helmfile -l env=dev sync --skip-deps` installs release `platform` in `hfd-24-dev` under Helm 4 with `rollbackOnFailure` | 24 | verified | `_plans/evidence/24-environments.txt` | Revision 1 deployed, `helm test` three Succeeded |
| `./demo.sh pin stage` pushes images, reads a digest, and a pod pulling `localhost:5000/shipping-service:0.1.0@sha256:...` starts | 24 | refuted-and-fixed | `_plans/evidence/24-environments.txt` | `docker push` from Docker Desktop (VM) cannot reach the host tunnel (`dial tcp [::1]:5000: i/o timeout`). With `BUILD_ENGINE=podman` the pin was written and the pod ran `localhost:5000/shipping-service:0.1.0@sha256:...`. Chapter and README now say so |
| Helmfile ignores `version:` for local-path charts (changing it to 1.0.1 renders the same chart) | 24 | verified | `_plans/evidence/24-environments.txt` | 1.0.1 renders byte-identical |
| Helmfile enforces `version:` for an `oci://` chart (chapter shows the form, example does not run it) | 24 | verified | `_plans/evidence/24-environments.txt` | 9.9.9 fails with `FetchReference ... not found`; needs a plain-HTTP shim because Helmfile 1.8.1 does not pass `--plain-http` to `helm pull`. Chapter updated |
| Dev NodePorts 30080/30081 clash with any other live release (hfd-26 `platform`, ch25 workload) | 24, 25 | verified | `_plans/evidence/24-environments.txt` | Dev Services use them; each example was cleaned before the next |
| Argo CD chart 10.10.1 installs with `--wait --rollback-on-failure` under Helm 4 and its CRDs apply (large Application CRD, SSA) | 25 | verified | `_plans/evidence/25-gitops-argocd.txt` | Twice |
| Chart default nodePortHttp 30080 collides with shipping; 30082 avoids it; UI on 127.0.0.1:8443 via `scripts/tunnel.sh argocd` | 25 | verified | `_plans/evidence/25-gitops-argocd.txt` |  |
| Repo Secret with `enableOCI` + `insecureOciForceHttp` lets Argo CD pull `shipping-platform:1.0.0` from `registry.kube-system.svc.cluster.local:80/cha… | 25 | refuted-and-fixed | `_plans/evidence/25-gitops-argocd.txt` | Key is case-sensitive: `insecureOCIForceHttp`. With the old spelling repo-server pulled over HTTPS and the Application stayed `Unknown`. Fixed `apps/repo-registry.yaml` and chapter; rerun from scratch Synced/Healthy |
| `helm push ... oci://127.0.0.1:5000/charts --plain-http` works through the registry tunnel | 25 | verified | `_plans/evidence/25-gitops-argocd.txt` |  |
| Application reaches Synced and Healthy; `helm list -n hfd-25` is empty (no Helm release) | 25 | verified | `_plans/evidence/25-gitops-argocd.txt` |  |
| `valuesObject.shipping.config.defaultCarrier: ARGO-Post` is visible at `/api/info` | 25 | verified | `_plans/evidence/25-gitops-argocd.txt` |  |
| Migration hook (`post-install,post-upgrade`) runs as a PostSync hook and completes | 25 | verified | `_plans/evidence/25-gitops-argocd.txt` | `Job/platform-shipping-migrate PostSync Succeeded`; `schema_migrations` versions 1, 2 |
| `lookup` returns empty under Argo CD rendering (stated from design: no live API during render; not demonstrated, golden charts do not use lookup) | 25 | verified | `_plans/evidence/25-gitops-argocd.txt` | Probe chart: `yes` from `helm install`, `no` from Argo CD. Chapter updated |
| `apps/shipping-platform-git.yaml` syncs from GitHub incl. `file://` dependencies | 25 | not verified |  | Repository not pushed |
| Grafana chart 8.5.0 sidecar watches only its own namespace by default; ConfigMap in hfd-26 is not loaded until `searchNamespace=ALL` | 26 | verified | `_plans/evidence/26-observability.txt` | No `NAMESPACE` env, search `[]`; after upgrade `NAMESPACE=ALL` |
| `helm upgrade grafana grafana/grafana --version 8.5.0 --reuse-values --set sidecar.dashboards.searchNamespace=ALL` succeeds (grafana repo in project-… | 26 | verified | `_plans/evidence/26-observability.txt` |  |
| Dashboard "Shipping platform (platform)" appears in folder Shipping | 26 | verified | `_plans/evidence/26-observability.txt` |  |
| Metric `http_server_duration_milliseconds_count` exists in Mimir with label `service_name` | 26 | refuted-and-fixed | `_plans/evidence/26-observability.txt` | Metric exists; label is `job` (`shipping/platform-shipping`), no `service_name`. Dashboard panel changed in golden and example copies (identical); `helm unittest` 23 pass |
| Loki label `service_name` exists for platform-* logs | 26 | verified | `_plans/evidence/26-observability.txt` | Values `platform-notification`, `platform-shipping` |
| Dispatch trace holds spans from platform-shipping and platform-notification (re-run) | 26 | verified | `_plans/evidence/26-observability.txt` | Demo dispatch lacked the bearer token (401), so its trace was shipping-only, and it reused order 2601 on rerun. Demo now sends the token, uses a random order id, and asserts both services plus the Mimir query (S7 row: s7-c; result "verified, demo fixed") |
| Whole of ch27 and its example is untested on a live OpenShift cluster | 27 | verified | `_plans/evidence/27-openshift-crc.txt` | Both profiles on CRC 2.64.0 / OCP 4.22.14. Console Helm view and Streams operator not run |
| `restricted-v2` annotates every app pod (`openshift.io/scc`) and assigns a UID that is not 1001 | 27 | verified | `_plans/evidence/27-openshift-crc.txt` | All 5 pods incl. operator-managed carry restricted-v2; UID 1000650000, GID 0; chapter cross-check corrected (SCC injects runAsUser/fsGroup into the live pod) |
| `helm upgrade --install` with `-f values-openshift.yaml -f values-openshift-minimal.yaml` reaches Ready under `--wait --rollback-on-failure` on CRC | 27 | verified | `_plans/evidence/27-openshift-crc.txt` | Minimal passed; first run's Route check got 503 (router lag), `verify-crc.sh` now retries. Full profile installed in 57 s |
| Registry `defaultRoute` patch publishes `default-route-openshift-image-registry.apps-crc.testing`; `podman login -p $(oc whoami -t)` and push create… | 27 | verified | `_plans/evidence/27-openshift-crc.txt` | podman 5.8.7; both ImageStreams created with tag 0.1.0 |
| Route host `platform-shipping-hfd-ocp.apps-crc.testing` generated, `/api/info` returns 200 with `"environment":"openshift"`, HTTP redirects to HTTPS | 27 | verified | `_plans/evidence/27-openshift-crc.txt` | 200 with environment openshift, HTTP 302 to HTTPS |
| `helm test` passes with `tests.image` set to the registry path (umbrella test reads that key directly) | 27 | verified | `_plans/evidence/27-openshift-crc.txt` | Full (3 suites) and minimal (1 suite) both Succeeded |
| Full profile: CNPG and Strimzi/Streams for Apache Kafka from OperatorHub; Streams may require `kafka.strimzi.io/v1beta2` | 27 | partial | `_plans/evidence/27-openshift-crc.txt` | CNPG 1.30.1 (certified, stable-v1) and Strimzi 1.2.0 (community, strimzi-1.2.x) installed; CRD serves v1 only, v1beta2 rejected. Streams for Apache Kafka not installed. Uninstall needs KafkaTopic deleted first (demo.sh clean fixed) |
| `ProjectHelmChartRepository` (`helm.openshift.io/v1beta1`) lists a classic repo in the Developer console; OCI support in console depends on release | 27 | partial | `_plans/evidence/27-openshift-crc.txt` | CR accepted and listed by `oc get`; console view not opened; GitHub Pages index.yaml returns 404 (unpublished) |
| `oc set image-lookup shipping-service` enables short image references | 27 | verified | `_plans/evidence/27-openshift-crc.txt` | lookupPolicy local=true; short ref `shipping-service:0.1.0` resolved to the registry digest |
| Helm 3 era `--force` and `--atomic` still work with deprecation warnings in 4.3.0 | 28 | not verified |  | Not exercised by S7: no live check; read from `--help` and official pages only |
| Release compatibility: Helm 4 reads and upgrades Helm 3 releases; `auto` SSA keeps previous method | 28 | not verified |  | Not exercised by S7: no live check; read from `--help` and official pages only |
| `helm-mapkubeapis` works with Helm 4 | 28 | not verified |  | Not exercised by S7: no live check; read from `--help` and official pages only |
| Author lists of the nine books | 30 | not verified |  | Not exercised by S7: no live check; read from `--help` and official pages only |
| Cheat sheet examples execute as written | 29 | not verified |  | Not exercised by S7: no live check; read from `--help` and official pages only |

### S7 results without a matching S6 claim

| Claim | Chapter | Status | Evidence | Note |
|---|---|---|---|---|
| Generated chart installs; `helm test` passes | 18 | verified | `_plans/evidence/18-starters.txt` |  |
| Tag re-push moves the tag, digest install unaffected | 20 | verified | `_plans/evidence/20-oci.txt` | Tag showed 9.9.9, digest 0.1.0 |
| Missing-annotations Deployment fails | 23 | verified | `_plans/evidence/23-post-renderers.txt` | Helm shows only `plugin "kustomize-postrender" exited with error`; the script's stderr (`add operation does not apply...`) is visible only when run by hand. Chapter updated |
| Self-heal reverts drift (behavioral) | 25 | verified | `_plans/evidence/25-gitops-argocd.txt` | Scaled to 3, back to 1 within about 6 s |

## Status by chapter

Claim counts come from the merged table above; the footer column is the current verification footer in `_docs/`.

| Chapter | Claims | Claim statuses | Footer status | Footer evidence | Evidence file present |
|---|---|---|---|---|---|
| 00-outline | 0 | none | (no footer) | none | n/a |
| 01-prerequisites | 6 | 1 not verified, 5 verified | partially verified | 01-lab-setup.txt | yes |
| 02-helm-4-tour | 8 | 6 verified, 2 not verified | verified | 02-helm-tour.txt | yes |
| 03-shipping-service-raw-manifests | 3 | 3 verified | verified | 03-raw-manifests.txt | yes |
| 04-first-chart | 7 | 7 verified | verified | 04-first-chart.txt | yes |
| 05-values-and-overrides | 5 | 5 verified | verified | 05-values.txt | yes |
| 06-templates | 3 | 3 verified | verified | 06-templates.txt, 08-config-secrets.txt | yes |
| 07-helpers-and-notes | 3 | 3 verified | verified | 07-helpers-notes.txt | yes |
| 08-config-and-secrets | 6 | 5 verified, 1 partial | verified | 08-config-secrets.txt | yes |
| 09-dependencies-postgres | 5 | 5 verified | verified | 09-postgres-subchart.txt | yes |
| 10-crds-and-operators | 5 | 5 verified | verified | 10-crds-operators.txt | yes |
| 11-hooks-and-migrations | 5 | 5 verified | verified | 11-hooks-migrations-deadlock.txt, 11-hooks-migrations.txt | yes |
| 12-release-lifecycle | 9 | 7 verified, 2 refuted-and-fixed | verified | 12-release-lifecycle.txt | yes |
| 13-debugging-charts | 4 | 1 refuted-and-fixed, 3 verified | verified | 13-debugging.txt | yes |
| 14-chart-testing | 6 | 4 verified, 2 not verified | partially verified | 14-chart-testing.txt | yes |
| 15-kafka-and-notification | 8 | 8 verified | verified | 15-kafka-notification.txt | yes |
| 16-umbrella-charts | 7 | 6 verified, 1 partial | verified | 16-umbrella.txt | yes |
| 17-library-charts | 3 | 3 verified | verified | 17-library-chart.txt | yes |
| 18-starters-golden-paths | 3 | 3 verified | verified | 18-starters.txt | yes |
| 19-packaging-and-repos | 8 | 8 verified | verified | 19-packaging-repos.txt | yes |
| 20-oci-registries | 8 | 8 verified | verified | 20-oci.txt | yes |
| 21-provenance-and-signing | 11 | 10 verified, 1 not verified | verified | 21-signing.txt | yes |
| 22-plugins | 8 | 7 verified, 1 partial | verified | 22-plugins.txt | yes |
| 23-post-renderers | 6 | 6 verified | verified | 23-post-renderers.txt | yes |
| 24-environment-promotion | 4 | 3 verified, 1 refuted-and-fixed | verified | 24-environments.txt | yes |
| 25-gitops-argocd | 9 | 7 verified, 1 refuted-and-fixed, 1 not verified | verified | 25-gitops-argocd.txt | yes |
| 26-observability-lgtm | 6 | 5 verified, 1 refuted-and-fixed | verified | 26-observability.txt | yes |
| 27-appendix-openshift-local | 9 | 7 verified, 2 partial | verified | 27-openshift-crc.txt | yes |
| 28-appendix-helm3-to-helm4 | 3 | 3 not verified | unverified | none | n/a |
| 29-appendix-cheat-sheet | 1 | 1 not verified | unverified | none | n/a |
| 30-appendix-further-reading | 1 | 1 not verified | unverified | none | n/a |

### Footer check

No footer says verified without an evidence file. Every `verified` footer cites an existing `_plans/evidence/NN-*.txt` for its own chapter. Chapters 01 and 14 say partially verified, and 28 to 30 say unverified; 00 has no footer.

## Iteration log

| Iteration | Date | Note |
|---|---|---|
| r1.0 | 2026-10-08 | Scaffold created |
| r1.0 | 2026-10-08 | S7 live sweep merged into this plan; repair rounds 1 and 2 applied |

## Recorded deviations
| Date | Item | Decision | Reason |
|---|---|---|---|
| 2026-10-08 | Python base | F1: CPython 3.14.8 on UBI 10 ubi-minimal via uv | uv offered only 3.15.0rc3; aiokafka 0.14.0 has no cp315 wheel. Swap `ARG PYTHON_VERSION` when available. |
| 2026-10-08 | Arbitrary UID test | `--user 54321:0` instead of `123456:0` | Rootless podman maps 65536 ids; OpenShift-sized UID checked on CRC (ch27): uid 1000650000, gid 0, app works. |

## Repair round (validation-r1)

| Claim | Chapter | Status | Evidence | Note |
|---|---|---|---|---|
| ch05 `key "Post" has no value` and the unknown-key lint error | 05 | verified | `_plans/evidence/05-values.txt` | Captured in the repair round; chapter block now shows the observed unknown-key lint line only |
| ch13 `could not find schema for Cluster` without the CRDs-catalog | 13 | verified | `_plans/evidence/13-debugging.txt` | Captured in the repair round |
| ch27 read-only root filesystem | 27 | verified | `_plans/evidence/27-openshift-crc.txt` | Chapter now cites `readOnlyRootFilesystem: true` from the pod spec; the earlier `touch` output was not captured and was removed |
| ch27 SCC-filled securityContext | 27 | verified | `_plans/evidence/27-openshift-crc.txt` | Read-only `oc get` captured in the repair round |
| ch11 CNPG Cluster ready before PostgreSQL accepts connections | 11 | inference | `_plans/evidence/11-hooks-migrations.txt` | Evidence shows the ConnectionRefused log and the retry pod; the cause is labeled as inference in the chapter |
| ch11 and ch16 deadlock text | 11, 16 | verified | `_plans/evidence/golden-01-install-attempt1-deadlock.txt`, `_plans/evidence/16-umbrella.txt` | ch11 quotes the `hfd-26` run and says so; ch16 quotes its own `hfd-16` run |
