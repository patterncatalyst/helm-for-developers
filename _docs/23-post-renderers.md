---
title: "Post-renderers"
order: 23
part: "Extending Helm"
description: "Change what a chart renders without forking it. You write a postrenderer/v1 plugin that runs kubectl kustomize and call it with --post-renderer and --post-renderer-args."
duration: 35 minutes
---

Sometimes the chart is not yours: a platform team needs a label on every object, or an annotation on every pod template, and the upstream chart exposes no value for it. A post-renderer is a filter that Helm runs on the rendered manifests before it uses them. In Helm 4 a post-renderer is a plugin of type `postrenderer/v1`, so this chapter builds on chapter 22 and wraps `kubectl kustomize` as one.

The code is in `examples/23-post-renderers/`. Run `./demo.sh` there. The plugin installs into an isolated directory under the example, and `kubectl` must be on `PATH`.

{% include excalidraw.html file="23-post-render-pipeline" alt="Helm renders a chart into one YAML stream, pipes it to the kustomize-postrender plugin on stdin, which runs kubectl kustomize and writes modified YAML to stdout." caption="Figure 23.1 — A post-renderer sits between rendering and use" %}

## The contract

A post-renderer is a filter. Helm renders the chart, writes the full manifest stream to the plugin's standard input, and reads the replacement stream from its standard output. With `helm template` the result prints. With `helm install` or `helm upgrade` it is what Helm applies. [The plugins overview](https://helm.sh/docs/plugins/overview/) describes the type, and [the plugin tutorial](https://helm.sh/docs/plugins/developer/tutorial-postrenderer-plugin/) shows the same stdin/stdout shape.

