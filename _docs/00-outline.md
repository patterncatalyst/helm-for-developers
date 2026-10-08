---
title: "Outline"
order: 0
part: "Getting started"
description: "The nine parts and thirty-one chapters, and how one application grows from raw manifests into a signed, GitOps-delivered chart."
duration: 10 minutes
---

This tutorial teaches Helm 4 by building one application in the open. The application is fixed from the first chapter: a **shipping-service** (REST API, Postgres, Kafka producer) and a **notification-service** (Kafka consumer), both Python 3.14 (3.15-ready) and FastAPI, built once into UBI 10 images. Feature flags in the services switch storage, messaging and telemetry on or off. Because the image never changes, every chapter changes only charts and values, and every chapter is about Helm.

Each hands-on chapter has an `examples/NN-slug/` directory. The directory is a self-contained snapshot of the charts at that step, with a `demo.sh` that supports three modes: no argument for the full run, `offline` for lint, template, unit tests and kubeconform only, and `clean` to uninstall.

{% include excalidraw.html
   file="00-build-up-arc"
   alt="Diagram of the build-up arc: raw manifests become a chart, then a chart with a Postgres subchart, an umbrella with Kafka and a library chart, and finally a signed OCI artifact delivered by Argo CD"
   caption="Figure 0.1 — The build-up arc from raw manifests to GitOps delivery" %}

## Chapters

| Part | # | Chapter |
|---|---|---|
| **Getting started** | 00 | Outline |
| | 01 | [Prerequisites and lab setup]({{ '/docs/01-prerequisites/' | relative_url }}) |
| | 02 | [A tour of Helm 4]({{ '/docs/02-helm-4-tour/' | relative_url }}) |
| **From manifests to a chart** | 03 | [The shipping service as raw manifests]({{ '/docs/03-shipping-service-raw-manifests/' | relative_url }}) |
| | 04 | [Your first chart]({{ '/docs/04-first-chart/' | relative_url }}) |
| | 05 | [Values and overrides]({{ '/docs/05-values-and-overrides/' | relative_url }}) |
| | 06 | [Templates]({{ '/docs/06-templates/' | relative_url }}) |
| | 07 | [Helpers and NOTES.txt]({{ '/docs/07-helpers-and-notes/' | relative_url }}) |
| | 08 | [Configuration and secrets]({{ '/docs/08-config-and-secrets/' | relative_url }}) |
| **Data and lifecycle** | 09 | [Dependencies and a Postgres subchart]({{ '/docs/09-dependencies-postgres/' | relative_url }}) |
| | 10 | [CRDs and operators]({{ '/docs/10-crds-and-operators/' | relative_url }}) |
| | 11 | [Hooks and database migrations]({{ '/docs/11-hooks-and-migrations/' | relative_url }}) |
| | 12 | [The release lifecycle]({{ '/docs/12-release-lifecycle/' | relative_url }}) |
| **Debugging and testing** | 13 | [Debugging charts]({{ '/docs/13-debugging-charts/' | relative_url }}) |
| | 14 | [Chart testing]({{ '/docs/14-chart-testing/' | relative_url }}) |
| **Multi-service applications** | 15 | [Kafka and the notification service]({{ '/docs/15-kafka-and-notification/' | relative_url }}) |
| | 16 | [Umbrella charts]({{ '/docs/16-umbrella-charts/' | relative_url }}) |
| | 17 | [Library charts]({{ '/docs/17-library-charts/' | relative_url }}) |
| | 18 | [Starters and golden paths]({{ '/docs/18-starters-golden-paths/' | relative_url }}) |
| **Distribution and supply chain** | 19 | [Packaging and repositories]({{ '/docs/19-packaging-and-repos/' | relative_url }}) |
| | 20 | [OCI registries]({{ '/docs/20-oci-registries/' | relative_url }}) |
| | 21 | [Provenance and signing]({{ '/docs/21-provenance-and-signing/' | relative_url }}) |
| **Extending Helm** | 22 | [Plugins]({{ '/docs/22-plugins/' | relative_url }}) |
| | 23 | [Post-renderers]({{ '/docs/23-post-renderers/' | relative_url }}) |
| **Delivery and operations** | 24 | [Environment promotion]({{ '/docs/24-environment-promotion/' | relative_url }}) |
| | 25 | [GitOps with Argo CD]({{ '/docs/25-gitops-argocd/' | relative_url }}) |
| | 26 | [Observability with the LGTM stack]({{ '/docs/26-observability-lgtm/' | relative_url }}) |
| **Appendices** | 27 | [Appendix: OpenShift Local]({{ '/docs/27-appendix-openshift-local/' | relative_url }}) |
| | 28 | [Appendix: Helm 3 to Helm 4]({{ '/docs/28-appendix-helm3-to-helm4/' | relative_url }}) |
| | 29 | [Appendix: Cheat sheet]({{ '/docs/29-appendix-cheat-sheet/' | relative_url }}) |
| | 30 | [Appendix: Further reading]({{ '/docs/30-appendix-further-reading/' | relative_url }}) |

## Progressive build-up

