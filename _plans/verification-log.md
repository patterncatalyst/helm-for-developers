---
render_with_liquid: false
---

# Verification log

Per-chapter verification-status footers moved here from the chapter bodies. The
reader-facing chapters now carry a `## Build, run, observe` section (the example's
real commands) instead; the run records stay here. Detailed evidence is in
`_plans/evidence/<name>.txt`, referenced per entry. The `plans` collection is
`output: false`, so this file is not published. Each entry is the footer text as
it last stood (verbatim summary; full transcripts in the evidence files).

## 00-outline.md
Had a `## Verification status` section describing the (now removed) book-wide footer convention: "A chapter is marked verified only after its example has run against a live cluster and the observed effect is recorded as evidence in the repository." Removed; the convention no longer applies (see CLAUDE.md).

## 01-prerequisites.md
verified on 2026-10-08, evidence `01-lab-setup.txt`, `01-lab-setup-fresh.txt`, `01-lab-setup-nodeports.txt`. `./demo.sh offline` preflight passes; `cluster-status.sh` healthy; global Helm still v3.18.3; service image Python 3.14.8. From-scratch rebuild: setup-profile.sh (43s), bootstrap.sh (235s), build-images.sh (11s), all exit 0. r1.1 published-NodePorts re-run: profile recreated with nine HFD_NODE_PORTS bound to 127.0.0.1; registry+Grafana answer on loopback; guard refuses 0.0.0.0-bound profile.

## 02-helm-4-tour.md
verified on 2026-10-08, evidence `02-helm-tour.txt`. Install reached deployed with two ready pods; release Secret present then gone after uninstall; `podcli check http` 200 in-pod; `helm get manifest` matched the live Deployment (2 replicas, podinfo:6.15.0).

## 03-shipping-service-raw-manifests.md
verified on 2026-10-08, evidence `03-raw-manifests.txt`. Manifests rolled out one ready pod; `/api/info` storage: memory; non-root securityContext + read-only root fs; a changed image tag created a second ReplicaSet while the old kept serving.

## 04-first-chart.md
verified on 2026-10-08, evidence `04-first-chart.txt`. `helm history` revisions 1/2/3 (3 = Rollback to 1); one release Secret per revision; `--keep-history` left an uninstalled release; Deployment owned by field manager helm; history cap held at 10.

## 05-values-and-overrides.md
verified on 2026-10-08, evidence `05-values.txt`. prod upgrade gave 3 replicas; `helm get values --all` showed merged values; `--reset-then-reuse-values` kept overrides and took a new chart default, `--reuse-values` did not; `--set` family and schema checks held. The bare-upgrade value-reuse rule follows the Helm 4.3.0 code path (not separately run).

## 06-templates.md
verified on 2026-10-08, evidence `06-templates.txt`. `tpl` annotation reached the pod with the install namespace; `required` fired only with schema validation skipped; `lookup` empty under template/dry-run=client, live object under dry-run=server (ch08 chart).

## 07-helpers-and-notes.md
verified on 2026-10-08, evidence `07-helpers-notes.txt`. `helm get notes` printed notes; Service had one endpoint; resources carried recommended labels; a 54-char release name rejected; a chart version bump rolled the pods.

## 08-config-and-secrets.md
verified on 2026-10-08, evidence `08-config-secrets.txt`, `08-config-secrets-sops.txt`. Writes 401 without token / 201 with; a ConfigMap change replaced pods; `auth.generate=true` kept the token across upgrade; `existingSecret` rendered no Secret and authenticated; `helm get values` printed the token. helm-secrets 4.7.9 + SOPS 3.13.3 + age 1.3.2 decrypted via `secrets://` and `helm secrets template`; wrong age key failed.

## 09-dependencies-postgres.md
verified on 2026-10-08, evidence `09-postgres-subchart.txt`. `--wait` succeeded with the CNPG Cluster; pod authenticated with the generated app Secret; manual migration + POST stored a row; import-values names matched the live Service/Secret; `helm lint` failed without `--set postgres.host`; `helm template` rendered the packaged copy until `helm dependency build` rerun.

