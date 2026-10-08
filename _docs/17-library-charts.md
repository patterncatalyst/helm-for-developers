---
title: "Library charts"
order: 17
part: "Multi-service applications"
description: "Move the helpers and templates the service charts copy into a pc-lib library chart, and prove the refactor by diffing rendered manifests."
duration: 40 minutes
---

The two service charts from chapter 16 carry the same 140 lines of helpers: names, labels, image, probes, security context, OpenTelemetry environment, and the Deployment and Service skeletons. Fixing a probe means editing both and hoping they stay in step. A library chart moves that code into one place. This chapter extracts `pc-lib` and proves the refactor changed nothing by diffing what both versions render.

The code is in `examples/17-library-chart/`. The `demo.sh` there installs and runs it; its `README.md` covers what it does and how to drive it.

{% include excalidraw.html
   file="17-library-reuse"
   alt="Diagram: the pc-lib library chart holds the deployment, service, labels, fullname, probes, image, security, otelEnv and metadataAnnotations templates; shipping-service, notification-service and a future starter chart each include them"
   caption="Figure 17.1 — One library chart, many consumers" %}

## What a library chart is

A chart with `type: library` in `Chart.yaml` contains only named templates. It has no `values.yaml` of its own, renders nothing, and cannot be installed:

```text
Error: library charts are not installable
```

