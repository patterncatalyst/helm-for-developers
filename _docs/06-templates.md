---
title: "Templates"
order: 6
part: "From manifests to a chart"
description: "How Helm renders a chart: Go template syntax, Sprig functions, built-in objects, whitespace control, if, with and range, and the functions that fail loudly or reach into the cluster."
duration: 45 minutes
---

Chapters 04 and 05 used template expressions without explaining them. This chapter takes them apart. The shipping-service templates gain optional blocks (pull secrets, pod annotations, extra environment variables) and a required field, and each construct that appears is a feature of Go's `text/template` package plus the Sprig function library. The new idea is that a template is a program whose output happens to be YAML, so indentation and whitespace are part of its logic.

The code is in `examples/06-templates/`. `./demo.sh offline` renders the chart and asserts the behavior of `required`, `tpl` and `with` without a cluster; `./demo.sh` installs it into `hfd-06`.

{% include excalidraw.html
   file="06-render-pipeline"
   alt="Diagram: .Values, .Release, .Chart, .Capabilities and .Files feed the Go template engine with Sprig functions, which produces YAML documents that are parsed and checked before the API server receives them"
   caption="Figure 6.1 — Templates read built-in objects and produce YAML documents" %}

## The objects a template can read

Everything inside `{% raw %}{{ }}{% endraw %}` is evaluated against a context, written `.` (dot). Helm fills the root context with these objects:

- `.Values`: the merged values from chapter 05.
- `.Release`: `.Name`, `.Namespace`, `.Revision`, `.IsInstall`, `.IsUpgrade`, `.Service`.
- `.Chart`: the fields of `Chart.yaml`, capitalized (`.Chart.AppVersion`).
- `.Capabilities`: the cluster's Kubernetes version and API versions, used in chapter 10.
- `.Template`: `.Name` and `.BasePath` of the file being rendered.
- `.Files`: non-template files in the chart, used in chapter 07.

## Pipelines, whitespace and flow control

A pipeline passes a value through functions with `|`. `{% raw %}{{ .Values.config.logLevel | quote }}{% endraw %}` is `quote .Values.config.logLevel` written left to right. Most functions come from Sprig: `default`, `quote`, `trunc`, `trimSuffix`, `printf`, `sha256sum`, `b64enc`. Helm adds `toYaml`, `fromYaml`, `include`, `tpl`, `required` and `lookup`.

Whitespace is literal. `{% raw %}{{-{% endraw %}` deletes all whitespace and newlines before the action and `{% raw %}-}}{% endraw %}` deletes them after. Without the dash, an `if` block leaves a blank or half-indented line, and in YAML a misplaced space changes the meaning. `nindent N` prints a newline and then indents every line by N spaces; it is the standard way to insert a multi-line value such as `toYaml` output under a key.

The three flow-control actions each end with `{% raw %}{{ end }}{% endraw %}`:

- `if` runs a block when the condition is truthy. Empty strings, `0`, `false`, `null`, empty maps and empty lists are all false. Combine conditions with prefix functions: `{% raw %}{{ if and (eq .Values.service.type "NodePort") .Values.service.nodePort }}{% endraw %}`.
- `with` runs the block only when the value is non-empty and rebinds `.` to that value inside it.
- `range` loops over a list (`.` is the item) or a map (`$key, $value :=` binds both).

## How the code works

The whole chapter lives in `templates/deployment.yaml`. It opens with two variables:

```yaml
{% raw %}{{- $fullname := printf "%s-%s" .Release.Name .Chart.Name -}}
{{- $image := printf "%s:%s" (required "image.repository is required" .Values.image.repository) (.Values.image.tag | default .Chart.AppVersion) -}}{% endraw %}
```

A variable is declared with `:=` and read with `$name`. `$fullname` removes the four repeated name expressions from chapter 04. `printf` builds the image reference. `required "message" value` returns the value, or aborts rendering with the message when the value is empty. Both dashes trim the newline, so the declarations produce no output and the first line of the file is still `apiVersion`.

The schema catches an empty `image.repository` first (`minLength: 1`), so to see `required` fire you skip it with `--skip-schema-validation`. `required` is the guard for values the schema cannot express or a chart that ships without one. Observed output:

```text
Error: execution error at (shipping-service/templates/deployment.yaml:2:30): image.repository is required
```

`fail "message"` is the unconditional version, used inside an `if` to reject an invalid combination of values.

The optional pull secrets use `with`:

```yaml
{% raw %}      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}{% endraw %}
```

With the default empty list the whole block disappears, including the key. Inside it `.` is the list, so `toYaml .` serializes it and `nindent 8` places it under the key at the right depth. If `with` were an `if`, `.` would still be the root context.

