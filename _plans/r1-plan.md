---
title: "Release r1.0 plan"
layout: plan
render_with_liquid: false
---

# Plan: "Helm for Developers" tutorial (r1.0)

All of this comes from read-only investigation done on 2026-10-08. The coordinator's book constraint (books are cited only for concepts Helm 4 left unchanged, and Helm-4-changed behavior is sourced from official Helm docs) is built into the Chapter outline, the Steps and the Acceptance criteria.

## Environment facts (checked, not assumed)

**Tools on PATH**
- helm **v3.18.3** at `~/.local/bin/helm`. This is Helm 3. Latest stable upstream is **v4.3.0** (2026-09-09, from `gh release list -R helm/helm`).
- minikube v1.38.1.
- kubectl v1.32.13, which has kustomize v5.5.0 built in. There is no standalone `kustomize`.
- podman 5.8.7.
- docker 29.8.2 (real Docker).
- node v22.22.2, with `pptxgenjs@4.0.1` installed globally.
- gh 2.102.0, authenticated as **patterncatalyst**. Git identity is `PatternCatalyst <rsedor@patterncatalyst.io>`.
- go 1.26.8, gpg 2.4.9, skopeo.
- soffice and pdftoppm. 24 Red Hat font files are installed.
- ruby 4.0.7, bundler 4.0.20.
- python3 **3.14.7**, with pyyaml.

**Missing**
- python3.15, uv, crc, oc, kubeconform, ct, cosign, helmfile, kind.
- Python packages `python-docx` and `cairosvg`. `cairosvg` is needed by the deck PNG renderer, following the MEA `build_diagrams.py` pattern.

**Host and cluster**
- 62 GB RAM, 16 CPUs.
- One minikube profile exists: `datamesh` (docker driver, containerd, k8s v1.35.1), currently **Stopped**. The docker driver is therefore the one already proven on this host.

**Python 3.15**
- 3.15.0 GA has slipped to **2026-10-09**, tomorrow (rc3 came out 10-02).
- There is **no UBI Python 3.15 image**. `ubi9/python-314` exists. No `ubi10/python-*` image exists.
- Docker Hub has `python:3.15.0rc3-*` and `3.15-rc` tags.

**Other repos and tools**
- `~/Dev/helm-for-developers` does not exist, and neither does the GitHub repo `patterncatalyst/helm-for-developers`.
- Latest upstream versions: helm-unittest v1.2.1, chart-testing v3.15.0, kubeconform v0.8.0, helm-diff v3.15.15, cosign v3.1.3.
- The hub repo is clean on `main`.

## Approach

Build one fixed, feature-flagged Python 3.15 / FastAPI application, in final form, once:
- **shipping-service**: REST API, Postgres, Kafka producer.
- **notification-service**: Kafka consumer with a small HTTP surface.

Then build a validated **golden chart set** that represents the end state. Each chapter's `examples/NN-*/` directory is a **self-contained snapshot** of the charts at that step, stripped back from the golden set. The app image never changes between chapters; only the charts and values do. That keeps every chapter focused on Helm.

Platform pieces:
- Platform operators come from the lgtm-minikube-stack templates, scoped to CNPG, Strimzi and LGTM. Charts ship only the custom resources, never the operators.
- Helm **4.3.x** is installed **project-locally** under `.tools/` with isolated `HELM_*_HOME` directories, so the user's global Helm 3.18 keeps working for the other projects.
- Verification has two tiers. Offline checks are lint, template, unittest, kubeconform and ct lint. Live checks run on a dedicated minikube profile `helm4dev`.
- Content follows the lgtm-jekyll, lgtm-tutorial and lgtm-professional-voice conventions.
- Decks follow lgtm-presentation.
- Git follows lgtm-github on the branch `feature/r1-initial-build`.
- Any outward action (creating or pushing the GitHub repo, enabling Pages, a hub PR or push) is held for user confirmation.

**Rejected alternatives**
- **A single evolving chart with a git tag per chapter.** It breaks the "runnable example directory per chapter" rule.
- **Reusing the datamesh `charts/capstone` umbrella as-is.** It is a skeleton with hard-coded names, no helpers or labels conventions, and many dead toggles. It would teach anti-patterns, so only its patterns are reused.
- **Bitnami Postgres/Kafka subcharts.** Bitnami moved its catalog to legacy/paid images in 2025, and the house stack is operator-based (CNPG and Strimzi).
- **Replacing the global helm with Helm 4.** Sibling projects (datamesh, MEA) depend on Helm 3.18.
- **Flux as the primary GitOps tool.** Argo CD matches the OpenShift GitOps Application pattern already used in the sibling repos' `openshift/gitops/application.yaml`.
- **Istio, KEDA and Kiali.** They cost a lot of resources and are not Helm-specific; the flags stay `false`.
- **`docker.io/library/python:3.15-slim` as the base image.** It breaks the house UBI rule (lgtm-minikube-stack `references/base-images.md`).
- **Alembic for migrations.** It adds a heavy dependency. Versioned SQL plus a roughly 40-line runner is enough and makes the hook Job easy to read.

## Reuse map

| Source | What is reused | Lands at |
|---|---|---|
| `~/Dev/datamesh-reference-arch-python/examples/lgtm-datamesh/services/shipping-service/app/{config.py,db.py,main.py,models.py}`, `tests/test_health.py`, `Containerfile` (identical copy exists in `minikube-on-fedora/examples/17-capstone/...`) | pydantic-settings `Settings` with env-sourced `PG_*`; async SQLAlchemy/asyncpg engine; `/health` liveness vs `/healthz` readiness split; FastAPI lifespan (Managed Lifecycle); ASGITransport test; UBI multi-stage, `USER 1001:0` | `services/shipping-service/app/`, `services/*/tests/`, `services/Containerfile` |
| `~/Dev/modernizing-enterprise-applications/examples/06-shipping-service/src/main/java/dev/patterncatalyst/shipping/{Shipment,ShipmentDto,ShipmentDispatched,ShippingResource}.java` and `src/main/resources/db/migration/V1__create_shipments_table.sql`, `V3` (unique order_id), outbox SQL | Domain model: `Shipment(id BIGSERIAL, order_id BIGINT, address, status PENDING/DISPATCHED/CANCELLED, created_at)`; `/api/shipments/{id}`, `/api/shipments?orderId=`, 400 on missing orderId; `ShipmentDispatched{orderId, shipmentId, address, status, occurredAt}` wire contract; unique order_id idempotency | `services/shipping-service/app/{models.py,routes.py,events.py}`, `services/shipping-service/migrations/V1__shipments.sql`, `V2__unique_order_id.sql` |
| `~/Dev/observability-python-otel-lgtm/services/common/obs/{otel.py,kafka.py,kafka_propagation.py,logging.py}` and `services/Containerfile` (repo-root context, `ARG SERVICE`) | OTel SDK bootstrap over OTLP/HTTP 4318, W3C propagation, FastAPI auto-instrumentation, `OTEL_SDK_DISABLED` switch; aiokafka producer/consumer with trace context in headers; JSON logging; one parameterized Containerfile | `services/common/pcobs/` (renamed package), `services/Containerfile` |
| `.../lgtm-datamesh/charts/capstone/charts/postgres/templates/cluster.yaml` + values | CNPG `Cluster` CR with `inheritedMetadata` sidecar opt-out, `bootstrap.initdb` database/owner, `<cluster>-app` Secret keys `dbname/username/password`, 2Gi memory limit lesson | `charts/shipping-postgres/templates/cluster.yaml` |
| `.../lgtm-datamesh/charts/capstone/charts/kafka/templates/{kafka,nodepool,topic}.yaml` | Strimzi KRaft `Kafka` + `KafkaNodePool` (dual role, ephemeral) + `KafkaTopic` (API version must be re-verified for Strimzi 0.51; see Risks) | `charts/shipping-kafka/templates/` |
| `.../lgtm-datamesh/charts/capstone/charts/shipping-service/templates/deployment.yaml` + values | Probes block (startup 30×2s, liveness `/health`, readiness `/healthz`), secretKeyRef wiring to CNPG secret, `pullPolicy: Always` lesson for mutable tags | `charts/pc-lib/templates/_deployment.tpl` (generalized) |
| `.../lgtm-datamesh/openshift/helm/datamesh/templates/{_helpers.tpl,route.yaml,serviceaccount-infra.yaml}`, `openshift/gitops/application.yaml`, `openshift/README.md`; `~/Dev/modernizing-enterprise-applications/openshift/{README.md,helm/mea/}`, `_docs/33-appendix-openshift.md` | Route template (edge TLS, Redirect), "no runAsUser under restricted-v2" rule, internal registry push loop, CRC prerequisites prose (account, pull secret, `crc setup/start`), Argo CD `Application` with `helm.releaseName` | `charts/shipping-platform/templates/route.yaml` (gated by `Capabilities.APIVersions.Has "route.openshift.io/v1"`), `examples/27-openshift-crc/`, `examples/25-gitops-argocd/application-*.yaml`, `_docs/27-appendix-openshift-local.md` |
| `.../lgtm-datamesh/scripts/tunnel-services.sh` | NodePort + SSH tunnel (no port-forward) | `scripts/tunnel.sh` |
| `~/.claude/skills/lgtm-minikube-stack/templates/{setup-profile.sh,bootstrap.sh,setup-postgres-operator.sh,setup-kafka-operator.sh,setup-lgtm.sh,teardown.sh,cluster-status.sh}.template`, `grafana-datasources.yaml`, `grafana-dashboards/`, `snippets/otel-collector-config.yaml` | Platform bring-up, tiers gated on health | `scripts/platform/*.sh`, `platform/observability/` |
| `~/.claude/skills/lgtm-jekyll/assets/site-template/*`, `lgtm-tutorial/scripts/generate_diagram.py` | Site scaffold, layouts, CSS, diagram engine | repo root, `scripts/generate_diagram.py` |
| `~/Dev/modernizing-enterprise-applications/presentation/modernizing-101/` (layout, `package.json`, cairosvg `build_diagrams.py` variant) + `lgtm-presentation/scripts/*` | Deck directory shape and PNG rendering without `/mnt/skills` | `presentation/helm-101/`, `presentation/helm-201/` |
| `~/Dev/modernizing-enterprise-applications/.gitignore` | ignore set (plus `.tools/`, `dist/`, `.venv/`, `qa/`) | `.gitignore` |
| Data-mesh concept (`datamesh-reference-arch-python/_docs/01-concepts.md`) | Per-service schema ownership (`shipping` schema) and events as a published contract; the library chart emits `patterncatalyst.io/domain`, `/owner`, `/data-product` annotations | `charts/pc-lib/templates/_metadata.tpl`, chapters 09, 16, 17 |