## 10-crds-and-operators.md
verified on 2026-10-08, evidence `10-crds-operators.txt`. `helm upgrade` left the CRD unchanged; `kubectl apply` updated it without conflict (added kubectl-client-side-apply to managedFields); `helm uninstall` kept the CRD and sample object; the lint guard passed on a cluster with the CNPG operator.

## 11-hooks-and-migrations.md
verified on 2026-10-08, evidence `11-hooks-migrations.txt`, `-deadlock.txt`, `-preinstall.txt`. post-install migration succeeded under `--wait`; Job deleted on success and schema_migrations held versions 1 and 2; the warm hook ran after the migration; `deadlock` failed with context deadline exceeded and no Job; `preinstall` failed with secret not found.

## 12-release-lifecycle.md
verified on 2026-10-08, evidence `12-release-lifecycle.txt`. Steps 1-11 end to end: `--rollback-on-failure` left a failed revision then a Rollback-to-2 revision; `--cleanup-on-fail` removed only the new ConfigMap; field-manager conflict, ownership refusal and adoption (with `--force-conflicts`) captured; `--force-replace` worked only with `--server-side=false`. (demo.sh step 6 head-under-pipefail exit-141 fixed to sed -n.)

## 13-debugging-charts.md
verified on 2026-10-08, evidence `13-debugging.txt`. `helm diff upgrade` showed the replicaCount/LOG_LEVEL changes; `helm get manifest` passed kubeconform and matched `helm template`; a bad-tag `--wait` upgrade printed Pending termination + context deadline exceeded; a bad containerPort string passed both Helm dry-runs but failed `kubectl apply --server-side --dry-run=server`.

## 14-chart-testing.md
verified on 2026-10-08, evidence `14-chart-testing.txt`, `-ci.txt`. ct 3.15.0: `helm test` Phase Succeeded; an unanchored tests/ printed TEST SUITE: None; `ct install` installed with ci-values.yaml and deleted its namespace. GitHub Actions lint-test passed on PR and main; manual ct-install passed on kind.

## 15-kafka-and-notification.md
verified on 2026-10-08, evidence `15-kafka-notification.txt`. Strimzi 1.2.0: Kafka/KafkaNodePool/KafkaTopic Ready on v1; dispatched shipmentId 1 appeared in /api/notifications and the consumer log; `helm test` passed both services; a wrong bootstrap left notification 0/1 Ready; shipping restarted 3x when installed concurrently with Kafka, 0x after it.

## 16-umbrella-charts.md
verified on 2026-10-08, evidence `16-umbrella.txt`. Release platform installed with the post-install migration hook and /health readiness; a shipment reached notification with the same shipmentId; `helm test platform` passed three pods; `/healthz` readiness timed out and `--rollback-on-failure` uninstalled; tags/condition switches behaved as described.

## 17-library-charts.md
verified on 2026-10-08, evidence `17-library-chart.txt`. Library-based and copied charts rendered identically apart from the chart label/checksum (line counts 224->16, 295->87); release platform installed from the library charts with the ownership labels; `helm test platform` passed.

## 18-starters-golden-paths.md
verified on 2026-10-08, evidence `18-starters.txt`. `helm create --starter pc-fastapi` found the starter, rewrote Chart.yaml without dependencies and copied pc-lib-dependency.yaml; failed to render until the dependency was appended; the scaffolded chart installed and its `helm test` pod Succeeded.

## 19-packaging-and-repos.md
verified on 2026-10-08, evidence `19-packaging-repos.txt`, `19-published-repo.txt`. Against the live Pages URL: `helm repo add`/`search`/`pull`/`template` served six charts at 1.0.0 (15 objects). `helm package` without `--dependency-update` failed on missing pc-lib; version/app-version flags changed the filename and image tag; index digest equalled the archive sha256; `--devel` gated the rc; install from the local repo reached Ready.

## 20-oci-registries.md
verified on 2026-10-08, evidence `20-oci.txt`. push without `--plain-http` failed HTTP-to-HTTPS; pull by tag and digest worked; chart-layer digest equalled the archive sha256, manifest digest differed; same archive to three registries gave one manifest digest; authenticated push failed before `helm registry login`; `helm dependency update --plain-http` pulled pc-lib; install by digest Ready; a retagged 1.0.0 returned appVersion 9.9.9 while the digest stayed 0.1.0.

