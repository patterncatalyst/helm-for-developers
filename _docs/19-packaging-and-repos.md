---
title: "Packaging and repositories"
order: 19
part: "Distribution and supply chain"
description: "Turn the shipping-service chart into a versioned 1.0.0 archive, index it, and serve it as a classic chart repository you can add, search and install from."
duration: 35 minutes
---

Until now every install pointed at a chart directory on disk. That works for one developer and breaks the moment a second person, a CI job or Argo CD needs the same chart at the same version. This chapter packages `shipping-service` as release `1.0.0`, shows why the chart version and the application version are two different numbers, and serves the archive as a classic repository: an `index.yaml` plus `.tgz` files behind plain HTTP.

The code is in `examples/19-packaging-repos/`. `./demo.sh offline` lints, renders, unit-tests, packages and indexes without a cluster; `./demo.sh` also serves the repository and installs from it.

{% include excalidraw.html
   file="19-semver-chart-vs-app"
   alt="Diagram: Chart.yaml version, appVersion and dependencies feed helm package, which writes shipping-service-1.0.0.tgz; helm repo index builds index.yaml next to it and a python http.server serves both to helm repo add"
   caption="Figure 19.1 — Chart.yaml fields into a package, an index and a served repository" %}

## Two version numbers, two meanings

`Chart.yaml` carries both numbers, and they move independently:

```yaml
version: 1.0.0        # the chart: templates, values keys, dependencies
appVersion: "0.1.0"   # the application the chart deploys
```