Chart versions are `0.<chapter>.0` per snapshot until chapter 19 releases `1.0.0`. `appVersion` is `0.1.0` throughout.

| Chapter | What the chart set contains after it | New Helm capability |
|---|---|---|
| [02]({{ '/docs/02-helm-4-tour/' | relative_url }}) | A public chart (podinfo) installed from OCI | Install, list, status, uninstall |
| [03]({{ '/docs/03-shipping-service-raw-manifests/' | relative_url }}) | Raw Deployment, Service and ConfigMap, no chart | The problem Helm solves |
| [04]({{ '/docs/04-first-chart/' | relative_url }}) | `shipping-service` chart, in-memory storage | Chart anatomy, upgrade, rollback, release storage |
| [05]({{ '/docs/05-values-and-overrides/' | relative_url }}) | Values with schema, environment overrides | Precedence, `--set*` flags, `values.schema.json` |
| [06]({{ '/docs/06-templates/' | relative_url }}) | Templated Deployment, Service, ConfigMap | Go templates, Sprig, flow control, `tpl`, `required` |
| [07]({{ '/docs/07-helpers-and-notes/' | relative_url }}) | `_helpers.tpl`, recommended labels, NOTES.txt | Named templates, `include` |
| [08]({{ '/docs/08-config-and-secrets/' | relative_url }}) | ConfigMap and Secret with checksum rollout | Rollout on config change, `existingSecret`, `lookup` |
| [09]({{ '/docs/09-dependencies-postgres/' | relative_url }}) | `shipping-postgres` subchart (CloudNativePG `Cluster`) | Dependencies, `condition`, `import-values`, `global` |
| [10]({{ '/docs/10-crds-and-operators/' | relative_url }}) | Demo CRD in `crds/`, capability guard | `crds/` semantics, `.Capabilities` |
| [11]({{ '/docs/11-hooks-and-migrations/' | relative_url }}) | Migration Job as a `pre-install,pre-upgrade` hook | Hooks, weights, delete policies |
| [12]({{ '/docs/12-release-lifecycle/' | relative_url }}) | Same chart, driven through failure paths | `--wait`, `--rollback-on-failure`, server-side apply |
| [13]({{ '/docs/13-debugging-charts/' | relative_url }}) | Same chart, debugged | `lint --strict`, dry-run, `helm diff`, kubeconform |
| [14]({{ '/docs/14-chart-testing/' | relative_url }}) | `templates/tests/`, helm-unittest suites, `ci/` values | `helm test`, chart-testing |
| [15]({{ '/docs/15-kafka-and-notification/' | relative_url }}) | `shipping-kafka` subchart (Strimzi) and `notification-service` | Multiple application charts |
| [16]({{ '/docs/16-umbrella-charts/' | relative_url }}) | `shipping-platform` umbrella | `alias`, `tags`, `global`, ordering limits |
| [17]({{ '/docs/17-library-charts/' | relative_url }}) | `pc-lib` library chart consumed by both services | `type: library` |
| [18]({{ '/docs/18-starters-golden-paths/' | relative_url }}) | `pc-fastapi` starter | `helm create --starter` |
| [19]({{ '/docs/19-packaging-and-repos/' | relative_url }}) | Packaged `1.0.0`, served from a classic repository | `helm package`, `helm repo index`, SemVer |
| [20]({{ '/docs/20-oci-registries/' | relative_url }}) | The same package in an OCI registry | `helm push`, `helm pull`, install by digest |
| [21]({{ '/docs/21-provenance-and-signing/' | relative_url }}) | Signed package and signed OCI artifact | `.prov`, `helm verify`, cosign |
| [22]({{ '/docs/22-plugins/' | relative_url }}) | `helm shipping-env` and a Wasm plugin | Helm 4 plugin types and runtimes |
| [23]({{ '/docs/23-post-renderers/' | relative_url }}) | `kustomize-postrender` plugin | `postrenderer/v1` |
| [24]({{ '/docs/24-environment-promotion/' | relative_url }}) | `values-dev`, `values-stage`, `values-prod` | Layering and promotion by version bump |
| [25]({{ '/docs/25-gitops-argocd/' | relative_url }}) | Argo CD `Application` pointing at the OCI chart | Helm under GitOps |
| [26]({{ '/docs/26-observability-lgtm/' | relative_url }}) | OTLP environment, Grafana dashboard ConfigMap | Library-driven telemetry |
| [27]({{ '/docs/27-appendix-openshift-local/' | relative_url }}) | `values-openshift.yaml`, Route template | Capability-gated resources, restricted-v2 SCC |

## Reading order

Chapters 01 to 12 are the core and should be read in order. Chapters 13 and 14 apply to any chart. Chapters 15 to 18 build on the Postgres work in chapter 09. Chapters 19 to 21 need the umbrella chart from chapter 16. Chapters 22 and 23 are independent of the delivery chapters. Chapter 27 repeats the umbrella deployment on OpenShift Local.

## Verification status

Every chapter ends with a verification footer. A chapter is marked `verified` only after its example has run against a live cluster and the observed effect is recorded as evidence in the repository.