## House decisions (record in `CONTRIBUTING.md` → "House style"; executors apply them verbatim)

**Project and site**
- Project dir: `~/Dev/helm-for-developers`.
- GitHub repo: `patterncatalyst/helm-for-developers`, **public**.
- `baseurl: "/helm-for-developers"`, `github_username: "patterncatalyst"`, `github_repo: "helm-for-developers"`.
- `brand_emoji: "⎈"` (falls back to "🧭" if the font lacks it).
- Accent color: default amber `#e8870c`.
- License: Apache-2.0.
- Hero eyebrow: "Helm 4 · Python 3.15 · FastAPI · minikube · OpenShift".

**Versions** (pinned and dated 2026-10-08; S0 re-verifies them)
- Helm 4.3.0
- helm-unittest 1.2.1
- helm-diff 3.15.15
- chart-testing 3.15.0
- kubeconform 0.8.0
- cosign 3.1.3
- helmfile: latest 1.x that supports Helm 4, optional
- Argo CD Helm chart: latest stable
- CNPG chart: the skill pins 0.23.0; re-verify
- Strimzi 0.51.0
- LGTM chart versions as in `setup-lgtm.sh`
- Python 3.15.0, FastAPI latest; Pydantic, uvicorn, asyncpg, aiokafka, OTel versions pinned in `pyproject.toml`

**Tool isolation.** `scripts/env.sh` is sourced by every script. It exports:
- `PATH=$REPO/.tools/bin:$PATH`
- `HELM_CONFIG_HOME`, `HELM_CACHE_HOME`, `HELM_DATA_HOME` under `$REPO/.tools/helm/`
- `HELM_PLUGINS=$REPO/.tools/helm/plugins`
- `GNUPGHOME=$REPO/.tools/gnupg`, for throwaway signing keys only
- `MINIKUBE_PROFILE=helm4dev`

It also fails if `helm version --short` is not `v4.*`.

**Cluster.**
- Profile `helm4dev`, `MINIKUBE_DRIVER=docker` by default (the driver already proven on this host), containerd runtime, 12g RAM, 8 CPUs.
- Flags: `ENABLE_ISTIO=false ENABLE_KEDA=false ENABLE_KIALI=false ENABLE_POSTGRES=true ENABLE_KAFKA=true ENABLE_LGTM=true`.
- **The bootstrap installs operators only.** The tiers that create the Postgres and Kafka cluster CRs are removed, because the charts own those CRs.
- Strimzi goes in namespace `strimzi` with `watchAnyNamespace=true`. CNPG goes in `cnpg-system`. Observability goes in `observability`.
- The registry addon is enabled.
- Each example installs into its own namespace `hfd-NN` with release name `shipping` (or `platform` for the umbrella), and `./demo.sh clean` uninstalls it.

**Host access.** NodePort plus `scripts/tunnel.sh`; no `kubectl port-forward`.
- shipping: 30080 → localhost 8080
- notification: 30081 → localhost 8081
- grafana: 30300 → localhost 3000
- argocd: 30443 → localhost 8443

**Images**
- `scripts/build-images.sh` builds `shipping-service:0.1.0` and `notification-service:0.1.0` straight into the profile (`minikube -p helm4dev image build` or `podman build` + `minikube image load`).
- `push` mode also pushes them to the registry addon as `localhost:5000/<name>:0.1.0`.
- Chart default: `image.repository: shipping-service`, tag defaults to `.Chart.AppVersion`, `pullPolicy: IfNotPresent`.

**Chart versions in snapshots.** Version `0.<chapter>.0` per chapter snapshot until chapter 19, which releases `1.0.0`. `appVersion: "0.1.0"` throughout.

**Command prefixes.** `[host]$` for the host, `[crc-host]$` for the CRC machine. Commands are single-line. Use `127.0.0.1` rather than `localhost` in prose for host URLs. Use fully qualified image refs.

**Banned vocabulary.** Per lgtm-tutorial and lgtm-professional-voice: honest/honestly, deceptive "lie" (person or process as subject), capstone, simply, seamless, leverage, load-bearing, delve. Also no Helm 2 terms in instructions: tiller, `helm init`, `requirements.yaml`, `helm serve`.

**Citation line format.** Must be one physical line, inside a `## Further reading` section at the end of each chapter (before the verification footer):
`- <Authors ≤60 chars, or "First Author et al.">, *<Title>* (<Publisher>, <Year>), ISBN <13-digit>. Used here for: <still-valid concepts>.`
- Do not put an em dash right before the title. The gen-books `AUTHOR_DASH_RE` would capture only the last author.
- Known extractor limitation: `is_plausible_title` rejects parentheses, so the CKAD title must be written as `*Certified Kubernetes Application Developer (CKAD) Study Guide*` and its hub entry is hand-curated.

**Helm-4-changed topics must cite official sources only, never books.** Sources: helm.sh/docs (Helm 4 overview and "changes since Helm 3" page), the Helm 4 release blog and notes on helm.sh/blog and the GitHub v4.0.0–v4.3.0 releases, and the HIPs in github.com/helm/community/tree/main/hips. Executors must find the exact URLs and confirm they resolve. Topics:
- `--atomic` → `--rollback-on-failure`
- `--force` → `--force-replace`
- server-side apply as the default for new releases (`--server-side`, field managers, `--force-conflicts`)
- `--wait` kstatus watcher semantics (`--wait=watcher|hookOnly|legacy`)
- the plugin system (types `cli/v1`, `getter/v1`, `postrenderer/v1`; subprocess and Wasm/extism runtimes; the plugin.yaml schema; plugin verification)
- post-renderers being plugins only
- OCI behavior (install by digest, `helm registry` changes)
- dry-run, lint and template flag changes
- `--take-ownership`
- slog-based logging and `--debug`
- removed or renamed flags
- chart API v3 status (still in progress; charts stay `apiVersion: v2`)

Executors confirm each one against `helm <cmd> --help` from `.tools/bin/helm` before writing it.

## Chapter outline

Every hands-on chapter gets `examples/NN-slug/{README.md, demo.sh, chart(s)/values}`. `demo.sh` supports these subcommands: (none) = full run, `offline` = lint/template/unittest/kubeconform only, `clean`.

**Diagram files.** Diagram specs live in `scripts/diagrams/chNN.py` and output to `assets/diagrams/NN-*.{svg,excalidraw}`.

**Book abbreviations** used in the table:

| Code | Book |
|---|---|
| LH | *Learning Helm*, Butcher, Farina, Dolitsky, O'Reilly 2021, 9781492083641 |
| MKR | *Managing Kubernetes Resources Using Helm*, 2nd ed., Block, Dewey, Packt 2022, 9781803242897 |
| KP | *Kubernetes Patterns*, 2nd ed., Ibryam, Huß, O'Reilly 2023, 9781098131678 |
| KUR | *Kubernetes: Up and Running*, 3rd ed., Burns et al., O'Reilly 2022, 9781098110192 |
| CKAD | *CKAD Study Guide*, 2nd ed., Muschko, O'Reilly 2024, 9781098152857 |
| PEK | *Platform Engineering on Kubernetes*, Salatino, Manning 2024, 9781617299322 |
| GOK | *GitOps and Kubernetes*, Yuen et al., Manning 2021, 9781617297274 |
| K4D | *Kubernetes for Developers*, Denniss, Manning 2024, 9781617297175 |
| EPE | *Effective Platform Engineering*, Chankramath, Cheneweth, Oliver, Alvarez (verify), Manning 2025, 9781633436497 |
| docs | Official Helm 4 sources only |

| Part (`part_name`, order) | # / file | Helm capabilities | Example dir | Citations | Diagrams |
|---|---|---|---|---|---|
| Getting started (0) | 00 `00-outline.md` | Arc of the book, progressive build table | none | none | `00-build-up-arc` |
| | 01 `01-prerequisites.md` | Project-local Helm 4 install, `helm version`, env isolation (`HELM_*_HOME`), minikube profile, operator-only bootstrap, image build | `01-lab-setup` (preflight + `scripts/platform/bootstrap.sh` driver) | docs | `01-lab-topology` |
| | 02 `02-helm-4-tour.md` | What Helm is (client-only, releases, charts, repos), install a public OCI chart (`oci://ghcr.io/stefanprodan/charts/podinfo`), `helm show/install/list/status/uninstall`, Helm 3→4 changes table | `02-helm-tour` | docs; LH (package-manager concepts only) | `02-helm-architecture` |
| From manifests to a chart (1) | 03 `03-shipping-service-raw-manifests.md` | Why charts: raw Deployment/Service/ConfigMap for shipping-service (memory storage), image build, probes, resources, securityContext | `03-raw-manifests` | KUR (Deployments/Services/ConfigMaps), KP (Health Probe, Predictable Demands, Managed Lifecycle), K4D (containerizing, probes), CKAD (securityContext, probes) | `03-raw-manifest-sprawl` |
| | 04 `04-first-chart.md` | `helm create` vs hand-built chart, anatomy, `Chart.yaml` apiVersion v2, `version` vs `appVersion`, `type`, `.helmignore`, install/upgrade/rollback/history/uninstall (`--keep-history`), release storage in Secrets (`sh.helm.release.v1.*`), `HELM_DRIVER` | `04-first-chart` | LH (anatomy); docs (lifecycle flags, storage) | `04-chart-anatomy`, `04-release-revisions` |
| | 05 `05-values-and-overrides.md` | values.yaml design, precedence (parent → `-f` order → `--set*` last), `--set`, `--set-string`, `--set-file`, `--set-json`, `--set-literal`, `--reuse-values` / `--reset-values` / `--reset-then-reuse-values`, `values.schema.json` (draft 2020-12 vs 7; verify Helm 4 support), `helm show values` | `05-values` | LH (values concept); docs (flags, schema) | `05-values-precedence` |
| | 06 `06-templates.md` | Go templates and Sprig, built-ins (`.Release`, `.Chart`, `.Capabilities`, `.Template`, `.Files`), pipelines, `quote/default/toYaml/nindent/trim`, whitespace chomping, `if/with/range`, `$` scope, variables, `tpl`, `required`, `fail`, `lookup` (empty under `template`/client dry-run) | `06-templates` | LH, MKR (templating) | `06-render-pipeline` |
| | 07 `07-helpers-and-notes.md` | Named templates in `_helpers.tpl`, `define/include/template`, why `include`, recommended labels, `fullname` truncation, `NOTES.txt`, `.Files.Get/Glob/AsConfig` | `07-helpers-notes` | LH | `07-named-templates` |
| | 08 `08-config-and-secrets.md` | ConfigMap/Secret from values, `checksum/config` rollout annotation, immutable ConfigMaps, `existingSecret` pattern, `API_TOKEN` Secret, comparison of secrets approaches (Sealed Secrets, External Secrets Operator, SOPS / helm-secrets; Helm 4 plugin compatibility verified or flagged), `lookup` to preserve generated secrets | `08-config-secrets` | KP (Configuration Resource, Immutable Configuration); docs | `08-secrets-options` |
| Data and lifecycle (2) | 09 `09-dependencies-postgres.md` | `dependencies` in Chart.yaml, `helm dependency update/build/list`, `Chart.lock`, `file://` subchart `shipping-postgres` (CNPG `Cluster`), `condition`/`tags`, `alias`, `import-values`, `global`, wiring the CNPG `<cluster>-app` secret; `SHIPPING_STORAGE=postgres` | `09-postgres-subchart` | LH, MKR (dependencies); KP (Operator) | `09-subchart-tree` |
| | 10 `10-crds-and-operators.md` | `crds/` semantics (install only; no templating, upgrade or delete), why app charts ship CRs and not operators, `.Capabilities.APIVersions.Has` + `fail` guard for a missing operator, small `ShippingRoute` demo CRD in `crds/` showing upgrade non-behavior, `--skip-crds` | `10-crds-operators` | KP (Operator, Controller); docs | `10-crd-ownership` |
| | 11 `11-hooks-and-migrations.md` | Migration Job as `pre-install,pre-upgrade` hook (`python -m app.migrate`), `helm.sh/hook-weight`, `hook-delete-policy` (`before-hook-creation,hook-succeeded`), hook failure behavior, `post-upgrade` cache-warm example, hooks vs init containers, `helm get hooks` | `11-hooks-migrations` | LH (hooks); K4D (Jobs); KP (Init Container); docs (Helm 4 hook/wait behavior) | `11-hook-timeline` |
| | 12 `12-release-lifecycle.md` | `--wait` (Helm 4 watcher), `--timeout`, `--rollback-on-failure`, `--cleanup-on-fail`, SSA default and field-manager conflicts, `--force-replace`, `--take-ownership`, `--history-max`, `helm get all/values/manifest/notes/metadata`, `helm status`, `helm rollback`, decoding a release Secret | `12-release-lifecycle` | **docs only** | `12-upgrade-failure-paths` |
| Debugging and testing (3) | 13 `13-debugging-charts.md` | `helm lint --strict`, `helm template --debug --show-only`, `--dry-run=client` vs `--dry-run=server`, `helm get manifest`, helm-diff plugin under Helm 4, kubeconform with CRD schemas (datree CRDs-catalog), common errors | `13-debugging` | docs | `13-debug-ladder` |
| | 14 `14-chart-testing.md` | `templates/tests/` + `helm test`, helm-unittest (suites, snapshot, `failedTemplate`), chart-testing `ct lint` / `ct install` against `helm4dev`, CI workflow `.github/workflows/charts-ci.yml` | `14-chart-testing` | MKR (chart testing concepts); docs | `14-test-pyramid` |
| Multi-service applications (4) | 15 `15-kafka-and-notification.md` | `shipping-kafka` subchart (Strimzi `Kafka`/`KafkaNodePool`/`KafkaTopic`), notification-service chart, `KAFKA_ENABLED`, event flow dispatch → `shipment.dispatched` → notification | `15-kafka-notification` | KP; docs | `15-event-flow` |
| | 16 `16-umbrella-charts.md` | `shipping-platform` umbrella: deps with `alias` (`shipping`, `notification`, `db`, `kafka`), `condition`/`tags` (`tags.messaging`), `global` (env, OTLP endpoint, image registry), `import-values` (exports from db), ordering limits (hooks and readiness vs dependency order) | `16-umbrella` | LH, MKR | `16-umbrella-topology` |
| | 17 `17-library-charts.md` | `type: library` chart `pc-lib` (deployment, service, labels, probes, securityContext, otelEnv, data-product metadata), consuming it, versioning a library | `17-library-chart` | LH (library charts); EPE (golden paths) | `17-library-reuse` |
| | 18 `18-starters-golden-paths.md` | `helm create --starter`, starter `pc-fastapi` built on pc-lib, starter location in `$HELM_DATA_HOME/starters`, golden paths | `18-starters` | EPE, PEK | `18-starter-flow` |
| Distribution and supply chain (5) | 19 `19-packaging-and-repos.md` | `helm package` (`--version`, `--app-version`, `--dependency-update`), SemVer for charts, classic repo (`helm repo index`, served by `python3 -m http.server`), `helm repo add/update/search` | `19-packaging-repos` | LH (repositories concept); docs | `19-semver-chart-vs-app` |
| | 20 `20-oci-registries.md` | `helm push/pull/show oci://`, `helm registry login`, local `docker.io/library/registry:2` on `127.0.0.1:5001` plus the minikube registry addon, `--plain-http`, install by digest, OCI dependencies | `20-oci` | **docs only** | `20-oci-flow` |
| | 21 `21-provenance-and-signing.md` | `helm package --sign --key --keyring` (throwaway key in project-local GNUPGHOME, legacy keyring export), `.prov`, `helm verify`, `--verify` on install/pull; cosign key-pair signing of the OCI chart artifact and `cosign verify`; keyless noted as not run here | `21-signing` | **docs only** (+ sigstore docs) | `21-trust-chain` |
| Extending Helm (6) | 22 `22-plugins.md` | Helm 4 plugin types and runtimes, `helm plugin install/list/uninstall` (verification flags), writing a subprocess `cli/v1` plugin `helm shipping-env`, Wasm runtime: a minimal extism Go-PDK plugin built with Go `GOOS=wasip1` (marked unverified if the build path fails) | `22-plugins` | **docs only** | `22-plugin-types` |
| | 23 `23-post-renderers.md` | Post-renderer as a `postrenderer/v1` plugin wrapping `kubectl kustomize` (adds labels plus a patch), `--post-renderer <plugin-name>` and args | `23-post-renderers` | **docs only** | `23-post-render-pipeline` |
| Delivery and operations (7) | 24 `24-environment-promotion.md` | `values-dev/stage/prod.yaml` layering, per-env namespaces, pinning chart version and image digest, promotion by version bump, optional Helmfile (`helmfile.yaml`, unverified if Helmfile lacks Helm 4 support) | `24-environments` | PEK, EPE | `24-promotion-flow` |
| | 25 `25-gitops-argocd.md` | Argo CD installed via its Helm chart, `Application` from the OCI chart in the in-cluster registry (primary, verifiable here) and from Git (after push), `helm.valueFiles`, Argo renders with `helm template` (hooks mapped to sync hooks; `lookup` not available), sync waves vs hook weights | `25-gitops-argocd` | GOK (GitOps principles only), PEK, MKR (Argo CD concepts only); docs (Argo CD + Helm 4) | `25-gitops-loop` |
| | 26 `26-observability-lgtm.md` | Library-driven OTel env (`OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability.svc.cluster.local:4318`, `OTEL_SERVICE_NAME`, resource attrs from `.Release`/`.Chart`), Grafana dashboard ConfigMap shipped by the chart (sidecar label), tracing across Kafka, Tempo/Loki/Mimir queries | `26-observability` | KP (Sidecar / observability context) | `26-telemetry-path` |
| Appendices (8) | 27 `27-appendix-openshift-local.md` | Same umbrella on OCP via CRC: `restricted-v2` SCC, arbitrary UID / GID 0, no `runAsUser`, Route vs Ingress (Capabilities-gated template), `oc new-project`, internal registry push, `HelmChartRepository`/`ProjectHelmChartRepository` CR + Developer console Helm UI, optional ImageStream. Marked **untested here**, with checklist plus `verify-crc.sh` | `27-openshift-crc` | docs (OpenShift docs) | `27-openshift-differences` |
| | 28 `28-appendix-helm3-to-helm4.md` | Migration reference: renamed/removed flags, SSA, plugins, post-renderers, `helm-mapkubeapis`-style notes, coexistence | none (reference) | **docs only** | none |
| | 29 `29-appendix-cheat-sheet.md` | Command and template-function cheat sheet | none | docs | none |
| | 30 `30-appendix-further-reading.md` | Bibliography with all cited books, one line each (citation format), plus the official sources list | none | all kept books | none |

