---
title: "Appendix: Cheat sheet"
order: 29
part: "Appendices"
description: "Helm 4 commands, flags and template functions on two pages, every flag checked against Helm 4.3.0."
duration: 10 minutes
---

A lookup page for the commands and template functions the tutorial uses. Every flag below was checked against `helm <command> --help` from Helm 4.3.0. Run `source scripts/env.sh` first so `helm` is the project's Helm 4. Replace `NS` and `REL` with your namespace and release name.

## Install and upgrade

```
[host]$ helm install REL ./chart -n NS --create-namespace -f values.yaml --wait --rollback-on-failure --timeout 5m
[host]$ helm upgrade --install REL ./chart -n NS -f values.yaml --wait --rollback-on-failure
[host]$ helm upgrade REL ./chart -n NS --reuse-values --set image.tag=0.1.1
[host]$ helm upgrade REL ./chart -n NS --reset-then-reuse-values -f override.yaml
[host]$ helm install REL oci://registry.example.com/charts/app --version 1.0.0 -n NS
```

| Flag | Meaning |
|---|---|
| `--rollback-on-failure` | Roll back an upgrade (uninstall an install) on failure. Implies `--wait=watcher`. |
| `--wait[=watcher\|hookOnly\|legacy]` | Wait for readiness. Bare `--wait` is `watcher`. Omitted is `hookOnly`. |
| `--wait-for-jobs` | With `--wait`, also wait for Jobs to complete. |
| `--timeout 5m` | Limit for each Kubernetes operation, including hooks. |
| `--server-side` | `install`: boolean, default `true`. `upgrade`: `true`, `false` or `auto`. |
| `--force-conflicts` | With server-side apply, take over fields owned by another manager. |
| `--force-replace` | Update resources by replacement. Client-side only: add `--server-side=false`. |
| `--take-ownership` | Adopt resources that lack Helm's ownership annotations. Add `--force-conflicts` when another manager owns differing fields. |
| `--dry-run=none\|client\|server` | Simulate. `server` needs a cluster and resolves kinds and `lookup`, but on 4.3.0 does not schema-validate fields. |
| `--no-hooks` | Skip hooks. |
| `--skip-crds` | Do not install `crds/`. |
| `--skip-schema-validation` | Ignore `values.schema.json`. |
| `--create-namespace` | Create the release namespace if missing. |
| `--dependency-update` | Fetch missing dependencies first. |
| `--post-renderer NAME`, `--post-renderer-args ARG` | Run a `postrenderer/v1` plugin by name. |
| `--history-max N` | Keep at most N revisions (`upgrade`, `rollback`). |
| `--cleanup-on-fail` | Delete new resources if the upgrade fails. |
| `--description TEXT` | Free text stored on the revision. |

Values, in precedence order from lowest to highest: chart `values.yaml`, each `-f` file in order, then `--set`, `--set-string`, `--set-json`, `--set-file` and `--set-literal`.

## Inspect and render

```
[host]$ helm template REL ./chart -n NS -f values.yaml --api-versions route.openshift.io/v1 --kube-version 1.32.0
[host]$ helm template REL ./chart -s templates/deployment.yaml --include-crds --skip-tests
[host]$ helm lint ./chart --strict --with-subcharts -f values.yaml
[host]$ helm show values ./chart
[host]$ helm show chart ./chart
[host]$ helm show crds ./chart
[host]$ helm show readme ./chart
[host]$ helm show all ./chart
[host]$ helm diff upgrade REL ./chart -n NS -f values.yaml
[host]$ helm unittest ./chart
```

The diff and unittest subcommands are plugins. `helm template --dry-run` takes `client` (default) or `server`.

## Releases

```
[host]$ helm list -n NS
[host]$ helm list -A --failed
[host]$ helm list -n NS -o json
[host]$ helm status REL -n NS
[host]$ helm history REL -n NS --show-rollback-revision
[host]$ helm get values REL -n NS
[host]$ helm get manifest REL -n NS
[host]$ helm get hooks REL -n NS
[host]$ helm get notes REL -n NS
[host]$ helm get metadata REL -n NS
[host]$ helm get all REL -n NS
[host]$ helm rollback REL 2 -n NS --wait
[host]$ helm test REL -n NS --logs
[host]$ helm uninstall REL -n NS --keep-history
[host]$ helm uninstall REL -n NS --ignore-not-found
```

## Charts and repositories

```
[host]$ helm create mychart
[host]$ helm create mychart --starter pc-fastapi
[host]$ helm dependency update ./chart
[host]$ helm dependency build ./chart
[host]$ helm dependency list ./chart
[host]$ helm package ./chart -d dist --version 1.0.0 --app-version 0.1.0
[host]$ helm package ./chart --sign --key KEYNAME --keyring KEYRING
[host]$ helm verify dist/chart-1.0.0.tgz --keyring KEYRING
[host]$ helm repo add NAME https://example.com/charts
[host]$ helm repo update
[host]$ helm repo index dist --url https://example.com/charts
[host]$ helm search repo NAME/ --versions
[host]$ helm search hub keyword
[host]$ helm pull NAME/chart --version 1.0.0 --untar --untardir tmp
```

