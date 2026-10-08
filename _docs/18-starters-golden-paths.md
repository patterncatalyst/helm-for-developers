---
title: "Starters and golden paths"
order: 18
part: "Multi-service applications"
description: "Scaffold a new service chart from a pc-fastapi starter with helm create --starter, handle the rewritten Chart.yaml, and see the starter as one step of a golden path."
duration: 35 minutes
---

The library from chapter 17 makes a service chart small. A starter makes it small from the first command: `helm create --starter` copies a prepared chart into a new directory and fills in the chart's name. This chapter builds the `pc-fastapi` starter, runs it, and deals with the one place where Helm's scaffolding gets in the way.

The code is in `examples/18-starters/`. The `demo.sh` there installs and runs it; its `README.md` covers what it does and how to drive it.

{% include excalidraw.html
   file="18-starter-flow"
   alt="Diagram: helm create --starter copies the pc-fastapi starter from the Helm data directory into charts/inventory-service, rewrites Chart.yaml, replaces the chart name placeholder and also copies pc-lib-dependency.yaml, which is appended to Chart.yaml before helm dependency build packs pc-lib"
   caption="Figure 18.1 — From starter to a buildable chart" %}

## How starters work

A starter is a chart directory in which the literal string `<CHARTNAME>` stands for the new chart's name. `helm create NAME --starter STARTER` copies the starter into `NAME`, replaces every `<CHARTNAME>` with the chart name, and writes a fresh `Chart.yaml`. `STARTER` is either an absolute path or a name that Helm looks up in `$HELM_DATA_HOME/starters`. In this repository `scripts/env.sh` puts `HELM_DATA_HOME` under `.tools/helm/data`, so the lab never touches `~/.local/share/helm` ([helm create reference](https://helm.sh/docs/helm/helm_create/)).

## How the code works

**What the starter contains.** `pc-fastapi` is a chart with no business logic: `values.yaml` and `values.schema.json` for the keys pc-lib reads, a Deployment and Service template of one line each, a `_helpers.tpl` with the environment variables every FastAPI service sets, `NOTES.txt`, a test pod and `ci/ci-values.yaml`. The Deployment template is the pc-lib call from chapter 17 with the chart name as a placeholder:

{% raw %}
```yaml
{{- include "pc-lib.deployment" (dict "root" . "env" (include "<CHARTNAME>.env" .)) }}
```
{% endraw %}

After `helm create`, the placeholder in that line, in the `env` helper's `define`, and in `values.yaml` (`image.repository: <CHARTNAME>`) reads `inventory-service`. The `env` helper emits `SERVICE_NAME`, `SERVICE_VERSION`, `DEPLOY_ENV` and `LOG_LEVEL`, then includes `pc-lib.otelEnv`. A team adds its own variables below those lines.

**Installing a starter.** There is no `helm starter install` command; a starter is a directory you place. The demo copies `charts/starters/pc-fastapi` to `$HELM_DATA_HOME/starters/pc-fastapi`, after which `helm create --starter pc-fastapi NAME` finds it by name. Passing an absolute path to the directory works the same way and needs no installation, which is how the starter's own README invokes it. A team usually distributes starters in a platform repository and copies them into place from a bootstrap script, the way `scripts/env.sh` already isolates every other piece of Helm state here.

**Writing a starter.** Start from a chart that already passes `helm lint --strict` and renders correctly, then replace the chart name with `<CHARTNAME>` everywhere it appears: template names, `define` blocks, image repository, labels. Helm substitutes text and does not understand templates, so a replaced name inside a `define` stays consistent only if every use was replaced. Test the result by generating a chart from it, which `demo.sh` does on every run. Anything the generated chart needs that `Chart.yaml` would carry, `dependencies` above all, goes in a sibling file.

**The `Chart.yaml` problem.** A starter's `Chart.yaml` is not copied; Helm writes its own, so the `dependencies:` block you put there never arrives. The scaffolded file from the demo run:

```yaml
apiVersion: v2
appVersion: 0.1.0
description: A Helm chart for Kubernetes
name: inventory-service
type: application
version: 0.1.0
```

The starter therefore ships the block as a second file, `pc-lib-dependency.yaml`, which `helm create` copies like any other. Appending it is the second step of the workflow:

```bash
helm create --starter pc-fastapi charts/inventory-service
cat charts/inventory-service/pc-lib-dependency.yaml >> charts/inventory-service/Chart.yaml
helm dependency build charts/inventory-service
```

