---
title: "Values and overrides"
order: 5
part: "From manifests to a chart"
description: "Design the chart's values interface, validate it with values.schema.json, and layer per-environment files and command-line flags in a predictable order."
duration: 40 minutes
---

The chart from chapter 04 reads three values. Everything else, including the log level, the resources and the probe paths, is still hardcoded in the templates. This chapter moves those settings into `values.yaml`, adds a JSON Schema that rejects bad input before anything is rendered, and shows how `-f` files and `--set` flags combine. The new idea is that `values.yaml` is the chart's public interface and deserves the same design care as an API.

The code is in `examples/05-values/`. `./demo.sh offline` runs the schema and precedence assertions without a cluster; `./demo.sh` installs the dev configuration into `hfd-05` and upgrades to the prod one.

{% include excalidraw.html
   file="05-values-precedence"
   alt="Diagram: the chart's values.yaml, then each -f file in order, then --set flags, merge in increasing priority into the .Values map, which values.schema.json validates"
   caption="Figure 5.1 — Values merge from lowest to highest priority, then the schema validates the result" %}

## Designing values.yaml

Name keys in camelCase and group related settings under a parent, such as `config.logLevel` and `probes.readiness.path`. Keep a key's comment on the same line so `helm show values` documents the chart. Quote string defaults, and leave a key empty (`tag: ""`) when the template computes the real default, as the image tag does from `appVersion`. Prefer a modest depth: every extra level is a longer `--set` path and another `if` in the templates. The [Helm values best practices](https://helm.sh/docs/chart_best_practices/values/) cover naming, types and documentation.

## How the code works

**`values.yaml`** now defines the whole interface: `replicaCount`, `image`, `containerPort`, `service`, `config`, `resources` and `probes`. The `config` block maps one to one onto the ConfigMap keys, `config.logLevel` to `LOG_LEVEL`. Two choices need a reason. `config.storage` defaults to `memory` and the schema allows only that value for now, because the Postgres wiring arrives in chapter 09. `resources` holds a whole Kubernetes `resources` map, so users can add `limits.cpu` without a chart change.

**`templates/configmap.yaml`** reads the values and pipes each through `quote`.

```yaml
{% raw %}DEPLOY_ENV: {{ .Values.config.environment | quote }}{% endraw %}
```

`quote` wraps the value in double quotes, which keeps `true` or `1.0` a string. Chapter 04 wrote literal text between quotes; `quote` is safer because it also escapes embedded quotes.

**`templates/deployment.yaml`** replaces the hardcoded probe and resource blocks.

```yaml
{% raw %}          resources:
            {{- toYaml .Values.resources | nindent 12 }}{% endraw %}
```

`toYaml` serializes the map as YAML and `nindent 12` starts a new line and indents it 12 spaces so it lands under `resources:`. Scalars such as `.Values.probes.readiness.path` are interpolated directly. Chapter 06 explains `toYaml` and `nindent`.

