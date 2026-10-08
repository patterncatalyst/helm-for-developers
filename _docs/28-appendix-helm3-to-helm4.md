---
title: "Appendix: Helm 3 to Helm 4"
order: 28
part: "Appendices"
description: "A migration reference: renamed and removed flags, server-side apply, the kstatus wait, plugins, post-renderers, registry login, logging, and running Helm 3 and Helm 4 side by side."
duration: 25 minutes
---

This is a reference, not a hands-on chapter. It lists what changed between Helm 3 and Helm 4 for someone with existing charts, scripts and CI, and points to the chapter that teaches each change. It is the one place in the tutorial where Helm 3 flags are written out as such, and each row that shows one carries a `<!-- helm3-reference -->` marker. Everything else in the tutorial uses the Helm 4 forms.

Sources for every row are the official Helm documents: the [Helm 4 overview](https://helm.sh/docs/overview/), the [changelog](https://helm.sh/docs/changelog/), the [Path to Releasing Helm v4](https://helm.sh/blog/path-to-helm-v4/) post, the [v4.0.0 release notes](https://github.com/helm/helm/releases/tag/v4.0.0), and [HIP-0026](https://github.com/helm/community/blob/main/hips/hip-0026.md) for plugins. Flag details below were checked against `helm <command> --help` from Helm 4.3.0.

## Charts are unchanged

Charts stay `apiVersion: v2`. A chart that installs with Helm 3 installs with Helm 4 without edits to `Chart.yaml`, `values.yaml` or templates. Helm 4's SDK supports multiple chart API versions, and chart API v3 is still in progress, so nothing here asks you to convert a chart. The changes are in the client, its flags, its plugin system and how it applies and waits.

## Renamed and removed flags

| Helm 3 | Helm 4 | Notes |
|---|---|---|
| `--atomic` | `--rollback-on-failure` | <!-- helm3-reference --> On `install` and `upgrade`. It implies `--wait=watcher`. Chapter 12. |
| `--force` | `--force-replace` | <!-- helm3-reference --> On `upgrade` and `rollback`. Both flags emit a deprecation warning when the old spelling is used. |
| `--wait` (boolean) | `--wait[=watcher\|hookOnly\|legacy]` | A bare `--wait` means `watcher`. Omitting the flag means `hookOnly`. `legacy` keeps the Helm 3 polling behavior. |
| `--dry-run` (boolean, plus `--dry-run=server`) | `--dry-run=none\|client\|server` | `install` and `upgrade` take `none`, `client` or `server`. `template` takes `client` or `server` and defaults to `client`. Chapter 13. |
| `--post-renderer <executable>` | `--post-renderer <plugin name>` | <!-- helm3-reference --> A path is rejected. Pass the name of a `postrenderer/v1` plugin, with arguments through `--post-renderer-args`. Chapter 23. |
| `helm registry login oci://host/path` | `helm registry login host` | Domain name only. Chapter 20. |
| `--hide-notes`, `--render-subchart-notes` on `helm template` | deprecated | Template output never includes notes, so the flags do nothing. Removal is planned for Helm 5. |

New flags: `--server-side` and `--force-conflicts` for server-side apply, `--take-ownership` to adopt resources that lack Helm's ownership annotations, `--wait-for-jobs`, `--skip-schema-validation`, `--history-max` on `upgrade` and `rollback`, `--show-rollback-revision` on `helm history`, `--color` and `--content-cache` as global flags, and `helm get metadata`.

## Server-side apply

New installs use server-side apply (SSA) by default. `helm install --server-side` is a boolean defaulting to `true`. `helm upgrade --server-side` takes `true`, `false` or `auto`, and `auto` (the default) follows the method the previous revision used, so a release installed with client-side apply by Helm 3 keeps its method until you change it. With SSA the API server tracks field ownership per manager, so another controller editing a field Helm also sets produces a conflict, and `--force-conflicts` lets Helm take the field. `--take-ownership` adopts objects that lack Helm's ownership annotations, and it needs `--force-conflicts` as well when another manager owns differing fields. `--force-replace` is the older replace-style update, a client-side mechanism: Helm 4.3.0 rejects it together with server-side apply, so it needs `--server-side=false`. Chapter 12 shows each.

## The wait

Helm 3's `--wait` polled readiness for a fixed list of resource kinds. Helm 4's `watcher` strategy uses kstatus, so it understands more kinds, including custom resources that report standard status conditions. The default without a flag is `hookOnly`, which waits for hooks and nothing else. That is a change if your scripts relied on `--wait` being implicit, and it is why this tutorial writes `--wait` explicitly. Hooks and `--wait` interact. A post-install hook runs only after the wait succeeds, so a readiness probe that depends on the hook never passes. Chapters 11 and 16 teach the case.

## Plugins

Helm 3 plugins were a directory with `plugin.yaml` and a command, run as a subprocess. Helm 4 has a typed plugin system from HIP-0026:

| Aspect | Helm 4 |
|---|---|
| Types | `cli/v1` (a subcommand), `getter/v1` (a download protocol), `postrenderer/v1` |
| Runtimes | `subprocess`, and Wasm through `extism/v1` |
| Manifest | `plugin.yaml` with `apiVersion: v1`, a `type`, a `runtime` and `runtimeConfig` |
| Install | `helm plugin install` verifies signatures by default, so a Git URL install needs `--verify=false` |
| Packaging | `helm plugin package` and `helm plugin verify` are new |

Existing Helm 3 plugins keep working. `helm plugin list` in this tutorial's toolchain shows `diff` and `unittest` with type `cli/v1` and API version `legacy`, meaning Helm loaded their old-style manifest and treats them as subprocess command plugins. Chapter 22 builds a subprocess plugin and a Wasm plugin.

## Post-renderers

A post-renderer is now a plugin of type `postrenderer/v1`, selected by name. Wrapper scripts that Helm 3 invoked by path need a `plugin.yaml` around them. Chapter 23 converts a kustomize post-renderer.

## Logging and output

Logging uses Go's `slog`, which matters mainly to SDK users. `--debug` still means verbose output. Color is controlled by `--color`, `--colour`, `HELM_COLOR` and `NO_COLOR`. Charts and other content are cached in a local content cache, set with `--content-cache`.

## Coexistence

You can keep Helm 3 and Helm 4 installed. They are separate binaries with the same state layout, so do not let both write to the same places by accident. This tutorial isolates Helm 4 with `scripts/env.sh`, which puts the project's binary first on `PATH` and sets `HELM_CONFIG_HOME`, `HELM_CACHE_HOME`, `HELM_DATA_HOME` and `HELM_PLUGINS` under `.tools/`. The global Helm 3 never reads or writes those directories.

```
[host]$ source scripts/env.sh && helm version --short
```

For a production migration, start in a non-production namespace. Run `helm list -A` with Helm 4 against the cluster to confirm it reads your existing releases, `helm upgrade` one release with `--dry-run=server` (it resolves kinds and runs `lookup` against the API server, but on Helm 4.3.0 it does not schema-validate fields; chapter 13), then run the upgrade without the flag. Treat release compatibility as something to test on a copy, since the official pages do not promise a guarantee beyond chart API v2.

## Plugins that touch release state

Plugins written for Helm 3 that edit release records, such as the `helm-mapkubeapis` plugin for removed Kubernetes APIs, read and write Helm's release Secrets directly. Test them against a Helm 4 client on a throwaway release before using them on a real one, and check the plugin's own release notes for Helm 4 support.

## What to change first

1. Replace the renamed flags in CI scripts. The old spellings still work with a warning, which makes them easy to find in logs.
2. Make `--wait` explicit and choose a strategy.
3. Wrap each post-renderer script in a `postrenderer/v1` plugin.
4. Drop `oci://` and the path from `helm registry login`.
5. Reinstall plugins with `helm plugin install` and decide on verification.

## Further reading

- [Helm 4 overview](https://helm.sh/docs/overview/): breaking changes, renamed flags and new features.
- [Helm changelog](https://helm.sh/docs/changelog/): per-release changes through 4.3.0.
- [Path to Releasing Helm v4](https://helm.sh/blog/path-to-helm-v4/): the release plan.
- [Helm v4.0.0 release notes](https://github.com/helm/helm/releases/tag/v4.0.0): the major change list.
- [HIP-0026](https://github.com/helm/community/blob/main/hips/hip-0026.md): the plugin system proposal.

---

*Verification status: <span class="status status--unverified">unverified</span>. Flag names and defaults were read from Helm 4.3.0 `--help`. The claims about `--force-replace` deprecation warnings, release compatibility between clients, and Helm 3 plugins that edit release state have not been run.*
