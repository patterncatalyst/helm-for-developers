---
title: "Helpers and NOTES.txt"
order: 7
part: "From manifests to a chart"
description: "Move repeated names and labels into named templates in _helpers.tpl, apply the recommended Kubernetes labels, and print post-install guidance with NOTES.txt and .Files."
duration: 35 minutes
---

After chapter 06 the chart still spells out the resource name and the same labels in every file. This chapter removes that repetition with named templates, adopts the recommended `app.kubernetes.io/*` labels, and adds a `NOTES.txt` that prints how to reach the service after an install. The new idea is `include`: a named template is a function you define once and call from any file.

The code is in `examples/07-helpers-notes/`. `./demo.sh offline` checks the naming rules and prints the rendered notes without a cluster; `./demo.sh` installs the chart into `hfd-07` and prints them from the release.

{% include excalidraw.html
   file="07-named-templates"
   alt="Diagram: _helpers.tpl defines name, fullname, selectorLabels and labels templates; the configmap, service and deployment templates call them with include"
   caption="Figure 7.1 — One _helpers.tpl defines the names and labels that every template includes" %}

## Named templates

`define "name"` ... `end` creates a template with a global name. Files whose names begin with an underscore, such as `_helpers.tpl`, are loaded as template libraries and never rendered into a manifest, so they can hold definitions without producing output. Because template names are global across the chart and its subcharts, the convention is to prefix each name with the chart name: `shipping-service.fullname`, not `fullname`. Two charts that both define `fullname` would silently overwrite each other (chapter 09 reintroduces this with subcharts).

There are two ways to call one. `{% raw %}{{ template "shipping-service.fullname" . }}{% endraw %}` inserts the output directly and cannot be piped. `{% raw %}{{ include "shipping-service.fullname" . }}{% endraw %}` returns the output as a string, so it can go through `quote`, `nindent` or `trunc`. Use `include` always. Pass the context explicitly: the trailing `.` hands the root context to the helper, and forgetting it gives the helper an empty context where `.Release.Name` fails.

## How the code works

`templates/_helpers.tpl` defines five templates, each with a single job.

**`shipping-service.name`** is `default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-"`. `default` lets `nameOverride` replace the chart name; `trunc 63` keeps the result inside the DNS label limit for Kubernetes names and label values; `trimSuffix "-"` removes a trailing dash that truncation can leave behind, which would be an invalid name.

**`shipping-service.fullname`** is the name used for the Deployment, Service and ConfigMap. The logic has three branches. `fullnameOverride` wins if set. Otherwise the name is `<release>-<chart>`, unless the release name already contains the chart name, in which case the release name is used alone. The `contains` branch is why a release named `shipping-service` yields `shipping-service` rather than `shipping-service-shipping-service`. It also applies when `nameOverride` is set: with `nameOverride=ship` and release `shipping`, the release name contains `ship`, so the result stays `shipping`. Observed output of `helm template shipping-service ...`:

```text
  name: shipping-service
```

and for release `shipping`, `shipping-shipping-service`. Helm itself limits release names to 53 characters, so after the chart name is added the 63-character `trunc` is a second guard, not the first.

**`shipping-service.chart`** builds `<chart>-<version>` for the `helm.sh/chart` label and replaces `+`, which SemVer build metadata allows and a label value forbids, with `_`.

**`shipping-service.selectorLabels`** returns two lines: `app.kubernetes.io/name` and `app.kubernetes.io/instance`. These are the only labels used in `spec.selector` and the Service selector. A Deployment's selector cannot change after creation, so the selector set must never include anything that changes between upgrades, such as the chart version or `appVersion`.

**`shipping-service.labels`** is the full recommended set: the chart label, the selector labels (pulled in with a nested `include`), `app.kubernetes.io/version`, `app.kubernetes.io/managed-by` from `.Release.Service` (always `Helm`) and `app.kubernetes.io/part-of`. The part-of value defaults to `shipping-platform` and `global.partOf` can override it, which is how a parent chart groups several services. Reading a key from `.Values.global` safely uses `(default (dict) .Values.global).partOf`, so a missing `global` map does not abort the render. The [Kubernetes recommended labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/) define these keys.

The call sites are one line each. The metadata of the Service now reads:

```yaml
{% raw %}  name: {{ include "shipping-service.fullname" . }}
  labels:
    {{- include "shipping-service.labels" . | nindent 4 }}{% endraw %}
```

