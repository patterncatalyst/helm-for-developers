---
title: "S7a results (chapters 01-12)"
render_with_liquid: false
---
# S7a results, 2026-10-08, Helm 4.3.0, minikube helm4dev

Setup: golden `platform` uninstalled and namespace `hfd-26` deleted first (`_plans/evidence/s7a-00-uninstall-golden.txt`). All `hfd-01..12` namespaces and the ShippingRoute CRD were removed afterwards; tunnels stopped.

| Claim | Chapter | Result | Evidence | Note |
|---|---|---|---|---|
| `demo.sh` full run from a deleted profile exits 0 and ends healthy | 01 | not verified | 01-lab-setup.txt | Not re-bootstrapped by instruction. Preflight (`offline`) passes and `cluster-status.sh` reports "platform healthy" on the live profile |
| Global `~/.local/bin/helm` still v3.18.3 | 01 | verified | 01-lab-setup.txt | Run with a clean env |
| `helm env` shows four `HELM_*` locations under the repo | 01 | verified | 01-lab-setup.txt | |
| `helm plugin list` diff 3.15.15, unittest 1.2.1, cli/v1, provenance unknown | 01 | verified | 01-lab-setup.txt | Also shows an APIVERSION column value `legacy` |
| `helm plugin install` defaults to `--verify=true` | 01 | verified | 01-lab-setup.txt | Help text; also seen in 08 (install refused without `--verify=false`) |
| Service images run CPython 3.14.8 | 01 | verified | 01-lab-setup.txt | `python --version` in the image |
| podinfo OCI 6.15.0 pulls anonymously and renders | 02 | verified | 02-helm-tour.txt | Pull + install in the live run |
| Install `deployed`, 2 ready pods, `list`/`status`/`get values` as described | 02 | verified | 02-helm-tour.txt | |
| Release Secret `sh.helm.release.v1.podinfo.v1`, `owner=helm` | 02 | verified | 02-helm-tour.txt | |
| `podcli check http` succeeds in-pod | 02 | verified | 02-helm-tour.txt | status 200 |
| `uninstall --wait` removes the Secret | 02 | verified | 02-helm-tour.txt | |
| `get manifest` vs live Deployment (2 replicas, image) | 02 | verified | 02-helm-tour.txt | |
| Helm 4 table rows match overview/release post; Helm 3 support dates | 02 | not verified | | Web re-read not done in this sweep |
| Raw manifests roll out one ready pod, `storage: memory` | 03 | verified | 03-raw-manifests.txt | |
| Non-root securityContext admitted, read-only root fs runs | 03 | verified | 03-raw-manifests.txt | |
| Changed image tag creates a second ReplicaSet | 03 | verified | 03-raw-manifests.txt | Tag 0.1.1 does not exist; new pod ImagePullBackOff, old RS kept serving, `rollout undo` restored |
| 0.4.0 chart creates Deployment/Service/ConfigMap `shipping-shipping-service` | 04 | verified | 04-first-chart.txt | |
| History 1,2,3 with 3 = rollback to 1 | 04 | verified | 04-first-chart.txt | |
| One Secret per revision, type `helm.sh/release.v1` | 04 | verified | 04-first-chart.txt | |
| `--keep-history` leaves an `uninstalled` release | 04 | verified | 04-first-chart.txt | Plain `helm list` also showed it on 4.3.0; chapter updated |
| SSA by default, field manager `helm` Apply | 04 | verified | 04-first-chart.txt | |
| Default history cap 10 | 04 | verified | 04-first-chart.txt | 12 upgrades left 10 revisions and 10 Secrets |
| `helm create` file list | 04 | verified | 04-first-chart.txt | |
| Layered `-f` gives 3 replicas, `get values --all` merged | 05 | verified | 05-values.txt | |
| `--reset-then-reuse-values` keeps overrides, takes new defaults | 05 | verified | 05-values.txt | replicas 3, LOG_LEVEL ERROR |
| `--reuse-values` does not take new defaults | 05 | verified | 05-values.txt | Scratch chart copy with an added default |
| Schema 2020-12 accepted | 05 | verified | 05-values.txt | Only with the `/draft/` URI; the shortened URI 404s (added to chapter) |
| `--set image.tag=12345` fails, `--set-string`, `--set-literal`, `--set-file` | 05 | verified | 05-values.txt | |
| `tpl` annotation on running pod | 06 | verified | 06-templates.txt | |
| `lookup` empty under template/dry-run=client, live under dry-run=server | 06 | verified | 08-config-secrets.txt | Generated token compared |
| `required` fires only with schema skipped | 06 | verified | 06-templates.txt | |
| `get notes`, recommended labels, one endpoint | 07 | verified | 07-helpers-notes.txt | |
| Release name >53 rejected; fullname contains-rule | 07 | verified | 07-helpers-notes.txt | |
| Chart version bump rolls pods | 07 | verified | 07-helpers-notes.txt | New RS, chart label 0.7.1 |
| 401 without token, 201 with `dev-token` | 08 | verified | 08-config-secrets.txt | |
| ConfigMap change replaces pods (checksum) | 08 | verified | 08-config-secrets.txt | |
| `auth.generate=true` token stable across upgrade | 08 | verified | 08-config-secrets.txt | Fresh install with generate only (the demo's own check reuses the dev token) |
| `existingSecret` renders no Secret, works | 08 | verified | 08-config-secrets.txt | 201 with external value, 401 with dev-token |
| `helm get values` prints `auth.token` | 08 | verified | 08-config-secrets.txt | |
| helm-secrets under Helm 4 | 08 | partial | 08-config-secrets.txt | Installs with `--verify=false` (4.8.0-dev, getter/v1); decryption not tested (no sops/age). Chapter updated |
| CNPG Cluster counts ready under `--wait`, app starts | 09 | verified | 09-postgres-subchart.txt | |
| App connects with generated Secret; POST returns row | 09 | verified | 09-postgres-subchart.txt | |
| `import-values` names match live Service and Secret | 09 | verified | 09-postgres-subchart.txt | |
| `helm lint` does not resolve import-values | 09 | verified | 09-postgres-subchart.txt | |
| Template uses packaged copy until rebuild | 09 | verified | 09-postgres-subchart.txt | Source restored and rebuilt afterwards |
| Upgrade leaves CRD unchanged | 10 | verified | 10-crds-operators.txt | |
| `kubectl apply` updates Helm-created CRD, no conflict; managedFields gains `kubectl-client-side-apply` | 10 | verified | 10-crds-operators.txt | Managers: helm (Apply), kube-apiserver, kubectl-client-side-apply. kubectl prints a last-applied-annotation warning (added to chapter) |
| Uninstall keeps CRD and sample object | 10 | verified | 10-crds-operators.txt | |
| Lint prints `funcMap fail` INFO, 0 failures | 10 | verified | 10-crds-operators.txt | |
| Guard passes on a cluster with CNPG without `--api-versions` | 10 | verified | 10-crds-operators.txt | `--dry-run=server` rendered the Cluster |
| Post-install migration succeeds under `--wait` with `/health` readiness | 11 | verified | 11-hooks-migrations.txt | Job retried once: first pod got ConnectionRefused (Postgres not accepting yet), backoff started a second. Chapter updated |
| Migration Job deleted after success; versions 1 and 2 | 11 | verified | 11-hooks-migrations.txt | |
| `deadlock` fails with `context deadline exceeded`, no Job | 11 | verified | 11-hooks-migrations-deadlock.txt | Real text added to chapter. Release stays `failed` (no rollback flag) |
| `preinstall` fails, pod cannot start for missing Secret | 11 | verified | 11-hooks-migrations-preinstall.txt | Needed a demo fix (see below). Event: `secret "shipping-postgres-app" not found` |
| Warm Job runs after migration Job | 11 | verified | 11-hooks-migrations.txt | |
| `--wait` strategies and `--rollback-on-failure` implies watcher | 11, 12 | verified | (help text) | `helm upgrade --help` 4.3.0 |
| Bad tag + `--rollback-on-failure`: failed revision then rollback revision | 12 | verified | 12-release-lifecycle.txt | Standalone text now in chapter |
| `--cleanup-on-fail` removes only new ConfigMap, revision `failed` | 12 | verified | 12-release-lifecycle.txt | |
| `helm rollback shipping 2` creates `Rollback to 2` revision | 12 | verified | 12-release-lifecycle.txt | |
| Release Secret decodes with two base64 and gunzip | 12 | verified | 12-release-lifecycle.txt | Output: `deployed 6 shipping-service 0.12.0` |
| Step 8 SSA conflict, `--force-conflicts` succeeds | 12 | verified | 12-release-lifecycle.txt | Real text in chapter |
| Step 9 refusal and `--take-ownership` adoption | 12 | failed then fixed | 12-release-lifecycle.txt | `--take-ownership` alone hits an SSA conflict with `kubectl-create`; adoption needs `--force-conflicts` too. Demo and chapter corrected |
| Step 10 `--force-replace` succeeds | 12 | failed then fixed | 12-release-lifecycle.txt | Rejected with SSA ("cannot use server-side apply and force replace together"); works with `--server-side=false`. ConfigMap UID unchanged, so it is replacement not delete-and-recreate. Chapter corrected |
| Secret labels `owner,name,status,version` | 12 | verified | 12-release-lifecycle.txt | Plus `modifiedAt` |
| Upgrades follow previous apply method; `helm` Apply manager | 12 | verified | 12-release-lifecycle.txt | `APPLY_METHOD` and managedFields |

## Fixes

- `examples/03..09/demo.sh`: first `curl` to `/api/info` after `tunnel.sh start` failed once (exit 56, race on a fresh NodePort); added `--retry 10 --retry-all-errors --retry-delay 1`. `examples/11-hooks-migrations/demo.sh` POST curl got the same flags.
- `examples/10-crds-operators/demo.sh`: `trap ... "$work"` referenced a `local` variable under `set -u` and exited 1 at the end (`work: unbound variable`). Made it non-local with `${work:-}`.
- `examples/11-hooks-migrations/demo.sh`: `--set migration.hooks=pre-install,pre-upgrade` failed to parse; now `--set-literal`.
- `examples/12-release-lifecycle/demo.sh`: step 9 adds `--take-ownership --force-conflicts` (alone shown to fail); step 10 shows the SSA rejection then `--server-side=false --force-replace` with a UID check; step 8 prints managedFields.
- Chapters: 04 (plain `helm list` shows uninstalled), 05 (2020-12 URI), 08 (helm-secrets), 10 (managedFields output), 11 (deadlock, preinstall, retry cause, events), 12 (steps 3 to 10 observed text, `--take-ownership`, `--force-replace`). Footers and README status updated for 01 (partial) and 02 to 12 (verified).

## Notes for later batches

- Cluster: operators and LGTM running, no `hfd-*` namespaces, no example releases, `platform` gone. Port 30080/30081 free. Rebuild the golden umbrella in `hfd-26` before any chapter that expects it.
- `examples/09` and `10` `shipping-service/charts/shipping-postgres-0.9.0.tgz` were rebuilt by `helm dependency build` (timestamp only).
- Always redirect demo output to a file rather than a pipe: `tunnel.sh start` leaves a background ssh that keeps a pipe open.
- Helm 4.3.0: `--take-ownership` does not bypass SSA field conflicts, `--force-replace` is incompatible with server-side apply, a Job hook pod may fail once with ConnectionRefused right after the CNPG Cluster reports ready.