**Book decisions under the user constraint.** **All 9 books are kept**, each limited to still-valid scope. No Helm 2 or Tiller-era book is cited.

| Book | Decision | Cite for | Never cite for |
|---|---|---|---|
| LH (2021, Helm 3) | Keep | Chart anatomy, values concept, templating, helpers, dependencies, library charts, hooks, repositories concept | Any flag or command, plugins, post-renderers, OCI, SSA, wait, atomic |
| MKR (2022, Helm 3) | Keep | Templating, dependencies, chart-testing concepts, Argo CD concepts | Same as LH |
| KP | Keep | K8s patterns in 03, 08, 09, 10, 11, 15, 26 | Helm behavior |
| KUR | Keep | Ch 03 K8s objects only | Its Helm section |
| CKAD | Keep | Ch 03 securityContext and probes only | Its Helm-3 exam commands |
| K4D | Keep | Ch 03 and 11 (containerizing, Jobs) | Helm behavior |
| GOK | Keep | Ch 25 GitOps principles only (declarative, reconcile, drift) | Argo CD CLI or version specifics |
| PEK | Keep | Ch 18, 24, 25 | Helm behavior |
| EPE | Keep | Ch 17, 18, 24 | Helm behavior |

## Deck outlines

The decks live in `presentation/helm-101/` and `presentation/helm-201/`. Each copies `deck-helpers.js`, `dgen.py`, `assets/`, a `build_diagrams.py` using cairosvg (MEA variant), and `package.json`.
- Output: `Helm-101-r1.0.pptx` and `Helm-201-r1.0.pptx`, committed next to `deck.js`.
- `OUT` is a relative filename, not `/mnt/...`.
- Every slide gets thick speaker notes ("What it shows / What to show: `examples/NN` command / Fallback").
- Slide titles are 2–5 word concept noun phrases.
- No slide numbers are referenced.
- Helm 4 syntax only.

**Helm 101 (≈36 slides; chapters 02–12):**
1. Cover: "Helm for Developers 101", subtitle "Charts, values, templates, releases with Helm 4"
2. Agenda
3. Divider: Why Helm
4. YAML sprawl across environments (diagram)
5. Helm as package and release manager
6. Helm 4 at a glance (table: SSA default, rollback-on-failure, plugins/Wasm, post-renderer plugins, kstatus wait)
7. Divider: Core concepts
8. Chart, release, repository, values
9. Client-only architecture and release Secrets (diagram)
10. Divider: First chart
11. Chart anatomy (tree, code)
12. `Chart.yaml` v2 (code)
13. Install, upgrade, rollback (diagram of revisions)
14. Release history and storage
15. Divider: Values
16. Values precedence (diagram)
17. Override flags (code: `-f`, `--set`, `--set-json`, `--set-file`)
18. `values.schema.json` (code)
19. Divider: Templates
20. Go templates and Sprig (code)
21. Flow control and scope (code: if/with/range/$)
22. Named templates (code `_helpers.tpl`, include vs template)
23. `tpl`, `required`, `fail`, `lookup` (table)
24. `NOTES.txt`
25. Divider: Config, data, hooks
26. Config rollouts with checksums
27. Secrets options (table)
28. Subcharts and the Postgres operator (diagram)
29. Migration hooks (timeline diagram)
30. Hook weights and delete policies (table)
31. Divider: Safe releases
32. Wait and rollback-on-failure
33. Server-side apply in Helm 4
34. Lint, template, dry-run
35. Next: Helm 201
36. Appendix: Helm 3 → 4 flag map

**Helm 201 (≈42 slides; chapters 13–27):**
1. Cover
2. Agenda
3. Recap: Helm 101 in one slide
4. Divider: Testing and debugging
5. Debug ladder (diagram)
6. Diff plugin and server dry-run
7. Chart test pyramid (diagram)
8. helm-unittest (code)
9. chart-testing and kubeconform
10. Chart CI pipeline
11. Divider: Multi-service applications
12. Kafka via Strimzi
13. Umbrella topology (diagram)
14. Conditions, tags, alias (code)
15. Globals and import-values
16. CRDs and operators (table)
17. Capabilities guards (code)
18. Library charts (diagram)
19. Starters and golden paths
20. Divider: Distribution
21. Chart SemVer vs appVersion
22. Classic repos vs OCI
23. Push and pull with OCI (diagram)
24. Provenance files
25. Cosign for OCI charts
26. Divider: Extending Helm
27. Helm 4 plugin types (table)
28. Wasm plugins
29. Post-renderer plugins (diagram)
30. Divider: Delivery
31. Environment promotion (diagram)
32. Helmfile, optional
33. GitOps with Argo CD (diagram)
34. Hooks vs sync waves
35. Observability via the library chart
36. Telemetry path to LGTM (diagram)
37. Divider: OpenShift
38. SCCs and arbitrary UIDs
39. Routes and the Helm console
40. Takeaways
41. Appendix: cheat sheet
42. Appendix: reading list (only kept books + official docs)

## Golden app and chart contract (S3 and S4 both code against this; neither may deviate)

**shipping-service** (`services/shipping-service`, port 8080)

Endpoints:
- `GET /health`
- `GET /healthz`: checks the DB only when `SHIPPING_STORAGE=postgres`
- `GET /api/info`: returns `{service, version, environment, defaultCarrier, storage, kafkaEnabled}`
- `POST /api/shipments {orderId, address}`: returns 201 with status PENDING. If `API_TOKEN` is set, it requires `Authorization: Bearer <token>` and returns 401 otherwise.
- `GET /api/shipments/{id}`: 404 if absent
- `GET /api/shipments?orderId=`: 400 if missing
- `POST /api/shipments/{id}/dispatch`: returns DISPATCHED and publishes the `ShipmentDispatched` JSON to `KAFKA_TOPIC_DISPATCHED` when `KAFKA_ENABLED=true`