## OCI

```
[host]$ helm registry login registry.example.com -u USER --password-stdin
[host]$ helm push dist/chart-1.0.0.tgz oci://registry.example.com/charts
[host]$ helm pull oci://registry.example.com/charts/chart --version 1.0.0
[host]$ helm show values oci://registry.example.com/charts/chart --version 1.0.0
[host]$ helm install REL oci://registry.example.com/charts/chart --version 1.0.0 --plain-http
[host]$ helm registry logout registry.example.com
```

Log in with the domain only. `--plain-http` is for local registries without TLS.

## Plugins

```
[host]$ helm plugin list
[host]$ helm plugin install ./plugin-dir
[host]$ helm plugin install https://example.com/plugin.git --verify=false
[host]$ helm plugin update NAME
[host]$ helm plugin package ./plugin-dir
[host]$ helm plugin verify ./plugin-dir
[host]$ helm plugin uninstall NAME
```

## Environment and global flags

| Item | Meaning |
|---|---|
| `HELM_CONFIG_HOME`, `HELM_CACHE_HOME`, `HELM_DATA_HOME`, `HELM_PLUGINS` | State directories. |
| `HELM_DRIVER` | Release storage: `secret`, `configmap`, `memory`, `sql`. |
| `HELM_NAMESPACE`, `HELM_KUBECONTEXT` | Defaults for `-n` and `--kube-context`. |
| `HELM_DEBUG`, `--debug` | Verbose output. |
| `HELM_COLOR`, `NO_COLOR`, `--color` | Color control. |
| `HELM_MAX_HISTORY` | Default revision limit. |
| `--kube-context`, `--kubeconfig`, `-n` | Cluster selection. |
| `--content-cache` | Directory for cached charts. |
| `helm env` | Print every setting. |

## Template objects

{% raw %}
| Object | Use |
|---|---|
| `.Values` | Merged values. |
| `.Release.Name`, `.Release.Namespace`, `.Release.Service` | Release identity. |
| `.Release.IsInstall`, `.Release.IsUpgrade`, `.Release.Revision` | Lifecycle state. |
| `.Chart.Name`, `.Chart.Version`, `.Chart.AppVersion` | Chart metadata. |
| `.Capabilities.APIVersions.Has "group/version"` | Is the API served? |
| `.Capabilities.KubeVersion.Version` | Cluster version. |
| `.Template.Name`, `.Template.BasePath` | Current template. |
| `.Files.Get`, `.Files.Glob`, `.Files.AsConfig`, `.Files.AsSecrets`, `.Files.Lines` | Chart files. |

## Template functions

| Function | Example |
|---|---|
| `default` | `{{ .Values.tag \| default .Chart.AppVersion }}` |
| `required` | `{{ required "host is required" .Values.host }}` |
| `quote`, `squote` | `{{ .Values.name \| quote }}` |
| `toYaml`, `toJson`, `fromYaml` | `{{ toYaml .Values.resources \| nindent 12 }}` |
| `indent`, `nindent` | `{{ include "x.labels" . \| nindent 4 }}` |
| `include` | `{{ include "x.fullname" . }}` returns a string. |
| `tpl` | `{{ tpl .Values.text . }}` renders a string as a template. |
| `lookup` | `{{ lookup "v1" "Secret" .Release.Namespace "name" }}` returns empty under `helm template`. |
| `printf` | `{{ printf "%s-%s" .Release.Name .Chart.Name }}` |
| `trunc`, `trimSuffix`, `trimPrefix`, `trim` | `{{ .Release.Name \| trunc 63 \| trimSuffix "-" }}` |
| `lower`, `upper`, `title`, `kebabcase` | Case conversion. |
| `contains`, `hasPrefix`, `hasSuffix`, `regexMatch` | String tests. |
| `dict`, `list`, `append`, `merge`, `mergeOverwrite` | Build and combine collections. |
| `hasKey`, `has`, `keys`, `pick`, `omit`, `get` | Map and list access. |
| `ternary` | `{{ ternary "a" "b" .Values.flag }}` |
| `coalesce`, `empty` | First non-empty value, emptiness test. |
| `b64enc`, `b64dec`, `sha256sum` | Encoding and checksums. |
| `semverCompare` | `{{ semverCompare ">=1.29.0" .Capabilities.KubeVersion.Version }}` |
| `fail` | `{{ fail "unsupported" }}` stops rendering. |
| `randAlphaNum`, `genPassword`-style helpers | Random values change on every render, so use `lookup` to keep them. |

Flow control: `if`, `else if`, `else`, `with`, `range`, `define`, `template`, `block`, `end`. A leading or trailing `-` inside the braces trims whitespace. Inside `range` and `with`, `$` is the root context.
{% endraw %}

## Further reading

- [Helm documentation](https://helm.sh/docs/): the command reference and the chart template guide.
- [Helm 4 overview](https://helm.sh/docs/overview/): what changed from Helm 3.
- Chapter 28 in this tutorial, for the old-to-new flag map.

---

*Verification status: <span class="status status--unverified">unverified</span>. Flag spellings come from Helm 4.3.0 `--help`. Examples were not each executed.*