Consumers declare it as a dependency and call its templates with `include`. The templates run in the consumer's context, so `.Values`, `.Release` and `.Chart` are the consumer's. Template files in a library start with an underscore so Helm does not try to render them as manifests. Because `.Chart` is the consumer's, `pc-lib.chart` yields `notification-service-0.17.0`, not a `pc-lib` label, and `pc-lib.fullname` follows the consumer's release and alias, so the object names do not change when a service moves onto the library. That is also why the unit tests of the service charts keep passing without edits: they assert rendered output, and the output is the same. Library charts are an established Helm 3 feature that Helm 4 left unchanged ([library charts](https://helm.sh/docs/topics/library_charts/)).

## The refactor in five steps

1. Create `charts/pc-lib` with `type: library` and move each helper block into an underscore-prefixed file, renaming the template prefix from `shipping-service.` to `pc-lib.`.
2. Turn the Deployment and Service manifests into `define` blocks that take a dict, as shown below.
3. Add `pc-lib` to each consumer's `dependencies` and delete the copied helpers, keeping only the chart-specific ones.
4. Run `helm dependency build` in each consumer.
5. Render the old and new chart with the same values and diff.

Template names are global across a chart and all its subcharts, so a library prefixes every name with its own (`pc-lib.`). Two charts that both defined `fullname` would silently overwrite one another, which is one reason the copies in chapter 16 are named per chart.

## How the code works

**The library.** `pc-lib/Chart.yaml` is four lines plus `type: library`. Its templates are split by concern:

| File | Defines |
|---|---|
| `_labels.tpl` | `pc-lib.name`, `pc-lib.fullname`, `pc-lib.chart`, `pc-lib.selectorLabels`, `pc-lib.labels` |
| `_image.tpl` | `pc-lib.image`: `[global.imageRegistry/]repository:tag`, tag defaults to `.Chart.AppVersion` |
| `_probes.tpl` | `pc-lib.probes`: startup, liveness and readiness probes from `.Values.probes` |
| `_security.tpl` | pod and container security contexts: non-root, no `runAsUser`, drop ALL, seccomp default |
| `_otel.tpl` | `pc-lib.otelEnv`: SDK on only when an endpoint exists |
| `_metadata.tpl` | `pc-lib.metadataAnnotations`: data-product annotations |
| `_deployment.tpl`, `_service.tpl` | the two manifests |

**Data-product annotations.** `_metadata.tpl` turns `.Values.dataProduct` into `patterncatalyst.io/domain`, `patterncatalyst.io/owner` and `patterncatalyst.io/data-product` on the Deployment, the pod template and the Service. The idea comes from data-mesh practice: every deployable unit states which domain owns it and what product it serves, so a catalog or a cost report can group workloads without a spreadsheet. Because the annotation logic now lives in the library, a new service gets it by filling three values.

**One argument, many inputs.** A named template takes one argument, so `pc-lib.deployment` takes a dict:

{% raw %}
```yaml
{{- include "pc-lib.deployment" (dict
    "root" .
    "env" (include "notification-service.env" .)
    "envFrom" (printf "- configMapRef:\n    name: %s" (include "pc-lib.fullname" .))
    "podAnnotations" (dict "checksum/config" $configSum)) }}
```
{% endraw %}

`root` is the consumer's context. `env` and `envFrom` are YAML list strings the consumer builds, because only the consumer knows its variables. `podAnnotations` carries the `checksum/config` hash, which has to be computed in the consumer because it hashes the consumer's ConfigMap. The line before it in `deployment.yaml` computes `$configSum` with `include (print $.Template.BasePath "/configmap.yaml")`. Inside `_deployment.tpl` the first line is {% raw %}`{{- $root := .root -}}`{% endraw %}, and every helper call passes `$root`, not `.`: in a template called with a dict, `.` is the dict.

**The consumer's side.** notification-service declares the library like any other dependency:

```yaml
dependencies:
  - name: pc-lib
    version: 0.17.0
    repository: file://../pc-lib
```

`helm dependency build` packs `charts/pc-lib-0.17.0.tgz` and writes `Chart.lock`. The umbrella then packs each service together with its own `charts/pc-lib` copy, so the umbrella's dependency list does not change at all: a refactor inside a service is invisible one level up. `helm dependency list charts/shipping-service` reports the library as `ok` once the tarball matches the lock. Because the library sits two levels below the umbrella, the services must be built before the umbrella, which is the order `demo.sh` uses.

**Everything else is a one-liner.** `service.yaml` is the single line `{% raw %}{{ include "pc-lib.service" . }}{% endraw %}`. Labels, names and security contexts are called wherever a manifest needs them, including the migration Job and the test pod. What stays in each service chart is what differs: `shipping-service.env` builds the Postgres, Kafka and token variables and `notification-service.env` builds one Kafka address.

**What belongs in the library.** Put in code that every service must do identically and that a platform team wants to change in one place: names, labels, probes, security context, telemetry, ownership metadata. Leave out anything that encodes a service's behavior, such as which environment variables it needs or whether it has a migration Job. If a helper grows a flag for each consumer, it is application code placed in a library and belongs back in the consumer. The line between the two is the main design decision in a library chart, and it is easier to move a helper into the library later than to remove one every consumer already calls.

**Versions.** The consumers depend on `pc-lib` at an exact version with `repository: file://../pc-lib`. The chart version is public API: renaming `pc-lib.fullname` breaks every consumer, so that is a major bump, while a new optional helper is a minor one. After editing the library, run `helm dependency build` in each consumer again; the consumer renders the packed copy in its `charts/` directory.

**What is fragile.** The helpers read fixed value keys (`image`, `probes`, `service`, `dataProduct`, `otel`, `resources`, `containerPort`). A consumer that renames one gets a nil-pointer error at render time. The library documents its contract in comments only, and the consumer schemas, which set `additionalProperties: false`, are where those keys are enforced.

## Build, run, observe

```bash
cd examples/17-library-chart && ./demo.sh
```

`charts/` holds the library and its consumers; `before/` holds the chapter 16 versions of both services. `./demo.sh offline` runs 46 unit tests across three charts and prints the size of the change:

```text
  notification-service before: 224 lines   after: 16 lines
  shipping-service     before: 295 lines   after: 87 lines
```

## Cross-check

The refactor claims to change source, not output, so render both and diff. The demo strips two lines that must differ, the `helm.sh/chart` label (it carries the chart version) and the `checksum/config` annotation (it hashes a ConfigMap that contains that label):

```text
  shipping-service: identical
  notification-service: identical
```

An empty diff is a stronger check than the unit tests, because it covers every field of every manifest, including ones no test asserts.

## What you learned

- `type: library` charts hold named templates only and are consumed as dependencies.
- Pass a dict when a template needs more than one input, and call helpers with the saved root context.
- Prove a refactor with a rendered diff, then keep the library's value keys as a versioned contract.

Chapter 18 turns this into a scaffold so the next service starts on the library.

## Further reading

- Matt Butcher, Matt Farina, Josh Dolitsky, *Learning Helm* (O'Reilly, 2021), ISBN 9781492083641. Used here for: library charts and named templates.
- Oliver et al., *Effective Platform Engineering* (Manning, 2025), ISBN 9781633436497. Used here for: shared, opinionated defaults as a platform product.

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/17-library-chart.txt`. Observed on Helm 4.3.0 and minikube: the library-based and copied charts rendered identically apart from the chart label and checksum for both services, with line counts 224 to 16 and 295 to 87; release `platform` installed from the library charts, the shipping and notification Deployments and Services carried `patterncatalyst.io/domain`, `owner` and `data-product`, and `helm test platform` passed.*