`version` is a [SemVer](https://semver.org/) number for the chart itself. Bump the major version when a values key a consumer sets disappears or changes meaning, the minor version when you add a template or an optional value, the patch version for a fix that changes nothing a consumer wrote. `appVersion` describes the software inside. In this chart it is also the default image tag, because the Deployment helper falls back to `.Chart.AppVersion` when `image.tag` is empty. A new service image with an unchanged chart is a new `appVersion` and a patch or minor chart bump; a template rewrite around the same image is a chart bump only.

The `helm package` command can override both without editing the file, which is how CI stamps a release:

```bash
[host]$ helm package examples/19-packaging-repos/charts/shipping-service --version 1.0.1 --app-version 0.1.1 -d .work/repo
```

With `--app-version 0.1.1`, `helm template` on the packaged chart renders `image: "shipping-service:0.1.1"` and `app.kubernetes.io/version: "0.1.1"`. Pre-release versions such as `1.1.0-rc.1` are valid SemVer and Helm hides them from `helm search repo` until you pass `--devel`.

Helm's version parser is lenient. Helm packaged `--version 1.0` and `--version v1.0.2` without complaint, and the index stored them as written. Treat that leniency as a trap: three-part numbers with no `v` prefix keep ordering, ranges and tooling predictable.

## How the code works

The snapshot holds two charts: `charts/shipping-service` (version `1.0.0`) and `charts/pc-lib` (a `type: library` chart, version `1.0.0`). The dependency in `shipping-service/Chart.yaml` is:

```yaml
dependencies:
  - name: pc-lib
    version: 1.0.0
    repository: file://../pc-lib
```

`file://../pc-lib` resolves relative to the chart directory, so it works on your machine and nowhere else. That is acceptable only because `helm package` copies the dependency into the archive's `charts/` directory. The archive is self-contained; the `repository` field in its `Chart.yaml` is metadata at that point.

The copy comes from `charts/` inside the source chart, and `.tgz` files there are not committed. On a fresh checkout the first package attempt fails:

```text
Error: found in Chart.yaml, but missing in charts/ directory: pc-lib
```

Two fixes exist. `helm dependency build` restores `charts/` exactly as `Chart.lock` records. `helm package --dependency-update` (short form `-u`) re-resolves dependencies and rewrites the lock first. The script uses `build` for lint and test, and `--dependency-update` when it packages, so a release never ships against a stale lock.

`demo.sh offline` then runs the same gates as earlier chapters: `helm lint --strict`, `helm template` piped into `kubeconform -strict`, and `helm unittest` (25 tests). A package that fails a gate should never reach a repository.

What goes into the archive is decided by `.helmignore`, which this chart anchors to the chart root:

```text
.git/
/tests/
```

The leading slash restricts the rule to the chart root, so the helm-unittest suites in `tests/` stay out of the package while `templates/tests/test-connection.yaml`, the `helm test` hook, stays in. An unanchored `tests/` would drop both. Check any package before publishing it:

```bash
[host]$ tar tzf .work/repo/shipping-service-1.0.0.tgz
```

The listing shows `Chart.yaml`, `Chart.lock`, `values.yaml`, `values.schema.json`, the templates, `ci/ci-values.yaml` and the embedded `charts/pc-lib/` files, and no `tests/` directory.

The packaging step writes two archives into `.work/repo`:

```bash
[host]$ helm package charts/shipping-service --dependency-update -d .work/repo
[host]$ helm package charts/shipping-service --version 1.1.0-rc.1 -d .work/repo
```

The file name is `<chart name>-<chart version>.tgz`, taken from `Chart.yaml` or `--version`. The flag `-d` (`--destination`) selects the output directory.

The index is built from the directory contents:

```bash
[host]$ helm repo index .work/repo --url http://127.0.0.1:8088
```

For each archive `index.yaml` records the chart metadata, `version`, `appVersion`, a `digest` and a `urls` list built from `--url`. The digest is the SHA-256 of the `.tgz`; `sha256sum` on the archive prints the same value (`f8d507c0...` for `1.0.0` here). Because the URL is baked into the index, the index must be regenerated, or merged with `--merge`, whenever the public address changes. Add a new version by packaging into the same directory and re-running `helm repo index`; older entries stay.

A classic repository needs no special server. Any HTTP server that serves `index.yaml` and the archives is enough:

```bash
[host]$ python3 -m http.server 8088 --bind 127.0.0.1
```

Run it from inside the repository directory. The script starts it in the background, records the PID in `.work/http.pid`, and `./demo.sh clean` kills it.

## Build, run, observe

```bash
[host]$ cd examples/19-packaging-repos && ./demo.sh
```

The client side is three commands. `helm repo add` stores the name and URL in `repositories.yaml` under the project-local `HELM_CONFIG_HOME`, `helm repo update` downloads `index.yaml` into `HELM_CACHE_HOME`, and `helm search repo` reads that cached copy:

```bash
[host]$ helm repo add hfd-local http://127.0.0.1:8088
[host]$ helm repo update hfd-local
[host]$ helm search repo hfd-local
```

Observed output from the demo repository (`1.0.0` and `1.1.0-rc.1`):

```text
NAME                      	CHART VERSION	APP VERSION	DESCRIPTION
hfd-local/shipping-service	1.0.0        	0.1.0      	Shipping data product. FastAPI service that cre...
```

`--devel --versions` lists `1.1.0-rc.1` above `1.0.0`, each version on its own line. Searching is local: it reads the cached index, so a new upload is invisible until the next `helm repo update`.

To fetch without installing, use `helm pull hfd-local/shipping-service --version 1.0.0 -d .work/pull`. The destination directory must exist; `helm pull` does not create it and fails with a temp-file error if it is missing. `--untar` expands the chart instead of keeping the archive.

The install uses the repository reference and an explicit version:

```bash
[host]$ helm upgrade --install shipping hfd-local/shipping-service --version 1.0.0 -n hfd-19 --create-namespace --set service.type=NodePort --set service.nodePort=30080 --wait --rollback-on-failure
```

Without `--version`, Helm picks the newest non-pre-release version. Pin it in anything that is not a throwaway.

## Published chart repository

This site serves a classic repository of the reference charts from GitHub Pages: `index.yaml` plus a packaged archive for `pc-lib`, `shipping-service`, `notification-service`, `shipping-postgres`, `shipping-kafka` and `shipping-platform`. `scripts/publish-charts.sh` builds it bottom-up with the same `helm dependency build`, `helm package` and `helm repo index --url` sequence this chapter uses, and the Pages workflow runs it after the Jekyll build. The umbrella archive carries its subcharts, so installing `shipping-platform` from the repository needs no `file://` paths.

```bash
[host]$ helm repo add hfd https://patterncatalyst.github.io/helm-for-developers/charts
[host]$ helm search repo hfd
[host]$ helm pull hfd/shipping-platform --version 1.0.0 -d .
```

The same build served from a local HTTP server listed all six charts at 1.0.0, and `helm template` rendered the umbrella from the pulled archive. The commands against the real Pages URL run after the r1.1 deploy; until then treat that URL as unverified.

## Cross-check

Compare three views of the same release. `sha256sum .work/repo/shipping-service-1.0.0.tgz` equals the `digest` in `index.yaml`. `helm get metadata shipping -n hfd-19` shows chart `shipping-service` version `1.0.0` and appVersion `0.1.0`. `helm show chart hfd-local/shipping-service --version 1.0.0` prints the same `Chart.yaml` the directory holds. Agreement across the digest, the stored release and the repository entry confirms the install used the packaged archive.

## What you learned

- `version` versions the chart, `appVersion` describes the application and doubles as the default image tag; `helm package --version` and `--app-version` set them at build time.
- A package must embed its dependencies: `--dependency-update` or `helm dependency build` first, or the package fails.
- A classic repository is `index.yaml` (from `helm repo index --url`) plus archives behind any HTTP server; `helm repo add`, `update` and `search` work on a cached copy of the index.
- Pre-release versions stay hidden unless you ask with `--devel`, and installs should always pin `--version`.

The failure modes look alike in a CI log: a missing dependency fails at package time, a stale index fails at search time (the new version is missing), and a wrong `--url` fails at install time with a download error for an address that only worked on the machine that built the index. Each has the same remedy, which is to rebuild the index from the directory you are about to publish and to run `helm repo update` on the client.

Next, the same archive moves into an OCI registry, where the version is a tag and the content can be pinned by digest.

## Further reading

- Matt Butcher, Matt Farina, Josh Dolitsky, *Learning Helm* (O'Reilly, 2021), ISBN 9781492083641. Used here for: the concept of a chart repository as an index plus archives.
- Helm documentation, [The Chart Repository Guide](https://helm.sh/docs/topics/chart_repository/) and [`helm package`](https://helm.sh/docs/helm/helm_package/).
- Helm documentation, [Charts: the Chart.yaml file](https://helm.sh/docs/topics/charts/) for `version` and `appVersion`.
- [Semantic Versioning 2.0.0](https://semver.org/).

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/19-packaging-repos.txt` and `_plans/evidence/19-published-repo.txt`. Against the live Pages URL on 2026-10-08, `helm repo add hfd` succeeded, `helm search repo hfd` listed all six charts at 1.0.0, and `helm pull` plus `helm template` of `hfd/shipping-platform` rendered 15 objects from the packaged subcharts. Observed on Helm 4.3.0 and minikube: `helm package` without `--dependency-update` failed with `missing in charts/ directory: pc-lib`; `--version` and `--app-version` changed the file name and the rendered image tag (`shipping-service:0.1.1`); the index digest equalled the `sha256sum` of the archive; `helm search repo` hid `1.1.0-rc.1` until `--devel`; `1.0` and `v1.0.2` were accepted as written; `helm pull -d` into a missing directory failed; the archive kept `templates/tests/`; the install from `hfd-local` reached Ready, `helm get metadata` reported chart 1.0.0 and appVersion 0.1.0, and `/api/info` answered on the published NodePort. Re-run on r1.1 with published NodePorts (bound to 127.0.0.1) on 2026-10-08: `./demo.sh` exited 0 and `./demo.sh clean` removed the namespace; the local repository served the chart and the install from it reached deployed (the demo only prints the `curl http://127.0.0.1:30080/api/info` hint, so that request was not exercised).*