## 21-provenance-and-signing.md
verified on 2026-10-08, evidence `21-signing.txt`. cosign 3.1.3: default-keyring signing failed, legacy keyring signed and `helm verify` passed; a tampered archive failed sha256; the .prov uploaded as its own layer; `helm pull/upgrade --verify` passed signed and failed unsigned; cosign signed/verified by digest and reported no signatures for a moved tag. Keyless not run.

## 22-plugins.md
verified on 2026-10-08, evidence `22-plugins.txt`. `helm shipping-env` matched the `--chart` form and `kubectl get deploy -o yaml`; Helm exported HELM_BIN/HELM_NAMESPACE/HELM_PLUGIN_DIR; `ignoreFlags: true` passed no args; `maxPages: 16` failed with the quoted error; plugin.wasm rebuilt from an empty GOPATH.

## 23-post-renderers.md
verified on 2026-10-08, evidence `23-post-renderers.txt`. `--post-renderer kustomize-postrender` annotated Deployment/Service/ConfigMap/Secret and the pod template; selector.matchLabels unchanged; `helm get manifest` carried the label (install+upgrade); two `--post-renderer-args` arrived as $1/$2; a missing-annotations Deployment failed the install.

## 24-environment-promotion.md
verified on 2026-10-08, evidence `24-environments.txt`. Helmfile 1.8.1: offline dev/stage/prod passed; `helmfile -l env=dev sync` installed platform with rollbackOnFailure and `helm test` passed; a pinned digest was pulled; version: ignored on a local path, enforced for oci://. stage/prod rendered offline only.

## 25-gitops-argocd.md
verified on 2026-10-08, evidence `25-gitops-argocd.txt`, `-git.txt`, `-helmrepo.txt`. Argo CD chart 10.10.1: the OCI Application reached Synced/Healthy once the repo Secret used insecureOCIForceHttp; PostSync migration ran; ARGO-Post at /api/info; self-heal reverted a scaled Deployment. The Git-sourced Application (tag r1.0) reached Synced/Healthy; a valuesObject change reached /api/info. The Helm-repo-sourced umbrella reached Synced/Healthy, ran the migration, delivered a Kafka notification, took a valuesObject change, and reverted drift. The Git-sourced umbrella failed with a pc-lib.fullname error and was not made to work.

## 26-observability-lgtm.md
verified on 2026-10-08, evidence `26-observability.txt`. Grafana chart 8.5.0: dashboard hidden until searchNamespace=ALL; a dispatch trace held spans from platform-shipping and platform-notification; the HTTP-duration metric exists in Mimir without a service_name label (panel uses job); Loki has service_name. Release platform stays installed in hfd-26 as the reference state.

## 27-appendix-openshift-local.md
verified on OpenShift Local 2.64.0 (OpenShift 4.22.14), Helm 4.3.0, 2026-10-08, both profiles, community Strimzi 1.2.0 and Streams for Apache Kafka 3.2.1-14, evidence `27-openshift-crc.txt`, `-streams.txt`, `-console.txt`. restricted-v2 SCC + arbitrary UIDs, edge-TLS Routes, internal-registry push, OperatorHub installs, `helm test`, and the end-to-end shipment/dispatch/Kafka-notification flow. The Developer console Helm view: repo resources accepted and `helm` lists the six charts from the published index, but the console's own catalog listing needs a browser login and was not opened. (This content was also the chapter's top blockquote, removed with the footer.)

## 28-appendix-helm3-to-helm4.md
unverified. Flag names and defaults read from Helm 4.3.0 `--help`. Claims about `--force-replace` deprecation warnings, cross-client release compatibility, and Helm 3 plugins that edit release state were not run.

## 29-appendix-cheat-sheet.md
unverified. Flag spellings from Helm 4.3.0 `--help`. Examples were not each executed.

## 30-appendix-further-reading.md
unverified. The identifiers, titles, editions, publication years and author lists match the O'Reilly learning platform catalog entries for all nine books, checked 2026-10-08.
