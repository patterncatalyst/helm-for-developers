---
title: "Outline"
order: 0
part: "Getting started"
description: "The nine parts and thirty-one chapters, and how one application grows from raw manifests into a signed, GitOps-delivered chart."
duration: 10 minutes
---

This tutorial teaches Helm 4 by building one application in the open. The application is fixed from the first chapter: a **shipping-service** (REST API, Postgres, Kafka producer) and a **notification-service** (Kafka consumer), both Python 3.15 and FastAPI, built once into UBI 10 images. Feature flags in the services switch storage, messaging and telemetry on or off. Because the image never changes, every chapter changes only charts and values, and every chapter is about Helm.

Each hands-on chapter has an `examples/NN-slug/` directory. The directory is a self-contained snapshot of the charts at that step, with a `demo.sh` that supports three modes: no argument for the full run, `offline` for lint, template, unit tests and kubeconform only, and `clean` to uninstall.

{% include excalidraw.html
   file="00-build-up-arc"
   alt="Diagram of the build-up arc: raw manifests become a chart, then a chart with a Postgres subchart, an umbrella with Kafka and a library chart, and finally a signed OCI artifact delivered by Argo CD"
   caption="Figure 0.1 — The build-up arc from raw manifests to GitOps delivery" %}

## Chapters

| Part | # | Chapter |
|---|---|---|
| **Getting started** | 00 | Outline |
| | 01 | Prerequisites and lab setup |
| | 02 | A tour of Helm 4 |
| **From manifests to a chart** | 03 | The shipping service as raw manifests |
| | 04 | Your first chart |
| | 05 | Values and overrides |
| | 06 | Templates |
| | 07 | Helpers and NOTES.txt |
| | 08 | Configuration and secrets |
| **Data and lifecycle** | 09 | Dependencies and a Postgres subchart |
| | 10 | CRDs and operators |
| | 11 | Hooks and database migrations |
| | 12 | The release lifecycle |
| **Debugging and testing** | 13 | Debugging charts |
| | 14 | Chart testing |
| **Multi-service applications** | 15 | Kafka and the notification service |
| | 16 | Umbrella charts |
| | 17 | Library charts |
| | 18 | Starters and golden paths |
| **Distribution and supply chain** | 19 | Packaging and repositories |
| | 20 | OCI registries |
| | 21 | Provenance and signing |
| **Extending Helm** | 22 | Plugins |
| | 23 | Post-renderers |
| **Delivery and operations** | 24 | Environment promotion |
| | 25 | GitOps with Argo CD |
| | 26 | Observability with the LGTM stack |
| **Appendices** | 27 | Appendix: OpenShift Local |
| | 28 | Appendix: Helm 3 to Helm 4 |
| | 29 | Appendix: Cheat sheet |
| | 30 | Appendix: Further reading |

## Progressive build-up

Chart versions are `0.<chapter>.0` per snapshot until chapter 19 releases `1.0.0`. `appVersion` is `0.1.0` throughout.

| Chapter | What the chart set contains after it | New Helm capability |
|---|---|---|
| 02 | A public chart (podinfo) installed from OCI | Install, list, status, uninstall |
| 03 | Raw Deployment, Service and ConfigMap, no chart | The problem Helm solves |
| 04 | `shipping-service` chart, in-memory storage | Chart anatomy, upgrade, rollback, release storage |
| 05 | Values with schema, environment overrides | Precedence, `--set*` flags, `values.schema.json` |
| 06 | Templated Deployment, Service, ConfigMap | Go templates, Sprig, flow control, `tpl`, `required` |
| 07 | `_helpers.tpl`, recommended labels, NOTES.txt | Named templates, `include` |
| 08 | ConfigMap and Secret with checksum rollout | Rollout on config change, `existingSecret`, `lookup` |
| 09 | `shipping-postgres` subchart (CloudNativePG `Cluster`) | Dependencies, `condition`, `import-values`, `global` |
| 10 | Demo CRD in `crds/`, capability guard | `crds/` semantics, `.Capabilities` |
| 11 | Migration Job as a `pre-install,pre-upgrade` hook | Hooks, weights, delete policies |
| 12 | Same chart, driven through failure paths | `--wait`, `--rollback-on-failure`, server-side apply |
| 13 | Same chart, debugged | `lint --strict`, dry-run, `helm diff`, kubeconform |
| 14 | `templates/tests/`, helm-unittest suites, `ci/` values | `helm test`, chart-testing |
| 15 | `shipping-kafka` subchart (Strimzi) and `notification-service` | Multiple application charts |
| 16 | `shipping-platform` umbrella | `alias`, `tags`, `global`, ordering limits |
| 17 | `pc-lib` library chart consumed by both services | `type: library` |
| 18 | `pc-fastapi` starter | `helm create --starter` |
| 19 | Packaged `1.0.0`, served from a classic repository | `helm package`, `helm repo index`, SemVer |
| 20 | The same package in an OCI registry | `helm push`, `helm pull`, install by digest |
| 21 | Signed package and signed OCI artifact | `.prov`, `helm verify`, cosign |
| 22 | `helm shipping-env` and a Wasm plugin | Helm 4 plugin types and runtimes |
| 23 | `kustomize-postrender` plugin | `postrenderer/v1` |
| 24 | `values-dev`, `values-stage`, `values-prod` | Layering and promotion by version bump |
| 25 | Argo CD `Application` pointing at the OCI chart | Helm under GitOps |
| 26 | OTLP environment, Grafana dashboard ConfigMap | Library-driven telemetry |
| 27 | `values-openshift.yaml`, Route template | Capability-gated resources, restricted-v2 SCC |

## Reading order

Chapters 01 to 12 are the core and should be read in order. Chapters 13 and 14 apply to any chart. Chapters 15 to 18 build on the Postgres work in chapter 09. Chapters 19 to 21 need the umbrella chart from chapter 16. Chapters 22 and 23 are independent of the delivery chapters. Chapter 27 repeats the umbrella deployment on OpenShift Local and was not run on the authoring machine.

## Verification status

Every chapter ends with a verification footer. A chapter is marked `verified` only after its example has run against a live cluster and the observed effect is recorded as evidence in the repository.