The call has two flags, both documented on [`helm template`](https://helm.sh/docs/helm/helm_template/):

- `--post-renderer NAME` names an installed `postrenderer/v1` plugin.
- `--post-renderer-args ARG` passes an argument to it, and can repeat.

Helm 4 accepts only a plugin name. A path to an executable is rejected, which is the main migration step from Helm 3.

> **Helm 3 comparison.** Helm 3 took the path of an executable: `--post-renderer ./postrender.sh` <!-- helm3-reference -->. In Helm 4 wrap the script in a plugin as below. The migration list is in the Helm 3 to Helm 4 appendix.

## When a post-renderer is the right tool

Try the chart's own values first. A chart that exposes `podAnnotations` or `commonLabels` needs no post-renderer, and the setting stays visible in `values.yaml`. A post-renderer fits when the chart has no such knob and a fork would cost more than the filter, or when one policy must apply to every chart in a pipeline. Three costs come with it. The change is invisible in the chart, so a reader of `helm template` without the flag sees different output. Every install and upgrade needs the same flags, or the release drifts between revisions. And the filter runs on your machine, so CI and developers need the same plugin installed at the same version.

## How the code works

### The plugin manifest

```yaml
apiVersion: v1
type: postrenderer/v1
name: kustomize-postrender
version: 0.1.0
runtime: subprocess
runtimeConfig:
  platformCommand:
    - command: "${HELM_PLUGIN_DIR}/postrender.sh"
```

It has the same fields as the `cli/v1` plugin in chapter 22, minus the `config` block. A post-renderer has no command name of its own, so no `usage` or `shortHelp`. `type: postrenderer/v1` is what makes `--post-renderer kustomize-postrender` resolve. The plugin name is the value users pass, so keep it descriptive. `${HELM_PLUGIN_DIR}` expands to the plugin's directory.

### The script

`postrender.sh` has to do four things in order: read stdin, build a kustomization around it, run kustomize, and write only YAML to stdout.

```sh
label_value="${1:-true}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/all.yaml"
```

The first argument is whatever follows `--post-renderer-args`; without it the label value is `true`. `kubectl kustomize` reads a directory, not a stream, so the script spools stdin to `all.yaml` in a temporary directory and removes the directory on exit through the `trap`. `set -eu` at the top stops the script on any failure, so Helm sees a non-zero exit rather than half a manifest.

```yaml
resources:
  - all.yaml
labels:
  - pairs:
      patterncatalyst.io/post-rendered: "${label_value}"
    includeSelectors: false
```

The heredoc writes a `kustomization.yaml`. `resources` points at the spooled render. `labels` is the kustomize field that adds a label to every object it processes. `includeSelectors: false` is the important line: with `true`, kustomize also rewrites `spec.selector.matchLabels` and Service selectors, and a Deployment's selector is immutable, so a post-renderer that touched it would break upgrades of an existing release. The label lands on metadata and pod templates only.

```yaml
patches:
  - target:
      kind: Deployment
    patch: |-
      - op: add
        path: /spec/template/metadata/annotations/patterncatalyst.io~1post-rendered-by
        value: kustomize-postrender
```

The patch is a JSON 6902 operation aimed at every `Deployment`. In a JSON Pointer path a `/` inside a key is written `~1`, so `patterncatalyst.io~1post-rendered-by` is the single key `patterncatalyst.io/post-rendered-by`. The `add` needs `spec/template/metadata/annotations` to exist, and the reference chart always sets pod annotations (its `checksum/config`). Run by hand on a Deployment without annotations, the script exits 1 with `error: add operation does not apply: doc is missing path`, and Helm reports only `Error: INSTALLATION FAILED: error while running post render on files: failed to invoke post-renderer plugin "kustomize-postrender": plugin "kustomize-postrender" exited with error`. The script's own stderr does not reach the terminal. A real plugin would guard that case.

The last line, `kubectl kustomize "$work"`, writes the result to stdout. Nothing else may print to stdout, or the noise becomes part of the manifest. Diagnostics belong on stderr.

### Arguments

`--post-renderer-args` can repeat, and each value arrives as one positional argument, in order. The script reads only `$1`, so a second value is ignored. A plugin that takes several settings should parse them explicitly with `shift` and a `case`, the way `shipping-env.sh` does in chapter 22, rather than rely on position. Keep the argument list short: it is part of every deploy command, and a long one belongs in a wrapper script or a Makefile target the whole team calls.

### Fragile bits

- The script needs a `kubectl` with built-in kustomize on `PATH`. A standalone `kustomize` binary would also work with a one-word change.
- kustomize re-serializes the stream, so object order and formatting differ from `helm template`. Compare renders by object, not by line.
- The label value is not validated. A value that is not a valid label value fails at apply time, not at render time.

## Build, run, observe

```bash
cd examples/23-post-renderers && ./demo.sh
```

The demo installs the plugin, then renders the chart three ways. Commands are shown with `HELM_PLUGINS` set to the demo's plugin directory:

```text
[host]$ HELM_PLUGINS="$PWD/.tmp/data/plugins" helm template shipping chart -f values-demo.yaml --post-renderer kustomize-postrender
```

Without the flag the render contains no `post-rendered` string. With it, the default run prints these matches:

```text
13:    patterncatalyst.io/post-rendered: "true"
40:    patterncatalyst.io/post-rendered: "true"
59:    patterncatalyst.io/post-rendered: "true"
88:    patterncatalyst.io/post-rendered: "true"
103:        patterncatalyst.io/post-rendered-by: kustomize-postrender
191:    patterncatalyst.io/post-rendered: "true"
```

Five objects get the label (Secret, ConfigMap, Service, Deployment and the test Pod), and the Deployment's pod template gets the annotation. Adding `--post-renderer-args staged` to the command changes each label value to `staged`.

The last step passes the plugin's script path instead of its name:

```text
Error: invalid argument "./plugins/kustomize-postrender/postrender.sh" for "--post-renderer" flag: plugin: {Name:./plugins/kustomize-postrender/postrender.sh Type:postrenderer/v1} not found
```

Helm looks the value up as a plugin name and fails. The same error appears for a name that was never installed.

On a live install the flags are the same, for example `helm install shipping chart --post-renderer kustomize-postrender`, with the plugin installed in the plugin directory Helm reads.

## Troubleshooting

Post-renderer failures surface as a single error from `helm install` or `helm template` that does not include the script's stderr, so the first step is to run the script by hand with the same input.

- **`plugin: {Name:... Type:postrenderer/v1} not found`.** `--post-renderer` takes the name of an installed plugin of type `postrenderer/v1`. A path to an executable fails with this message, and so does a misspelled name. Run `helm plugin list` and confirm the name and the type column.
- **A patch step exits 1 with `add operation does not apply: doc is missing path`.** The script's JSON patch adds a key under a path the object does not have; a Deployment without pod-template annotations is the example in the demo. Either create the parent map first or write the patch as a merge that tolerates a missing parent. The failing object is the one on standard input, so pipe `helm template` into the script to reproduce it.
- **Arguments arrive in the wrong position.** Each `--post-renderer-args` value becomes one positional argument, in order, so two flags give `$1` and `$2`. Quote values that contain spaces, and keep the script's argument handling as short as the demo's.
- **Selectors changed and an upgrade fails.** Adding a label through a transformer that also rewrites selectors changes immutable fields on a Deployment. Keep `includeSelectors: false` in the Kustomize `labels` entry so the label lands on metadata and pod templates and `spec.selector.matchLabels` stays untouched.

Because the stored release holds the post-rendered manifest, `helm get manifest` is the quickest check that a transformation took effect. If the label is missing there, the renderer did not run, regardless of what the live objects show after an earlier install.

## Cross-check

Run the script by hand, outside Helm: `helm template shipping chart -f values-demo.yaml | ./plugins/kustomize-postrender/postrender.sh` (no plugin lookup happens, so `HELM_PLUGINS` is not needed). It prints the same stream Helm prints through the flag, and `grep -c post-rendered` on it returns 6, the five labels plus the annotation. Agreement shows the plugin adds nothing beyond what the script does: Helm only supplies stdin and reads stdout.

## What you learned

- In Helm 4 a post-renderer is a `postrenderer/v1` plugin. Use `--post-renderer NAME` and `--post-renderer-args`, never an executable path.
- The plugin reads manifests on stdin and writes manifests on stdout, and nothing else may reach stdout.
- `includeSelectors: false` keeps immutable selectors unchanged, and JSON-patch keys escape `/` as `~1`.
- kustomize reorders and reformats output, so compare by object.

The next part moves from extending Helm to running it across environments, starting with promotion.

## Further reading

- Helm plugins overview: <https://helm.sh/docs/plugins/overview/>
- Building a postrenderer plugin: <https://helm.sh/docs/plugins/developer/tutorial-postrenderer-plugin/>
- Flag reference for the template command: <https://helm.sh/docs/helm/helm_template/>
- HIP-0026, the Wasm plugin system for Helm 4: <https://github.com/helm/community/blob/main/hips/hip-0026.md>

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/23-post-renderers.txt`. Observed on Helm 4.3.0: `helm install --post-renderer kustomize-postrender` on the cluster put `patterncatalyst.io/post-rendered` on the Deployment, Service, ConfigMap and Secret and the annotation on the pod template, `spec.selector.matchLabels` stayed unchanged, `helm get manifest` carried the label (install and upgrade), two `--post-renderer-args` arrived as `$1` and `$2`, and the missing-annotations Deployment failed the install.*