The path in the block is `file://../pc-lib`, so create the chart as a sibling of `pc-lib`. Skip the append and rendering fails because `pc-lib.fullname` is not defined; the demo shows that error before it fixes it. The file can be deleted once it has been appended. The starter's README records the same three commands, so the knowledge travels with the starter.

**What the starter fixes for the reader.** Every generated chart already has the OpenShift-safe security context, the three probes, a schema with `additionalProperties: false`, a `helm test` pod and a `ci/` values file. The test pod uses the chart's own image (`tests.image: ""`) with a Python probe, because a `ubi-minimal` image running `curl` has no numeric user and fails the `runAsNonRoot` check. The service team's first commit touches `values.yaml` and the `env` helper only.

**The values a new team edits.** `values.yaml` in the starter is the whole configuration surface: `replicaCount`, `image`, `service` (type, port, optional `nodePort`), `config.environment` and `config.logLevel`, `otel`, `dataProduct` (domain, owner and name, with placeholder values `example` and `team-example` that a team must replace), `resources`, `probes` and `tests`. The schema constrains the enums, so `logLevel: LOUD` or a `nodePort` outside 30000 to 32767 fails `helm lint` at once. The `dataProduct` defaults are obvious placeholders; a catalog query for the domain `example` finds the services that forgot to claim ownership.

**What is fragile.** Starters are copied, not linked. A fix to the starter does not reach charts generated last month, which is why the substantive logic sits in pc-lib and the starter stays thin. The version in `pc-lib-dependency.yaml` is also a literal, so bump it with the library.

## Golden paths

A golden path is the supported, pre-wired route to a working service: use these tools, these defaults and this template, and the platform's checks pass without extra work. The starter is the chart step of that path. The library supplies the behavior, the starter supplies the first commit, and the schema and `ci/` values supply the guardrails. A path works when it is the easiest option, not when it is mandatory; a team with unusual needs can still hand-write a chart and give up the shared fixes. Chapter 24 and the platform books cited below cover the other steps (promotion, delivery).

Three practical rules keep a path from turning into a mandate. Version it: the starter and the library carry numbers, and a service records which it was built from. Make the checks automatic: the schema, `helm lint --strict`, the unit tests and chart-testing from chapter 14 run in CI, so a service that stays on the path gets feedback automatically. And measure the path by use: if teams keep hand-writing charts, the starter is missing something they need.

## Build, run, observe

```bash
cd examples/18-starters && ./demo.sh
```

The script installs the starter into `$HELM_DATA_HOME/starters`, runs `helm create --starter pc-fastapi` in a temporary directory beside a copy of pc-lib, appends the dependency, builds, lints with `--strict`, renders and validates with kubeconform. The rendered Service is `shipping-inventory-service` (release `shipping`) and the image is `inventory-service:0.1.0`. The full run installs the chart into `hfd-18` using the shipping image under the new name, which exercises the chart wiring only. `./demo.sh clean` removes the starter again.

To see how a change to the starter flows through, edit `charts/starters/pc-fastapi/values.yaml`, run `./demo.sh offline`, and compare the rendered image and annotation lines in the output. The script copies the starter on every run, so a stale copy in `$HELM_DATA_HOME/starters` never masks the edit. The generated chart exists only in a temporary directory; to keep one, run the three commands from the previous section yourself in `charts/`.

## Cross-check

`helm lint --strict` on the scaffolded chart and `kubeconform` on its rendered output both pass, and `grep -rl '<CHARTNAME>' charts/inventory-service` lists only the starter's `README.md`, where the text describes the placeholder. A leftover placeholder anywhere else means a starter file used a different spelling.

## What you learned

- `helm create --starter` copies a chart, substitutes `<CHARTNAME>`, and rewrites `Chart.yaml`.
- A dependency block cannot ride in the starter's `Chart.yaml`; ship it as `pc-lib-dependency.yaml` and append it.
- A starter is one step of a golden path; the shared behavior belongs in the library.

Chapter 19 packages these charts as `1.0.0` and serves them from a repository.

## Further reading

- Chankramath et al., *Effective Platform Engineering* (Manning, 2025), ISBN 9781633436497. Used here for: golden paths and self-service templates as platform products.
- Mauricio Salatino, *Platform Engineering on Kubernetes* (Manning, 2024), ISBN 9781617299322. Used here for: platform capabilities that give teams a paved route to a running service.

---

*Verification status: <span class="status status--unverified">unverified</span>. A live run must confirm that the chart generated from the starter installs and that its `helm test` pod passes against the shipping image.*