Environment variables:
- `SERVICE_NAME`, `SERVICE_VERSION`, `DEPLOY_ENV`, `LOG_LEVEL`
- `SHIPPING_DEFAULT_CARRIER`
- `SHIPPING_STORAGE=memory|postgres` (default `memory`)
- `PG_HOST`, `PG_PORT`, `PG_DATABASE`, `PG_USER`, `PG_PASSWORD`, `PG_SCHEMA=shipping`
- `KAFKA_ENABLED=false`, `KAFKA_BOOTSTRAP`, `KAFKA_TOPIC_DISPATCHED=shipment.dispatched`
- `API_TOKEN`
- `OTEL_SDK_DISABLED=true` (default), `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`, `OTEL_RESOURCE_ATTRIBUTES`

`python -m app.migrate` applies `migrations/V*.sql` in order into schema `PG_SCHEMA`, records them in `<schema>.schema_migrations`, is idempotent, and exits 0. The app also tolerates the DB until it is migrated: readiness fails with 503 until the tables exist.

**notification-service** (port 8080)
- Endpoints: `/health`, `/healthz` (consumer started), `GET /api/notifications` (last 50 received)
- Background aiokafka consumer (group `notification-service`) runs in the lifespan and continues the trace context.
- Environment: `KAFKA_BOOTSTRAP`, `KAFKA_TOPIC_DISPATCHED`, `KAFKA_GROUP_ID`, plus the OTel variables.

**Image**
- One `services/Containerfile`, built from `services/` as the build context, with `ARG SERVICE`, `ARG PYTHON_VERSION=3.15.0`, and `ARG UV_IMAGE=ghcr.io/astral-sh/uv:<pinned>`.
- Builder: `registry.access.redhat.com/ubi10/ubi-minimal`. It copies `/uv`, runs `uv python install ${PYTHON_VERSION}` into `/opt/python`, creates a venv at `/opt/venv`, and installs `common/` plus the service. A `test` target runs pytest.
- Runtime: `ubi10/ubi-minimal`. It copies `/opt/python` and `/opt/venv`, runs as `USER 1001:0`, needs no writable root filesystem (an `/tmp` emptyDir is enough), and its CMD runs uvicorn on port 8080.
- Fallback F1: `PYTHON_VERSION=3.14` (same build). Fallback F2: `PYTHON_BASE=registry.access.redhat.com/ubi9/python-314`. Whichever is used gets recorded in `CONTRIBUTING.md` and the reconciliation plan.

**Golden charts** (`charts/` at the repo root)
- `pc-lib` (library)
- `shipping-service` and `notification-service` (applications, depending on pc-lib via `file://../pc-lib`)
- `shipping-postgres` (CNPG `Cluster`)
- `shipping-kafka` (Strimzi)
- `shipping-platform` (umbrella), with `values-{dev,stage,prod,openshift}.yaml`
- `starters/pc-fastapi`

Plugins (`plugins/`):
- `helm-shipping-env` (cli/v1, subprocess)
- `kustomize-postrender` (postrenderer/v1)
- `wasm-hello` (cli/v1, Wasm, Go extism PDK)

Requirements across the charts:
- Every app chart has `values.schema.json`, `NOTES.txt`, `templates/tests/test-connection.yaml`, a `tests/` helm-unittest suite, and `ci/ci-values.yaml` for ct.
- `securityContext`: `runAsNonRoot: true`, no `runAsUser` (OpenShift-safe), `allowPrivilegeEscalation: false`, capabilities drop ALL, `seccompProfile: RuntimeDefault`.

## Steps

The orchestrator does all git commits. Parallel executors never run `git commit`, which avoids index-lock races. After each step or parallel group lands, the orchestrator runs `git add <owned paths> && git commit -m "<type>(<scope>): ..."` on `feature/r1-initial-build`, then updates the step-status table in `_plans/r1-plan.md`.

Commits follow `~/.claude/skills/lgtm-github/references/commit-conventions.md`:
- Types: docs, site, demo, ci, chore, fix, feat.
- Scopes: `§NN`, `demo-NN`, `r1.0`.
- **No AI attribution trailers.**
- WIP checkpoints are allowed.

### S1: Scaffold the repo (serial, first)
- **Owns:**
  - `~/Dev/helm-for-developers/` root files: `_config.yml`, `Gemfile`, `index.html`, `_layouts/`, `_includes/` (header nav: Tutorial → `/docs/00-outline/`, Prerequisites → `/docs/01-prerequisites/`, Decks, GitHub), `assets/css/site.css`, `assets/diagrams/README.md`
  - `.github/workflows/pages.yml`, `.gitignore` (MEA set plus `.tools/ dist/ .venv/ qa/ presentation/*/node_modules`), `LICENSE`, `README.md`, `CLAUDE.md`, `CONTRIBUTING.md` (house style from above)
  - `_parts/00..08-*.md`, all nine parts, with `part_name` exactly as in the outline table
  - `_docs/00-outline.md`
  - `_plans/r1-plan.md` (this plan verbatim; `render_with_liquid: false`), `_plans/iteration-plan.md`, `_plans/reconciliation-plan.md` (skeleton), `_plans/claims/.gitkeep`
  - `scripts/generate_diagram.py` (copied from `~/.claude/skills/lgtm-tutorial/scripts/`), `scripts/diagrams/.gitkeep`
- **Process:** `git init -b main`, initial commit `chore: scaffold Jekyll site from lgtm-jekyll template`, then `git checkout -b feature/r1-initial-build`.
- **Deps:** none.
- **Group:** 0.
- **Skills to read:**
  - `~/.claude/skills/lgtm-jekyll/SKILL.md`
  - `~/.claude/skills/lgtm-jekyll/references/{authoring-conventions,theming}.md`
  - `~/.claude/skills/lgtm-tutorial/references/conventions.md`
  - `~/.claude/skills/lgtm-github/SKILL.md` §1, §5
- **Acceptance:**
  - Every `_parts` file parses and has `part_name` and `order` 0–8.
  - `00-outline.md` lists all 31 chapters by title.
  - `_config.yml` has the values above.
  - `git branch --show-current` = `feature/r1-initial-build`.
  - `main` has exactly one commit.

### S2: Tools and platform scripts (group A)
- **Owns:** `scripts/env.sh`, `scripts/install-tools.sh`, `scripts/platform/{setup-profile,bootstrap,setup-postgres-operator,setup-kafka-operator,setup-lgtm,teardown,cluster-status}.sh`, `platform/observability/{otel-collector-config.yaml,grafana-datasources.yaml,dashboards/}`, `scripts/build-images.sh`, `scripts/tunnel.sh`, `scripts/check-helm-commands.sh`, `scripts/validate-site.sh` (the 5 lgtm-tutorial static checks plus alt-text check plus part match), `scripts/forbidden-syntax.sh`.
- **Deps:** S1.
- **Group:** A.
- **`install-tools.sh`:** downloads into `.tools/bin` only. It covers Helm 4.3.x (checksum verified), kubeconform, ct (plus yamllint/yamale in `.tools/venv` if ct needs them), cosign, optional helmfile, and the helm-unittest and helm-diff plugins via `helm plugin install` using `HELM_PLUGINS`. Executors must check the Helm 4 plugin-verification flag in `helm plugin install --help`.
- **Platform scripts:** substitute `{{PROFILE_NAME}}=helm4dev`, `{{NAMESPACE}}`/`{{PROJECT_NAME}}` as appropriate, and remove the CR tiers. Re-verify the CNPG, Strimzi and LGTM chart versions against current releases, and confirm they install under Helm 4 with SSA.
- **`check-helm-commands.sh`:** extracts every line starting `helm ` (and `[host]$ helm`) from `_docs/*.md`, `examples/**/{demo.sh,README.md}` and `presentation/*/deck.js`. For each, it checks that the subcommand exists and that every `--flag` appears in `.tools/bin/helm <sub> --help`. Non-zero exit on any miss.
- **`forbidden-syntax.sh`:** greps `_docs/ examples/ charts/ presentation/*/deck.js` for `--atomic`, `helm upgrade .*--force( |$)`, `--post-renderer [./~]`, `tiller`, `helm init`, `requirements.yaml`, `helm serve`, `apiVersion: v1` in any `Chart.yaml`. Hits allowed only in `28-appendix-helm3-to-helm4.md` and in lines marked `<!-- helm3-reference -->`.
- **Skills to read:**
  - `~/.claude/skills/lgtm-minikube-stack/SKILL.md`
  - `references/{preflight-and-prerequisites,known-issues,ports-and-endpoints,lgtm-on-minikube-sizing,opt-in-flags}.md`
  - `snippets/{helm-repo-patterns,readiness-wait-patterns}.md`