**`values.schema.json`** is a JSON Schema that Helm checks on `install`, `upgrade`, `template` and `lint`, after all values are merged and before any template runs. The schema sets `additionalProperties: false` at the top level, so a misspelled key fails instead of being silently ignored. It uses `enum` for closed sets (`logLevel`, `service.type`, `image.pullPolicy`), `minimum` and `maximum` for ports and for `nodePort`, which must sit in the NodePort range 30000 to 32767, and `["integer", "null"]` where `null` is a legal default. The file declares `"$schema": "https://json-schema.org/draft-07/schema#"`, the draft the [Helm charts documentation](https://helm.sh/docs/topics/charts/) uses in its example. Helm 4.3.0 also accepted a `https://json-schema.org/draft/2020-12/schema` declaration when linted locally (the shortened `https://json-schema.org/2020-12/schema` returns 404 and fails the lint), so either draft works; this book keeps draft-07 for compatibility with older Helm clients.

The schema is strict, which is a trade-off. Anyone who adds a new value must add it to the schema in the same commit, or users get a hard error. That is the purpose of the strictness, and it is why later chapters extend the schema each time the values grow.

**`values-dev.yaml` and `values-prod.yaml`** hold only the differences from the defaults: dev sets `DEBUG` logging and a NodePort, prod sets three replicas, `WARNING` logging and larger resource limits. An override file never repeats a default. Because maps merge key by key, `values-prod.yaml` can set `resources.limits.memory` and inherit `resources.requests.cpu` from the chart.

## Precedence

Helm builds one `.Values` map in this order, lowest first:

1. The chart's own `values.yaml`.
2. Each `-f` or `--values` file, left to right, so a later file wins over an earlier one.
3. `--set`, `--set-string`, `--set-file`, `--set-json` and `--set-literal`, which win over every file.

Maps merge key by key. Lists and scalars are replaced whole, so overriding one entry of `imagePullSecrets` means supplying the full list. The `demo.sh offline` assertions check the order:

```bash
[host]$ helm template shipping examples/05-values/shipping-service -f examples/05-values/values-prod.yaml --set replicaCount=5 --show-only templates/deployment.yaml
[host]$ helm template shipping examples/05-values/shipping-service -f examples/05-values/values-prod.yaml -f examples/05-values/values-dev.yaml --show-only templates/configmap.yaml
```

The first renders `replicas: 5` although prod says 3, because `--set` outranks the file. The second renders `LOG_LEVEL: "DEBUG"` because `values-dev.yaml` comes last.

The five `--set` variants differ in how they type the value:

- `--set key=value` guesses the type: `true`, integers and `null` are converted; everything else is a string. Commas separate keys, so `--set config.defaultCarrier=ACME,Post` fails with `key "Post" has no value`.
- `--set-string` forces a string. `--set image.tag=12345` fails the schema (`got number, want string`); `--set-string image.tag=12345` renders `shipping-service:12345`.
- `--set-literal` takes the value verbatim, commas included: `--set-literal config.defaultCarrier=ACME,Post` renders `"ACME,Post"`.
- `--set-file key=path` uses the file's content, trailing newline included.
- `--set-json` accepts a JSON value for a map or list, such as `--set-json 'resources={"limits":{"memory":"1Gi"}}'`.

## What deserves a value

Every value is a promise to keep supporting it. Expose a setting when operators in different environments need different answers: replicas, log level, resource sizes, the carrier. Leave a setting as a template literal when it is part of the application contract rather than a choice, such as the `http` port name that the probes and the Service both reference. A value that most installs never change is better as a documented default than as a required input. When a value is a nested structure that Kubernetes itself defines, such as `resources`, pass the whole map through instead of mirroring each field, so the chart does not lag behind the Kubernetes API. Chapter 09 adds a `global` map that a parent chart shares with its subcharts, and chapter 16 uses it for settings common to every service.

## Values across upgrades

When an upgrade passes any `-f` or `--set*` flag, Helm starts from the new chart's defaults plus the values you give it, not from the previous release, so flags given last time are gone unless you repeat them. When an upgrade passes no value flags at all, Helm reuses the previous release's values. Three flags make the choice explicit:

- `--reuse-values` reuses the last release's values and merges your new flags over them. New defaults added to the chart in the meantime are not picked up, which is the usual surprise.
- `--reset-values` discards the previous release's values and uses only the new chart's defaults plus this command's flags.
- `--reset-then-reuse-values` resets to the new chart's defaults, then applies the last release's values, then this command's flags. It keeps your overrides and still receives new defaults.

For repeatable deployments, pass the same `-f` files on every upgrade and treat the files as the source of truth. `helm get values shipping -n hfd-05` shows only what the user supplied; add `--all` for the computed result.

## Build, run, observe

```bash
cd examples/05-values && ./demo.sh
```

Offline, the script lints the chart, proves the schema rejects both a wrong type and an unknown key, and runs the two precedence renders above. Observed output, from `./demo.sh offline`:

```text
schema rejects bad type and unknown key
  replicas: 5
  LOG_LEVEL: "DEBUG"
```

A rejected value fails before rendering, with a path into the values:

```text
[ERROR] values.yaml: - at '': additional properties 'replicas' not allowed
```

A wrong type reports the path of the offending key, for example `- at '/replicaCount': got string, want integer`.

## Cross-check

Render the same override two ways and compare: once with `--set replicaCount=5` and once with a one-line file passed through `-f`. The output must be identical. For the schema, run `helm lint` with `--skip-schema-validation` on a bad value: lint passes, and the bad value reaches the templates, which shows the schema is the only guard.

## What you learned

- `values.yaml` is the chart's interface: group related keys, comment them, and keep per-environment differences in small override files.
- The schema runs on the merged values and, with `additionalProperties: false`, catches typos and wrong types before rendering.
- Precedence is chart defaults, then `-f` files in order, then `--set*` flags. Choose the `--set` variant by how the value must be typed.
- An upgrade that passes any value flag forgets the previous release's flags unless you repeat the files or use `--reuse-values` or `--reset-then-reuse-values`. An upgrade with no value flags reuses them.

Chapter 06 opens the templates and explains the functions already used here: `toYaml`, `nindent`, `quote` and `default`.

## Further reading

- Matt Butcher, Matt Farina, Josh Dolitsky, *Learning Helm* (O'Reilly, 2021), ISBN 9781492083641. Used here for: the values concept and chart defaults versus overrides.
- Helm project, "Values Files" and chart best practices, https://helm.sh/docs/chart_best_practices/values/.
- Helm project, `helm upgrade` reference (`--reuse-values`, `--reset-values`, `--reset-then-reuse-values`), https://helm.sh/docs/helm/helm_upgrade/.

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/05-values.txt`. Observed on Helm 4.3.0: the prod upgrade gave 3 replicas, `helm get values --all` showed the merged values, `--reset-then-reuse-values` kept the overrides and took a new chart default while `--reuse-values` did not, and the `--set` family and schema checks behaved as described. The rule that a bare `helm upgrade` reuses the last release's values was not run; it follows the upgrade code path in the Helm 4.3.0 binary. Re-run on r1.1 with published NodePorts on 2026-10-08 (helm4dev recreated with `HFD_NODE_PORTS`, host requests at `http://127.0.0.1:30080`, no tunnel); the behaviour above held.*
