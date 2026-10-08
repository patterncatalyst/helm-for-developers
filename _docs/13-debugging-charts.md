---
title: "Debugging charts"
order: 13
part: "Debugging and testing"
description: "A ladder of checks from helm lint --strict to a server-side dry run, with kubeconform, helm diff and helm get manifest, applied to a chart with five planted faults."
duration: 40 minutes
---

Chapter 12 ended with failures that only show up at install time. Most chart bugs do not need a cluster to find: they are schema errors, template errors, invalid YAML, deprecated APIs and wrong field types, and each one has a cheaper check than `helm install`. This chapter orders those checks into a ladder, runs every rung against a chart with five planted faults, and shows which rung catches which fault.

The code is in `examples/13-debugging/`. Run it with `cd examples/13-debugging && ./demo.sh offline`; the no-argument run adds the cluster-side rungs in namespace `hfd-13`.

{% include excalidraw.html
   file="13-debug-ladder"
   alt="Diagram of the debug ladder: four rungs that need no cluster (helm lint --strict, helm template --debug --show-only, kubeconform, helm diff local) lead to three rungs that need a cluster (--dry-run=server, helm diff upgrade, helm get manifest)"
   caption="Figure 13.1 — The debug ladder: cheap local checks first, API-server checks last" %}

## The ladder

Each rung answers a different question, and a fault that slips past one is usually caught by the next.

| Rung | Command | Catches |
|---|---|---|
| 1 | `helm lint --strict` | Values that break `values.schema.json`, YAML that does not parse, deprecated APIs (a warning that `--strict` turns into a failure) |
| 2 | `helm template --debug --show-only` | Template execution errors; the rendered text of one file |
| 3 | `kubeconform` | Wrong field names and types, and custom resources when given their CRD schemas |
| 4 | `helm diff local` | What a values or template change does to the output |
| 5 | `--dry-run=server`, then `kubectl apply --server-side --dry-run=server` | Unknown kinds and `lookup` results (Helm); field types and admission (kubectl) |
| 6 | `helm diff upgrade` | The change against the live release |
| 7 | `helm get manifest` | What the cluster was sent, to feed back into kubeconform |

Helm 4 spells the dry-run flag `--dry-run=none|client|server` on `install` and `upgrade` and `client|server` on `template`. `client` renders locally and never contacts the cluster. `server` connects to the cluster: it resolves every kind against the API server's discovery data and runs `lookup`. On Helm 4.3.0 it does not submit the objects for schema validation (observed below), so it catches an unknown kind but not a string `containerPort`. A bare `--dry-run` means `client` on `template`. The flag set is in the [helm install](https://helm.sh/docs/helm/helm_install/) and [helm template](https://helm.sh/docs/helm/helm_template/) references, and the release changes are summarized in the [Helm 4 announcement](https://helm.sh/blog/helm-4-released/).

## How the code works

The example holds three charts. `charts/shipping-service` is the chart from chapter 12 with no unit tests yet (those arrive in chapter 14), `charts/shipping-postgres` renders one CloudNativePG `Cluster`, and `broken/shipping-service` is a copy of the first with five faults, each isolated in one file.

### Rungs 1 and 2: lint and render

`helm lint --strict` loads the chart, validates the merged values against `values.schema.json`, renders every template, parses the output as YAML, and checks each manifest against Helm's list of deprecated APIs. Without `--strict`, warnings print and the exit code stays 0. With it, a warning fails the run, which is what a CI job needs.

`helm template --debug --show-only templates/configmap.yaml` renders one file. `--show-only` takes the path as Helm names it in `# Source:` comments, and a path that matches no template is an error. In Helm 4, `--debug` also turns on `slog` output on stderr, so the demo discards stderr and keeps the manifest:

```bash
helm template shipping charts/shipping-service --show-only templates/configmap.yaml --debug 2>/dev/null
```

The `--debug` flag has one more job: when the rendered text is not valid YAML, `template` refuses to print it, and `--debug` prints the text anyway so you can see where the indentation went wrong.

### Rung 3: kubeconform with CRD schemas