- **Acceptance:**
  - `bash -n` passes on all scripts.
  - `source scripts/env.sh && helm version --short` prints `v4.3.*` (or newer 4.x).
  - `~/.local/bin/helm version --short` is still `v3.18.3`.
  - `helm plugin list` shows unittest and diff.
  - `kubeconform -v`, `ct version` and `cosign version` succeed.
  - `scripts/platform/bootstrap.sh` contains no `kind: Cluster` / `kind: Kafka` creation.
  - Downloading the tools needs network but does not touch system paths.

### S3: Services (group A)
- **Owns:** `services/` (`common/pcobs`, `shipping-service`, `notification-service`, `Containerfile`, migrations, tests).
- **Deps:** S1.
- **Group:** A.
- **Skills to read:** `~/.claude/skills/lgtm-minikube-stack/references/base-images.md` and the Reuse map rows above. Read the source files listed there.
- **Gate first:** confirm the Python 3.15.0 GA tag exists (`python.org` / `uv python list --all-versions` inside the uv image) and confirm cp315 wheels for pydantic-core, asyncpg and aiokafka (`pip download --only-binary=:all: --python-version 3.15 ...` in the builder). Apply fallbacks F1/F2 if not, and **record the decision**.
- **Acceptance:**
  - `podman build -f services/Containerfile --build-arg SERVICE=shipping-service --target test services/` passes the tests, which cover: `/health`, `/api/info` env reflection, create/get/list/400/404 in memory mode, the 401 token path, the migration runner being idempotent (unit-tested against a fake connection or skipped with a reason), and a dispatch event payload matching the `ShipmentDispatched` field names.
  - The same passes for notification-service.
  - `podman run --rm <img> python -c 'import sys;print(sys.version)'` prints 3.15.x (or the recorded fallback).
  - The runtime image runs as uid 1001 and also starts with an arbitrary uid: `podman run --user 123456:0`.

### S4: Golden charts and plugins (group A)
- **Owns:** `charts/`, `plugins/`.
- **Deps:** S1. Codes to the contract above.
- **Group:** A.
- **Skills to read:** Reuse map rows for charts and OpenShift. Helm 4 docs for any changed behavior.
- **Acceptance:**
  - With `scripts/env.sh` sourced, `helm lint --strict` passes for every chart, with `helm dependency build` run first where needed.
  - `helm unittest charts/{shipping-service,notification-service,shipping-platform}` passes, with at least 20 tests in total including schema-failure (`failedTemplate`) cases.
  - `helm template platform charts/shipping-platform -f charts/shipping-platform/values-dev.yaml | kubeconform -strict -summary -schema-location default -schema-location '<datree CRDs-catalog URL template>'` shows 0 invalid.
  - The same template with `--api-versions route.openshift.io/v1 -f values-openshift.yaml` renders Routes, and without that flag renders none.
  - No rendered Deployment sets `runAsUser`.
  - `kubectl kustomize` post-renderer plugin: `helm template ... --post-renderer kustomize-postrender` adds the label.
  - `helm shipping-env` runs.
  - The Wasm plugin either builds and runs, or is documented as unverified with the exact error.

### S5: Golden integration run on minikube (serial)
- **Owns:** `_plans/evidence/golden-*.txt`.
- **Deps:** S2, S3, S4.
- **Group:** serial.
- **Process:** start profile `helm4dev` (do not touch the `datamesh` profile), run `bootstrap.sh`, `build-images.sh`, then install `shipping-platform` with `values-dev.yaml --wait --rollback-on-failure`.
- **Acceptance**, with evidence captured:
  - The migration hook Job completes.
  - `curl -s 127.0.0.1:8080/api/info` through the tunnel reflects dev values.
  - POST then dispatch, then `GET 127.0.0.1:8081/api/notifications` contains that `shipmentId`. That is the observable cross-service effect.
  - `helm test platform` passes.
  - Negative control: upgrade with `--set shipping.image.tag=doesnotexist --wait --timeout 90s --rollback-on-failure` fails and `helm history` shows the rollback to the previous revision.
  - A Tempo trace contains spans from both services. Query and result are recorded.
  - Any criterion not met is recorded as not met.

### S6.0 – S6.8: Chapter plus example authoring by Part (group B, parallel)
- **Deps:** S5.
- **Group:** B.
- **Each executor owns:**
  - its `_docs/NN-*.md`
  - `examples/NN-*/`
  - `scripts/diagrams/chNN.py` and `assets/diagrams/NN-*.{svg,excalidraw}`
  - `_plans/claims/partN.md` (new claims, all `unverified`)
- **Assignments:**
  - S6.0: ch01–02
  - S6.1: ch03–08
  - S6.2: ch09–12
  - S6.3: ch13–14 plus `.github/workflows/charts-ci.yml`
  - S6.4: ch15–18
  - S6.5: ch19–21
  - S6.6: ch22–23
  - S6.7: ch24–26
  - S6.8: ch27–30, including `examples/27-openshift-crc/{verify-crc.sh,CHECKLIST.md,values-openshift.yaml,build-and-push.sh}`. Banner: "UNTESTED on the authoring machine; run on the CRC host".
- **Rules:**
  - Snapshots are derived from `charts/` and stripped back to the chapter's state. An example never references `../../charts`, so it stays self-contained.
  - Each chapter: front matter (`title`, `order`, `part` exact, quoted `description`, `duration`), hook paragraph, the run-hint line, at least one diagram with alt text and a "Figure NN.x —" caption, concept sections, a full **How the code works** walk of the real template/values/plugin code (depth standard), Build, run, observe, a Cross-check (e.g., `kubectl get` vs `helm get manifest`, kubeconform, `helm diff`), What you learned, Further reading (citation format; allowed scope only), and the verification footer `unverified`.
  - 1,400–1,900 words for hands-on chapters.
  - Literal `{{ }}` wrapped in `{% raw %}…{% endraw %}`.
  - Every Helm command checked against `helm <cmd> --help` (Helm 4).
  - Each executor runs `examples/NN/demo.sh offline` for its chapters and may **not** run live cluster demos; that is S7.
- **Skills to read:**
  - `~/.claude/skills/lgtm-tutorial/SKILL.md`
  - `references/{chapter-template,example-template,conventions,diagram-engine}.md`
  - `~/.claude/skills/lgtm-jekyll/references/authoring-conventions.md`
  - `~/.claude/skills/lgtm-professional-voice/SKILL.md` + `references/phrase-list.md` (draft in-voice)
  - `~/.claude/skills/lgtm-diagram-generator/SKILL.md`
- **Acceptance (per executor):**
  - `scripts/validate-site.sh` passes for its files.
  - `scripts/check-helm-commands.sh` passes and `scripts/forbidden-syntax.sh` is clean for its files.
  - `demo.sh offline` exits 0 for each example.
  - `bash -n` passes on demo.sh.
  - The diagram pair parses.
  - Word count in range.
  - No book is cited for a docs-only topic: the docs-only chapters 12, 13, 20, 21, 22, 23, 28 contain zero ISBN lines, and other chapters cite only the scopes in the book decision table.
  - `~/.claude/skills/lgtm-professional-voice/scripts/scan.sh --tier ban <files>` shows 0 hits, or each survivor has a reason in the claims file.

### S7: Live verification sweep (serial)
- **Owns:** `_plans/reconciliation-plan.md` (merging `_plans/claims/*`), `_plans/evidence/NN-*.txt`, and the verification-footer paragraph only in `_docs/*.md` and example README "Verification status" sections.
- **Deps:** all of S6.
- **Process:** run `examples/NN/demo.sh` for 01–26 in order on `helm4dev`, with clean between. Promote a footer to `verified` only with a behavioral observation (what changed and what was seen, with a negative control where cheap, e.g., the hook Job ran before the new pods, the rollback restored revision N, an unsigned chart was rejected by `--verify`, the cosign verify failure on a tampered tag, Argo CD reached Synced/Healthy and drift was reverted).
- **Stays unverified:** ch27, plus Git-sourced Argo CD until the push happens. Also anything that failed, with the failure text.
- **Acceptance:** the reconciliation plan has one row per claim with status and evidence path, and no footer says verified without an evidence file.

### S8a / S8b: Decks 101 / 201 (group C, parallel)
- **Owns:** `presentation/helm-101/` or `presentation/helm-201/` respectively, plus `presentation/README.md` (S8a only).
- **Deps:** S6 (and S7 preferred, for consistency).
- **Setup:** python venv `presentation/.venv` with `cairosvg`, which is gitignored.
- **Skills to read:** `~/.claude/skills/lgtm-presentation/SKILL.md`, `references/{deck-builder,theme,diagram-engine}.md`, `~/.claude/skills/lgtm-professional-voice/references/surfaces.md`.
- **Acceptance:**
  - `NODE_PATH=$(npm root -g) node deck.js` writes the pptx.
  - Slide count within ±4 of the outline.
  - A python-pptx (or unzip/XML) check shows notes on every slide, so notes count = slide count.
  - `soffice --headless --convert-to pdf` succeeds.
  - Cover, one code slide, one diagram slide and one table slide rendered with `pdftoppm` and eyeballed: logo bottom-right, captions single-line.
  - `check-helm-commands.sh` covers `deck.js`.

