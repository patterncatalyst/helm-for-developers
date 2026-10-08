---
title: "Plugins"
order: 22
part: "Extending Helm"
description: "Helm 4 plugin types and runtimes. You write a subprocess cli/v1 plugin, build a Wasm plugin with Go, and install both under the default signature policy."
duration: 40 minutes
---

Helm ships a fixed set of commands. A plugin adds one without a fork: a directory with a `plugin.yaml` and something to run. Helm 4 rebuilt the plugin system around typed plugins and two runtimes, so this chapter writes one plugin of each runtime and runs both against the chart from the earlier chapters. You need no cluster.

The code is in `examples/22-plugins/`. Run `./demo.sh` there; its `README.md` lists what it does. Every plugin installs into an isolated directory under the example, not into `.tools/`.

{% include excalidraw.html file="22-plugin-types" alt="A plugin directory holding plugin.yaml and an entry point feeds the Helm 4 plugin loader, which dispatches to the subprocess runtime or the extism Wasm runtime." caption="Figure 22.1 — From a plugin directory to a runtime" %}

## Types and runtimes

A Helm 4 plugin has a `type` and a `runtime`. The type says what Helm uses the plugin for. The runtime says how Helm runs it.

| `type` | Used for |
|---|---|
| `cli/v1` | A new subcommand: `helm <name>` |
| `getter/v1` | Downloading charts from a new kind of location |
| `postrenderer/v1` | Rewriting rendered manifests (chapter 23) |

| `runtime` | How it runs |
|---|---|
| `subprocess` | Helm starts the command in `runtimeConfig.platformCommand` |
| `extism/v1` | Helm runs `plugin.wasm` inside the Extism Wasm runtime |

The Wasm runtime is the reason for the redesign: a Wasm module runs sandboxed, with memory and time limits set by the plugin's own configuration. A subprocess plugin has the permissions of the user who runs Helm. The design is in [HIP-0026](https://github.com/helm/community/blob/main/hips/hip-0026.md), and [the plugins overview](https://helm.sh/docs/plugins/overview/) documents the file layout and `plugin.yaml` fields.

## How the code works

### A subprocess plugin: `helm shipping-env`

The plugin answers a question the chart tools do not: what environment will the containers get? `helm shipping-env` prints every container env entry per Deployment. This is its `plugin.yaml`:

```yaml
apiVersion: v1
type: cli/v1
name: shipping-env
version: 0.1.0
runtime: subprocess
config:
  usage: "shipping-env (RELEASE [-n NAMESPACE] | --chart DIR [-f VALUES]...)"
  shortHelp: "print the effective container env of every Deployment in a release"
  ignoreFlags: false
runtimeConfig:
  platformCommand:
    - command: "${HELM_PLUGIN_DIR}/shipping-env.sh"
```

`apiVersion: v1` is the plugin schema version, not the chart `apiVersion`. `type` and `runtime` select the dispatch from Figure 22.1. `config` is the `cli/v1` block: `usage` and `shortHelp` appear in `helm --help`, which lists the plugin as `shipping-env` next to the built-in commands. `runtimeConfig.platformCommand` is the command Helm runs. Helm exports `HELM_PLUGIN_DIR` to it, and also `HELM_BIN` (the path of the running Helm) and `HELM_NAMESPACE`.

`ignoreFlags: false` matters. With `true`, Helm parses no flags for the plugin and passes it no arguments. With `false`, everything after the plugin name reaches the script. The plugin takes `-f` and `--chart`, so it must be `false`.

The script, `shipping-env.sh`, has three parts. The argument loop is a `case` over `$1` that fills `release`, `chart`, `vals` and `ns`. `-n` falls back to `HELM_NAMESPACE`, so the plugin honors the same namespace default as Helm itself. The manifest source is a branch:

```sh
if [ -n "$chart" ]; then
  manifest=$("$helm_bin" template "${release:-shipping}" "$chart" $vals)
else
  manifest=$("$helm_bin" get manifest "$release" ${ns:+-n "$ns"})
fi
```

Both branches produce the same thing, a stream of rendered manifests. `--chart` renders locally with `helm template`, so it works without a cluster. The release form reads `helm get manifest`, which returns what was applied. The script calls `"$helm_bin"` rather than `helm` so a plugin run by one Helm binary never re-enters a different one on `PATH`.

An `awk` program then walks the manifest line by line. It ignores every kind except `Deployment`, starts a group at the Deployment's `metadata.name`, and collects `- name:` and `value:` pairs inside the `env:` list. A `secretKeyRef` prints as `<secret NAME/KEY>`, so the plugin never prints a secret value. The parser is line-based and assumes Helm's output indentation. It does not expand `envFrom`, so values that arrive through the ConfigMap are not listed. A plugin that needs full fidelity would parse YAML in a real language.

### A Wasm plugin: `helm wasm-hello`

The Wasm plugin is small, because the chapter's subject is the contract, not the logic. The `plugin.yaml` differs in three places:

```yaml
runtime: extism/v1
runtimeConfig:
  memory:
    maxPages: 256
  timeout: 5000
```

`runtime: extism/v1` replaces the `platformCommand`. Helm looks for a module named `plugin.wasm` in the plugin directory. `maxPages` caps linear memory at 64 KiB per page, and `timeout` is in milliseconds. A first attempt with `maxPages: 16` fails with `Error: failed to create existing plugin: section memory: min 42 pages (2 Mi) over limit of 16 pages (1 Mi)`: a Go module needs at least 42 pages, so the plugin asks for 256.

The Go source needs one exported function:

```go
//go:wasmexport helm_plugin_main
func helmPluginMain() uint32 {
	var in input
	if err := pdk.InputJSON(&in); err != nil {
		pdk.SetError(fmt.Errorf("parse input: %w", err))
		return 1
	}
	...
	fmt.Printf("Hello, %s! (from a Wasm Helm plugin)\n", name)
	if err := pdk.OutputJSON(struct{}{}); err != nil { ... }
	return 0
}
```

`helm_plugin_main` is the entry point name Helm calls. `pdk.InputJSON` reads Helm's input message; for `cli/v1` it carries `extraArgs`, the command-line arguments after the plugin name. With `ignoreFlags: true` that list arrives empty. Text printed to WASI stdout reaches the terminal. The plugin's output message is what `pdk.OutputJSON` writes, here `{}`, and the function returns `0` on success. A non-zero return together with `pdk.SetError` reports failure.

The build is one line in the `Makefile`:

```sh
GOOS=wasip1 GOARCH=wasm go build -buildmode=c-shared -o plugin.wasm .
```

`GOOS=wasip1` targets WASI. `-buildmode=c-shared` builds the module as a library with exported functions rather than a program that runs `main` once, so `//go:wasmexport` functions stay callable. The output name must be `plugin.wasm`. The module imports `github.com/extism/go-pdk`; `go.sum` pins it.

### Install policy

`helm plugin install` verifies signatures by default for tarball installs, and it needs a `.prov` file next to the archive. A plugin directory on disk is treated as a development install and skipped. [The user guide](https://helm.sh/docs/plugins/user/) describes `--verify`; `helm plugin package` builds the tarball and signs it unless given `--sign=false`, and `helm plugin verify` checks a plugin at a path.

## Build, run, observe

```bash
cd examples/22-plugins && ./demo.sh
```

The script exports `HELM_DATA_HOME` and `HELM_PLUGINS` under `./.tmp`. Helm 4.3 links a local-directory install under `$HELM_DATA_HOME/plugins`, so pointing both variables at one directory keeps the install and the lookup together. It builds the chart's `pc-lib` dependency (the `.tgz` is not committed, so a fresh clone has none), lints the chart, builds the module, installs both plugins, and runs them. The commands below set `HELM_PLUGINS` inline so Helm looks in that isolated directory; the demo leaves the plugins installed there until `./demo.sh clean`, so you can rerun them from the example directory.

The demo prints this after the two installs. `local dev` marks the directory install of the Wasm plugin:

```text
NAME        	VERSION	TYPE  	APIVERSION	PROVENANCE	SOURCE
shipping-env	0.1.0  	cli/v1	v1        	unknown   	unknown
wasm-hello  	0.1.0  	cli/v1	v1        	local dev 	unknown
```

```text
[host]$ HELM_PLUGINS="$PWD/.tmp/data/plugins" helm shipping-env --chart chart -f values-demo.yaml
# deployment/shipping-shipping-service
API_TOKEN=<secret shipping-shipping-service/api-token>
OTEL_SDK_DISABLED=true
OTEL_SERVICE_NAME=shipping-shipping-service
OTEL_RESOURCE_ATTRIBUTES=service.namespace=shipping,deployment.environment=dev,service.version=0.1.0
```

```text
[host]$ HELM_PLUGINS="$PWD/.tmp/data/plugins" helm wasm-hello Helm4
Hello, Helm4! (from a Wasm Helm plugin)
```

The last step packages `shipping-env` without a signature and installs the tarball:

```text
Verifying plugin signature...
Error: plugin verification failed: no provenance file (.prov) found
```

Adding `--verify=false` to the install prints a warning and succeeds, and `helm plugin list` then reports the provenance as `unsigned`. Skip verification only for plugins you built yourself.

Against a deployed release the first form is `helm shipping-env platform -n hfd-26`, which reads the manifest of the running release instead of rendering.

## Cross-check

Compare the plugin to Helm directly, after `helm dependency build chart` has packed `pc-lib` (the demo does this first): `helm template shipping chart -f values-demo.yaml` and search the Deployment for `env:`. The plugin's list is the `name`/`value` pairs from that block, in the same order, with the Secret reference rewritten. If the two disagree, the awk parser has drifted from the template.

## What you learned

- A Helm 4 plugin is `plugin.yaml` plus an entry point. `type` picks the role (`cli/v1`, `getter/v1`, `postrenderer/v1`) and `runtime` picks `subprocess` or `extism/v1`.
- A subprocess plugin gets `HELM_BIN`, `HELM_NAMESPACE` and `HELM_PLUGIN_DIR`, and receives flags only with `ignoreFlags: false`.
- A Wasm plugin needs a `plugin.wasm` that exports `helm_plugin_main`, returns JSON, and fits `maxPages`.
- Tarball installs verify signatures by default; local directories are development installs.

The next chapter uses the third plugin type to rewrite manifests after Helm renders them.

## Further reading

- Helm plugins overview: <https://helm.sh/docs/plugins/overview/>
- Using Helm plugins, including `--verify`: <https://helm.sh/docs/plugins/user/>
- HIP-0026, the Wasm plugin system for Helm 4: <https://github.com/helm/community/blob/main/hips/hip-0026.md>

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/22-plugins.txt`. Observed on Helm 4.3.0: the demo ran end to end; `helm shipping-env shipping -n hfd-22` against a deployed release printed the same env list as the `--chart` form and matched `kubectl get deploy -o yaml`; Helm exported `HELM_BIN`, `HELM_NAMESPACE` and `HELM_PLUGIN_DIR` to the subprocess; `ignoreFlags: true` passed no arguments; `maxPages: 16` failed with the quoted error; `plugin.wasm` rebuilt from an empty `GOPATH`.*