Pod annotations show `range`, `$`, and `tpl` together:

```yaml
{% raw %}      annotations:
        {{- range $key, $value := . }}
        {{ $key | quote }}: {{ tpl $value $ | quote }}
        {{- end }}{% endraw %}
```

Inside a `range` or `with`, `.` is rebound, so the root context is no longer reachable as `.`. `$` always points at the root. `tpl $value $` renders the value string as a template with the root as its context. In `values-dev.yaml` the annotation value is `{% raw %}"{{ .Release.Name }}/{{ .Release.Namespace }}"{% endraw %}`, and the rendered pod carries `"shipping.example.com/release": "shipping/default"` (the namespace is `default` unless `-n` is given). `tpl` lets a value refer to release data. Because it evaluates arbitrary template text, apply it only to values the chart author or the operator controls.

The extra environment variables use `range` over a list of maps:

```yaml
{% raw %}          {{- with .Values.extraEnv }}
          env:
            {{- range . }}
            - name: {{ .name }}
              value: {{ .value | quote }}
            {{- end }}
          {{- end }}{% endraw %}
```

The outer `with` skips the `env:` key for an empty list, so the key is omitted instead of rendering as `env: null`. The inner `range` rebinds `.` to each item, so `.name` and `.value` read that entry. The schema constrains names to `^[A-Z_][A-Z0-9_]*$`.

`templates/service.yaml` keeps the `nodePort` guard from chapter 04 and tightens it with `and (eq ...)`: a `nodePort` set while the type is `ClusterIP` would be rejected by the API server, so the template drops it. Observed with the chart defaults plus `service.nodePort=30080`: no `nodePort` line renders.

## lookup and its limits

`lookup "v1" "Secret" "ns" "name"` queries the live cluster during rendering and returns the object as a map, or an empty map if it does not exist. Under `helm template` and `--dry-run=client` there is no cluster connection, so `lookup` always returns an empty map. A chart that depends on it renders differently offline than in an install against a cluster. `helm template --dry-run=server` and `helm install --dry-run=server` connect to the cluster and run `lookup`. Chapter 08 uses `lookup` to keep a generated Secret stable, and chapter 25 returns to the limit when Argo CD renders the chart.

## Build, run, observe

```bash
cd examples/06-templates && ./demo.sh
```

The offline half of the script lints, renders and validates the chart, then asserts:

```text
        "shipping.example.com/release": "shipping/hfd-06"
required, tpl and with behave as documented
```

To explore, render single files and compare:

```bash
[host]$ helm template shipping examples/06-templates/shipping-service -n hfd-06 -f examples/06-templates/values-dev.yaml --show-only templates/deployment.yaml
[host]$ helm template shipping examples/06-templates/shipping-service --show-only templates/deployment.yaml
```

The first includes the `annotations` and `env` blocks; the second has neither. `--debug` prints the rendered text even when it is not valid YAML, which is how you find an indentation error.

## Cross-check

The `helm lint` command renders every template and checks the result is valid YAML, and `kubeconform` checks it against the Kubernetes schema. Run both on the default values and again with `-f values-dev.yaml`. An `if` that leaves a stray dash or indent usually passes one set of values and fails the other, which is why `demo.sh offline` renders both.

## What you learned

- A template is evaluated against `.Values`, `.Release`, `.Chart`, `.Capabilities`, `.Template` and `.Files`, using Go template syntax with Sprig and Helm functions.
- `{% raw %}{{-{% endraw %}`, `-}}` and `nindent` control whitespace; `if`, `with` and `range` control structure; `$` reaches the root inside rebinding blocks.
- `required` and `fail` stop a bad render with your message; `tpl` renders a value as a template; `lookup` is empty without a cluster.

Chapter 07 moves the repeated names and labels into named templates and adds `NOTES.txt`.

## Further reading

- Matt Butcher, Matt Farina, Josh Dolitsky, *Learning Helm* (O'Reilly, 2021), ISBN 9781492083641. Used here for: Go templates, built-in objects and control structures.
- Andrew Block and Austin Dewey, *Managing Kubernetes Resources Using Helm, 2nd ed.* (Packt, 2022), ISBN 9781803242897. Used here for: templating functions and flow control.
- Helm project, "Chart Template Guide", https://helm.sh/docs/chart_template_guide/.

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/06-templates.txt`. Observed on Helm 4.3.0: the `tpl` annotation reached the running pod with the install namespace, `required` fired only with schema validation skipped, and `lookup` returned an empty map under `helm template` and `--dry-run=client` but the live object under `--dry-run=server` (observed with the chapter 08 chart, `_plans/evidence/08-config-secrets.txt`).*