### S9: Hub integration (group C; separate repo `~/Dev/patterncatalyst-workshops-tutorials-list`)
- **Owns (in the hub repo, on branch `feature/add-helm-for-developers`):** `_data/sites.yml`, `_data/books.yml`, `_data/book_categories.yml`, `scripts/gen-books.py` (allowlist only).
- **Deps:** S6.8 (final citations).
- **Changes:**
  1. Append `"helm-for-developers"` to `ALLOWED_REPOS`. Commit `chore(scripts): allowlist helm-for-developers for book scan`.
  2. Dry-run only: `python3 -I scripts/gen-books.py --repos-root ~/Dev --out <session scratchpad>/books.gen.yml`. **Never** with `--out _data/books.yml`. Both modes rewrite the file from the scan and would drop curated entries, e.g. `otel-observability-tutorial` references that are not in the allowlist. Confirm the generated output contains all 9 ISBNs with `referenced_by` including `helm-for-developers`.
  3. **Hand-add** the 9 entries to `_data/books.yml` in alphabetical title position, matching the existing schema (`title`, `authors`, `publisher`, `year`, `isbn`, `url` = publisher product page (oreilly.com / manning.com / packtpub.com), optional `review_note` for print/ebook ISBN differences, `referenced_by: ["helm-for-developers"]`). Verify ISBNs and titles against the O'Reilly platform or publisher pages, especially the EPE author list and print vs ebook ISBNs.
  4. Add a category `"Kubernetes, Helm & Platform Engineering"` to `book_categories.yml`, listing the 9 exact titles (Helm books first).
  5. Add a `sites.yml` entry under `"Cloud-Native & Kubernetes"`: slug `helm-for-developers`, quoted title "Helm for Developers", synopsis (no em dashes, voice-scanned), `repo_url`, and `site_url: null` with `note: "site publishing pending"` until Pages is live (S12 flips it).
- **Commit message style:** follow the hub history, e.g. `content(books): ...` / `content(sites): ...`.
- **Acceptance:**
  - `python3 -c "import yaml;[yaml.safe_load(open(f)) for f in ['_data/sites.yml','_data/books.yml','_data/book_categories.yml']]"` succeeds.
  - Every title in the new category exists in books.yml.
  - `bundle exec jekyll build` exits 0 (or a Ruby 3.3 container build if Ruby 4 breaks Jekyll).
  - `git diff main -- _data/books.yml` shows only additions.
  - **No push.**

### S10: Professional-voice pass (group D, parallel partitions)
- **Partitions:** ch00–10; ch11–20; ch21–30 + all READMEs + `examples/*/README.md`; deck 101 `deck.js`; deck 201 `deck.js`; hub copy (synopsis).
- **Deps:** S7, S8, S9.
- **Process:** each partition edits only its files. One final executor rebuilds both decks and regenerates any diagram whose spec changed.
- **Skills to read:** `~/.claude/skills/lgtm-professional-voice/SKILL.md` and all its references. Use `scan.sh --files` to balance the partitions.
- **Acceptance:**
  - `scan.sh --tier ban --fail ~/Dev/helm-for-developers` exits 0, or each survivor is listed with a reason in `_plans/voice-pass.md`.
  - `git diff` shows no changes inside fenced code blocks, commands, identifiers or evidence.
  - Decks rebuilt.

### S11: Package iteration (serial)
- **Owns:** `dist/helm-for-developers_r1.0.tar.gz` (gitignored) and `_plans/iteration-plan.md`.
- **Deps:** S10.
- **Process:** clean `__pycache__`, `.tools`, `node_modules`, `.venv`, `qa` from the tarball. Run all global checks. Tag `r1.0` only after Phase 3 validation passes.
- **Acceptance:** the tarball exists and `ls -d examples/*/ | wc -l` = 26 (examples 01–27 minus the absent 02? No: 01–27 hands-on = 27 dirs; see global criteria).

### S12: Outward-facing actions (REQUIRES USER CONFIRMATION, after Phase 3)
1. `gh repo create patterncatalyst/helm-for-developers --public --source=. --remote=origin --description "Helm 4 for developers: a chaptered tutorial with a Python 3.15 FastAPI shipping app, progressive chart examples, and Helm 101/201 decks" --push` (pushes `main`), then `git push -u origin feature/r1-initial-build`, `gh pr create`, CI green, `gh pr merge --squash --delete-branch`.
2. Set Settings → Pages → Source: GitHub Actions (`gh api -X POST repos/patterncatalyst/helm-for-developers/pages -f build_type=workflow`), then `gh run watch`.
3. Re-run ch25's Git-sourced Argo CD path and update its footer.
4. Hub: set `site_url` to `https://patterncatalyst.github.io/helm-for-developers/`, push the branch, open a PR (hub CLAUDE.md implies main-push deploys; follow lgtm-github PR flow).
5. Tag and release `r1.0` with the tarball and `sha256sums`.

**Parallelism summary:**
- 0: S1
- A: S2 ∥ S3 ∥ S4
- Serial: S5
- B: S6.0–S6.8 (9 executors, disjoint files)
- Serial: S7
- C: S8a ∥ S8b ∥ S9
- D: S10 partitions
- Serial: S11
- Gated: S12

## Acceptance criteria (global)

Run these from `~/Dev/helm-for-developers` after `source scripts/env.sh` unless noted.

1. `helm version --short` matches `^v4\.` and `~/.local/bin/helm version --short` still prints `v3.18.3`.
2. `ls _docs/*.md | wc -l` = 31 (00–30). `ls -d examples/*/ | wc -l` = 27 (examples 01–27; 00 and 28–30 have none).
3. `scripts/validate-site.sh` exits 0. It covers: front matter parses; each `part` ∈ `part_name`s; no stray `{{` outside raw/includes; SVG and Excalidraw parse; every include has non-empty alt and a "Figure" caption; `bash -n` on all `examples/*/demo.sh`.
4. `bundle exec jekyll build` exits 0. If Ruby 4.0 breaks Jekyll 4.3, then `podman run --rm -v $PWD:/srv:Z -w /srv docker.io/library/ruby:3.3 sh -c 'bundle install && bundle exec jekyll build'` exits 0.
5. `scripts/check-helm-commands.sh` exits 0, so every `helm` command in chapters, examples and decks uses subcommands and flags present in Helm 4 `--help`. `scripts/forbidden-syntax.sh` exits 0.
6. Book-citation rule:
   - `grep -l ISBN _docs/{12,13,20,21,22,23,28}-*.md` returns nothing.
   - Every ISBN line in `_docs` belongs to one of the 9 kept books.
   - Each kept book appears in ≥1 chapter plus ch30.
   - A validator spot-check of every LH/MKR citation confirms its "Used here for" scope is in the allowed list.
   - Every Helm-4-changed topic paragraph links a helm.sh/docs, blog or HIP URL.
7. `for d in examples/*/; do [ -x $d/demo.sh ] && (cd $d && ./demo.sh offline) || exit 1; done` exits 0 (ch27 offline = template with `--api-versions route.openshift.io/v1` + kubeconform).
8. `helm unittest` across `charts/*` (non-library) passes, with ≥20 tests.
9. `_plans/evidence/golden-*.txt` shows a dispatched `shipmentId` present in notification-service's `/api/notifications`, a passing `helm test`, and the rollback negative control.
10. Every `_docs` footer reading `verified` has a matching `_plans/evidence/NN-*.txt`. Ch27 footer is `unverified` and states "untested on the authoring machine". `examples/27-openshift-crc/verify-crc.sh` passes `bash -n` and checks:
    - `oc whoami`
    - `crc status`
    - `oc new-project hfd-ocp`
    - image push to the internal registry
    - `helm upgrade --install platform ... -f values-openshift.yaml --wait --rollback-on-failure`
    - pods Ready with `openshift.io/scc: restricted-v2` annotation
    - uid ≠ 1001 inside a pod (arbitrary UID)
    - Route host resolves and `curl -k https://<route>/api/info` returns 200
    - `helm test`
    - It prints PASS/FAIL per check.