`include ... | nindent 4` is the idiom for a multi-line helper: the helper emits lines with no indentation and the call site decides the depth. The helper definitions use `{% raw %}{{-{% endraw %}` and `-{% raw %}}}{% endraw %}` so their output has no leading or trailing newline, which keeps `nindent` from adding blank lines. The Deployment includes `labels` in `metadata.labels` and in the pod template, and `selectorLabels` in `spec.selector.matchLabels`. That split is the one non-obvious design choice: pods carry the full labels so queries by chart or version work, while the selector stays minimal and stable. Observed rendered Service labels:

```text
    helm.sh/chart: shipping-service-0.7.0
    app.kubernetes.io/name: shipping-service
    app.kubernetes.io/instance: shipping
    app.kubernetes.io/version: "0.1.0"
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/part-of: shipping-platform
```

The pod template labels include `helm.sh/chart`, so bumping the chart version changes the pod template and triggers a rollout even when nothing else changed. If that is unwanted, drop the chart label from the pod template and keep it on the object metadata.

## NOTES.txt and .Files

`templates/NOTES.txt` is rendered like any template, with the same context, and printed by `helm install` and `helm upgrade`; `helm get notes` reprints it later. It is the place for the next command the user needs. This one prints the release, the namespace and storage mode, then branches on `service.type`: for a NodePort it gives the `minikube service` command, otherwise a `kubectl get svc` command. It ends with a line from `files/support.txt`:

```text
{% raw %}{{ .Files.Get "files/support.txt" -}}{% endraw %}
```

`.Files.Get` returns the content of a file in the chart as a string. `.Files.Glob "files/*"` returns a set of files, and `.AsConfig` or `.AsSecrets` on that set renders them as ConfigMap `data` or Secret `data` entries, which is how a chart embeds configuration files. `.Files` cannot read anything under `templates/`, and `.helmignore` excludes files from it. Observed output from `helm install --dry-run=client`:

```text
NOTES:
shipping-shipping-service 0.1.0 installed as release "shipping" in namespace hfd-07.
Storage: memory

Reach the service:
  [host]$ kubectl -n hfd-07 get svc shipping-shipping-service

Questions: team-shipping@example.com (owner: team-shipping, domain: shipping)
```

## Testing a helper

A helper produces no output of its own, so test it through a caller. `helm template --show-only templates/service.yaml` renders one file and shows what `labels` produced; `--debug` prints the output even if it is not valid YAML. For a quick experiment, add `{% raw %}{{ include "shipping-service.fullname" . }}{% endraw %}` to `NOTES.txt` and run `helm install --dry-run=client`, then remove it. When a helper needs more than the root context, pass a dict, for example `{% raw %}{{ include "shipping-service.thing" (dict "root" . "extra" "x") }}{% endraw %}`, and read `.root` and `.extra` inside. Library charts in chapter 17 use that form for every shared helper. Keep helpers small: a helper that calls three others is hard to read from a rendered error, because Helm reports the name of the outer template.

## Build, run, observe

```bash
cd examples/07-helpers-notes && ./demo.sh
```

Offline it counts the `managed-by` label across the rendered resources, checks the two fullname cases and `fullnameOverride`, and prints the notes shown above. Live, it installs with `values-dev.yaml` and runs:

```bash
[host]$ helm get notes shipping -n hfd-07
[host]$ kubectl -n hfd-07 get deploy shipping-shipping-service --show-labels
```

## Cross-check

Select by a label the helper produced and confirm the Service and Deployment agree:

```bash
[host]$ kubectl -n hfd-07 get all -l app.kubernetes.io/instance=shipping
[host]$ kubectl -n hfd-07 get endpoints shipping-shipping-service
```

The Service must have one endpoint address. An empty endpoint list means the Service selector and the pod labels came from different helpers, which is the failure that centralizing the selector prevents.

## What you learned

- A named template is defined once with `define` and called with `include`, which returns a string you can pipe; always pass the context as the last argument.
- Selector labels stay small and stable; the full recommended label set goes on metadata and pod templates.
- `fullname` handles overrides, release names that contain the chart name and the 63-character limit.
- `NOTES.txt` and `.Files` render post-install guidance and embed chart files.

Chapter 08 adds the configuration and secret handling that the service needs to roll out safely.

## Further reading

- Matt Butcher, Matt Farina, Josh Dolitsky, *Learning Helm* (O'Reilly, 2021), ISBN 9781492083641. Used here for: named templates, helpers and `_helpers.tpl` conventions.
- Helm project, "Named Templates" and "Accessing Files Inside Templates", https://helm.sh/docs/chart_template_guide/named_templates/ and https://helm.sh/docs/chart_template_guide/accessing_files/.

---

*Verification status: <span class="status status--unverified">unverified</span>. A live run must confirm that `helm get notes` prints the notes, that the Service has one endpoint, and that all resources carry the recommended labels.*