kubeconform validates rendered manifests against JSON Schemas. The built-in locations cover core Kubernetes kinds. A custom resource needs a second location, and the [datree CRDs-catalog](https://github.com/datreeio/CRDs-catalog) publishes one schema per CRD. The demo's `kc` function wraps the flags:

```bash
kubeconform -strict -summary -kubernetes-version 1.34.0 -cache "$SCHEMA_CACHE" \
    -schema-location default -schema-location "$CRD_CATALOG"
```

`-strict` rejects fields the schema does not define, which is how a misspelled key surfaces. `-kubernetes-version` pins the schema set so results do not move when the schemas do. `-cache` keeps downloaded schemas between runs. `-schema-location default` must be repeated when you add another location, because adding one replaces the default list. `$CRD_CATALOG` is the catalog's URL template, `.../main/{% raw %}{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}{% endraw %}.json`. Without it, a `Cluster` fails with `could not find schema for Cluster`, and `-ignore-missing-schemas` would skip it silently, which hides exactly the resources you wrote.

### Rung 4: helm diff local

Helm 4 runs the `helm-diff` plugin at version 3.15.15 as a legacy-format plugin; `helm plugin list` shows `diff 3.15.15 cli/v1 legacy`. `helm diff local CHART1 CHART2` renders both directories and diffs the output, so a values edit can be previewed with no release and no cluster:

```bash
helm diff local charts/shipping-service /tmp/changed
```

### The five faults

`demo.sh` copies `broken/shipping-service` to a temporary directory and runs a ladder: each stage asserts the current failure message, applies a one-line fix, and moves on. The faults are ordered so that each fix reveals the next.

| # | File | Fault | First caught by |
|---|---|---|---|
| 1 | `values.yaml` | `replicaCount: "1"` (a string) | `helm lint --strict`, `helm template` |
| 2 | `templates/configmap.yaml` | `.Values.logging.level`; no `logging` key exists | `helm template` |
| 3 | `templates/service.yaml` | `indent 4` where `nindent 4` is needed | `helm template`, `helm lint` |
| 4 | `templates/pdb.yaml` | `apiVersion: policy/v1beta1` | `helm lint --strict` only |
| 5 | `templates/deployment.yaml` | `containerPort: {% raw %}{{ .Values.containerPort | quote }}{% endraw %}` | `kubeconform` only |

Schema validation runs before rendering, so fault 1 hides everything else. Fault 2 shows how Helm reports an `include` chain: the error starts at `deployment.yaml:1:18`, which is the `include` that renders the ConfigMap for the checksum annotation, and ends at `configmap.yaml:11:23`, the line that holds the bad lookup. Read an error from the bottom: the last frame is the cause.

Fault 3 is a common mistake. `indent` does not add a leading newline, so the first label lands on the `labels:` line and the rest of the block is indented under a scalar. `helm template --show-only templates/service.yaml --debug` prints `labels:    helm.sh/chart: shipping-service-0.13.0`, which makes the problem visible.

Fault 4 passes plain `helm lint` with one `[WARNING]` and exit code 0. Only `--strict` fails it. Fault 5 passes lint and render, because `quote` is valid in a template and `containerPort: "8080"` is valid YAML. Only a schema that says `containerPort` is an integer rejects it.

## Build, run, observe

```bash
cd examples/13-debugging && ./demo.sh offline
```

The demo needs network access to fetch kubeconform schemas on the first run. Observed output from the ladder:

```text
--- fault 1: values violate values.schema.json (lint and template stop before rendering)
[ERROR] values.yaml: - at '/replicaCount': got string, want integer
--- fault 2: a nil pointer in a template (the error names the file and line)
    nil pointer evaluating interface {}.level
--- fault 3: valid template, invalid YAML after rendering
Error: YAML parse error on shipping-service/templates/service.yaml: error converting YAML to JSON: yaml: line 5: mapping values are not allowed in this context
--- fault 4: lint passes, lint --strict fails on a deprecated API
[WARNING] templates/pdb.yaml: policy/v1beta1 PodDisruptionBudget is deprecated in v1.21+, unavailable in v1.25+; use policy/v1 PodDisruptionBudget
--- fault 5: lint and template pass, kubeconform rejects a string containerPort
... at '/spec/template/spec/containers/0/ports/0/containerPort': got string, want integer
```

The cluster half of `./demo.sh` builds the image, installs the release, and then runs rungs 5 to 7. It first shows what `--dry-run=server` catches. A template that renders a `Widget` of an unknown API group renders fine under `helm template` and fails at the cluster:

```text
Error: UPGRADE FAILED: resource mapping not found for name: "x" namespace: "" from "": no matches for kind "Widget" in version "example.com/v1"
ensure CRDs are installed first
```

A string `containerPort` passes both Helm dry-runs on Helm 4.3.0. The API server's own server-side dry-run, fed the rendered manifest, rejects it:

```text
Error from server: failed to create typed patch object (hfd-13/shipping-shipping-service; apps/v1, Kind=Deployment): .spec.template.spec.containers[name="shipping-service"].ports[containerPort="8080",protocol="TCP"].containerPort: expected numeric (int or float), got string
```

Then the remaining rungs:

```bash
helm template shipping charts/shipping-service -n hfd-13 | kubectl -n hfd-13 apply --server-side --dry-run=server -f -
helm diff upgrade shipping charts/shipping-service -n hfd-13 --set replicaCount=2
helm get manifest shipping -n hfd-13 | kubeconform -strict -summary
```

Helm 4 verifies plugin installs by default, so `scripts/install-tools.sh` installs the pinned `helm-diff` and `helm-unittest` from their git URLs with `--verify=false`; see [the plugin docs](https://helm.sh/docs/topics/plugins/).

## Common errors

| Message | Meaning and fix |
|---|---|
| `values don't meet the specifications of the schema(s)` | A value broke `values.schema.json`; the line after names the JSON pointer. |
| `nil pointer evaluating interface {}.x` | `.Values.a.x` where `a` is missing. Guard with `with`, `default (dict)` or `dig`. |
| `YAML parse error on ...: mapping values are not allowed` | `indent` instead of `nindent`, or a missing `-` chomp. Re-run with `--debug`. |
| `could not find template templates/x.yaml in chart` | `--show-only` path is wrong, or `.helmignore` removed the file (see chapter 14). |
| `execution error at (...): <your message>` | A `required` or `fail` call fired. The text after the colon is yours. |
| `context deadline exceeded` | `--wait` timed out; the chart rendered fine. Look at pod events, not the template. Seen together with `Pending termination: 1` on a bad-tag upgrade. |
| `Pending termination: 1` after a bad upgrade | The new pod never became ready. `kubectl describe pod` shows the real cause, such as `ImagePullBackOff`. |

## Cross-check

Two independent checks agree on the fixed chart. After the five fixes, `diff -rq` between the good chart and the repaired copy reports only `Only in .../templates: pdb.yaml`, so no fix changed behavior. With the release installed, `helm get manifest shipping -n hfd-13` and `helm template shipping charts/shipping-service` should list the same resources, and kubeconform accepts both.

## What you learned

- Order checks by cost: lint, render, schema, local diff, then the API server.
- `helm lint --strict` turns deprecated-API warnings into failures; `--debug` shows rendered text that failed to parse.
- kubeconform needs `-schema-location default` plus the CRDs-catalog URL template to validate custom resources, and a pinned `-kubernetes-version`.
- `--dry-run=client` never contacts the cluster; `--dry-run=server` resolves kinds and `lookup` against the cluster but, on Helm 4.3.0, does not validate field types; pipe `helm template` into `kubectl apply --server-side --dry-run=server` for that.
- `helm diff local` previews changes offline, and `helm diff upgrade` compares against the live release.

Chapter 14 turns these one-off checks into repeatable ones: unit tests, `helm test` and a CI workflow.

## Further reading

- [helm template](https://helm.sh/docs/helm/helm_template/) and [helm install](https://helm.sh/docs/helm/helm_install/) for the `--dry-run` values.
- [helm lint](https://helm.sh/docs/helm/helm_lint/) for `--strict`, and [Debugging templates](https://helm.sh/docs/chart_template_guide/debugging/).
- [Helm 4 announcement](https://helm.sh/blog/helm-4-released/) and [v4.0.0 release notes](https://github.com/helm/helm/releases/tag/v4.0.0).
- [helm-diff](https://github.com/databus23/helm-diff), [kubeconform](https://github.com/yannh/kubeconform) and the [datree CRDs-catalog](https://github.com/datreeio/CRDs-catalog).

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/13-debugging.txt`. Observed on Helm 4.3.0 against minikube: `helm diff upgrade` showed the `replicaCount` and `LOG_LEVEL` changes, `helm get manifest` passed kubeconform and listed the same resources as `helm template`, a bad-tag `--wait` upgrade printed `Pending termination: 1` and `context deadline exceeded`, and the string `containerPort` passed both Helm dry-runs but failed `kubectl apply --server-side --dry-run=server`.*