11. Decks: `presentation/helm-101/Helm-101-r1.0.pptx` and `presentation/helm-201/Helm-201-r1.0.pptx` exist. Slide counts are 32–40 and 38–46. Notes count equals slide count, checked by script.
12. `~/.claude/skills/lgtm-professional-voice/scripts/scan.sh --tier ban --fail .` exits 0, or the survivors are justified in `_plans/voice-pass.md`. `grep -rniE '\bhonest(ly)?\b|capstone' _docs examples/*/README.md` returns nothing.
13. Container: the shipping-service image's `python -c 'import sys;print(sys.version_info[:2])'` prints `(3, 15)`, or `CONTRIBUTING.md` and the reconciliation plan record the fallback with the reason.
14. Hub branch: YAML parses, the jekyll build exits 0, the diff of `books.yml` is additions only (9 entries), the new category lists 9 existing titles, `sites.yml` has a `helm-for-developers` entry, and `ALLOWED_REPOS` contains `helm-for-developers`.
15. Git:
    - `git log main --oneline | wc -l` = 1 before S12.
    - All work sits on `feature/r1-initial-build` in Conventional Commits format.
    - `git log --format=%B | grep -ci 'co-authored-by\|generated with'` = 0.
    - No remote exists until S12 is confirmed.

## Risks

- **Python 3.15 timing.** GA is 2026-10-09, python-build-standalone 3.15.0 may lag by days, and cp315 wheels may be missing for asyncpg, pydantic-core or aiokafka. *Detected by* the S3 gate. *Handled by* recorded fallbacks F1/F2, never silently.
- **Helm 4 flag drift.** Executors may write Helm 3 flags from memory (`--atomic`, `--force`, a path given to `--post-renderer`). *Detected by* `check-helm-commands.sh` and `forbidden-syntax.sh`, with a validator spot-check.
- **Platform charts under Helm 4 SSA.** The LGTM, CNPG and Strimzi installs may hit field-manager conflicts or need newer chart versions. *Detected* in S2/S5 bring-up. The pinned versions get bumped and recorded.
- **Strimzi API version.** 0.49+ introduced `kafka.strimzi.io/v1` and v1beta2 is deprecated or removed in newer releases. The reused templates use v1beta2. *Detected by* `kubectl api-resources --api-group=kafka.strimzi.io` in S5 and kubeconform. Use whatever the installed operator serves.
- **ct container bundling Helm 3.** *Detected by* `ct version`/`helm version` inside ct. *Handled by* using the binary with the project-local Helm 4.
- **helm-diff / helm-unittest plugin install under Helm 4 verification.** May need a verification flag. *Detected by* `helm plugin list` in S2.
- **Wasm plugin build path (extism Go PDK + wasip1).** May not work. *Mitigation:* chapter 22 marks it unverified with the exact error; the subprocess plugin carries the runnable demo.
- **Argo CD pulling OCI from the in-cluster insecure registry** may need specific repo-secret fields (`enableOCI`, `insecure`). *Detected* in S7. The Git path waits for S12.
- **Parallel executors clobbering shared files** (`_plans/reconciliation-plan.md`, `assets/diagrams/README.md`, header nav). *Handled by* the ownership table: claims go to per-part files, and only the orchestrator commits.
- **Snapshot drift** between `charts/` (golden) and the `examples/*` copies, e.g. a fix in golden not propagated. *Detected by* `demo.sh offline` in every example plus S7 live runs. Any fix found in S7 must be applied to both, and the validator diffs the final example (26) against golden.
- **Hub data loss.** Running gen-books (with or without `--enrich`) into `_data/books.yml` would wipe curated URLs and `review_note`s, and drop `otel-observability-tutorial`. *Handled by* scratch-output-only rule; acceptance item 14 checks for additions only.
- **gen-books extraction quirks.** Dash-before-title captures only the last author, parentheses in the CKAD title are rejected, and hard-wrapped citation lines are missed. *Handled by* the fixed citation format and the S9 dry-run diff.
- **Ruby 4.0 with Jekyll 4.3** locally (missing default gems). *Fallback:* Ruby 3.3 container build. CI uses 3.3.
- **Resource contention** if the stopped `datamesh` profile is started at the same time. The scripts only touch `helm4dev`, and `setup-profile.sh` refuses `--replace` without an explicit flag.
- **Self-promotion of verification.** Executors may claim "verified" from a clean exit. *Handled by* S7 owning all promotions, with evidence files required (acceptance item 10).
- **Book metadata** (EPE authors, print vs ebook ISBNs). *Detected by* S9 verification against the O'Reilly platform and publisher pages, with `review_note` where they differ.

## Open questions for the user

1. **Python 3.15 base image.** No UBI 3.15 image exists and GA is tomorrow. The plan's default is UBI 10 minimal with a uv-installed CPython 3.15.0, falling back to 3.14 (same build), then `ubi9/python-314`. Is a non-UBI `python:3.15-slim` base acceptable instead, if wheels or python-build-standalone lag?
2. **Helm 4 install location.** The plan installs Helm 4.3 project-locally (`.tools/`), leaving the global Helm 3.18.3 alone. Would you rather upgrade `~/.local/bin/helm` globally? That affects datamesh and MEA scripts.
3. **Publishing.** Confirm the public repo `patterncatalyst/helm-for-developers` and GitHub Pages at `https://patterncatalyst.github.io/helm-for-developers/`, and whether the hub change goes in as a PR or a direct push to `main`. S12 waits for this either way.

Sources consulted for version facts:
- [Helm 3 End of Life](https://helm.sh/blog/helm-v3-end-of-life)
- [Helm v4 key changes from v3](https://dev.to/ilya-lesikov/helm-v4-key-changes-from-v3-2i26)
- [Helm 4 migration guide](https://dev.to/amareswer/helm-4-migration-guide-what-breaks-and-how-to-fix-it-before-eol-4p99)
- [Python 3.15.0rc3](https://www.python.org/downloads/release/python-3150rc3/)
- [PEP 790](https://peps.python.org/790)
- [Python 3.15 stable set for Oct 9](https://www.warp2search.net/story/python-3150rc3-release-candidate-announced-stable-release-set-for-october-9-2026/)
- `gh release list` for helm/helm, chart-testing, helm-unittest, kubeconform, helm-diff, cosign

### Critical Files for Implementation
- /home/rsedor/Dev/datamesh-reference-arch-python/examples/lgtm-datamesh/services/shipping-service/app/main.py (plus config.py, db.py)
- /home/rsedor/Dev/observability-python-otel-lgtm/services/common/obs/otel.py (plus kafka.py, kafka_propagation.py, services/Containerfile)
- /home/rsedor/Dev/datamesh-reference-arch-python/examples/lgtm-datamesh/charts/capstone/charts/{postgres,kafka,shipping-service}/templates/
- /home/rsedor/Dev/modernizing-enterprise-applications/examples/06-shipping-service/src/main/resources/db/migration/V1__create_shipments_table.sql (plus Shipment.java, ShipmentDispatched.java)
- /home/rsedor/Dev/patterncatalyst-workshops-tutorials-list/scripts/gen-books.py (plus _data/books.yml, _data/book_categories.yml, _data/sites.yml, CLAUDE.md)
- /home/rsedor/.claude/skills/lgtm-minikube-stack/templates/bootstrap.sh.template (plus setup-profile, setup-postgres-operator, setup-kafka-operator, setup-lgtm.sh)
- /home/rsedor/.claude/skills/lgtm-tutorial/references/chapter-template.md and /home/rsedor/.claude/skills/lgtm-jekyll/assets/site-template/

## User decisions (2026-10-08)
1. Base image: UBI10 ubi-minimal + uv-installed CPython 3.15.0; fallbacks F1 (3.14 same build) then F2 (ubi9/python-314), recorded, never silent. No Docker Hub python base.
2. Helm 4 installed project-local under `.tools/`; global `~/.local/bin/helm` (3.18.3) untouched.
3. Publishing (S12, re-confirm before running): public repo `patterncatalyst/helm-for-developers`, GitHub Pages, hub change via PR.
4. Plan approved; execution started.

## Step status
| Step | Status |
|---|---|
| S1 | done |
| S2 | done |
| S3 | done (F1: Python 3.14) |
| S4 | done |
| S5 | done (7/7 met) |
| S6.0–S6.8 | done (+ repair pass) |
| S7 | done (minikube; ch27 verified on CRC, see _plans/claims/s7-d.md) |
| S8a/S8b | pending |
| S9 | done (hub branch, not pushed) |
| S10 | pending |
| S11 | pending |
| S12 | gated |

## Plan change (2026-10-08): CRC available on the authoring machine
OpenShift Local 2.64.0 (OpenShift 4.22.14) and `oc` 4.22.17 installed in `~/.local/bin`; `crc config`: preset openshift, memory 20480, cpus 6, disk 80, pull secret from ~/Downloads. User runs `crc setup` (sudo). Ch27 is now verified live in the **last phase**: after S7b/S7c finish, stop minikube `helm4dev` (no delete) to free memory, `crc start`, run `examples/27-openshift-crc/verify-crc.sh`, promote ch27 with evidence, drop the "untested on the authoring machine" banners in ch27, its README, and the 201 deck.
