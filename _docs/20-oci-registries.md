---
title: "OCI registries"
order: 20
part: "Distribution and supply chain"
description: "Push the shipping-service 1.0.0 package to an OCI registry, pull and inspect it, log in, pin an install by digest, and pull a dependency from a registry."
duration: 35 minutes
---

A classic repository needs an index file that someone has to regenerate and host. An OCI registry already stores versioned, content-addressed artifacts, so Helm stores the chart there directly: the version is a tag, the content is a digest, and there is no `index.yaml`. This chapter pushes the `1.0.0` package from chapter 19 to a registry running on your machine, then walks through pull, login, install by digest and OCI dependencies.

The code is in `examples/20-oci/`. `./demo.sh offline` packages without a registry; `./demo.sh` starts two registry containers and runs the whole flow.

{% include excalidraw.html
   file="20-oci-flow"
   alt="Diagram: a packaged chart is pushed with helm push into an OCI registry, where a manifest points at a config layer and a chart layer and optionally a provenance layer; helm pull, helm install by digest and helm dependency update read it back"
   caption="Figure 20.1 — What helm push stores in a registry and who reads it back" %}

## What a registry holds

The `helm push` command uploads one OCI image manifest. It references a config blob (`application/vnd.cncf.helm.config.v1+json`, the chart metadata) and one layer for the archive (`application/vnd.cncf.helm.chart.content.v1.tar+gzip`). When the archive has a `.prov` file next to it, a second layer carries it (chapter 21). The repository path comes from the push target plus the chart name, and the tag comes from the chart `version`. Pushing `shipping-service-1.0.0.tgz` to `oci://127.0.0.1:5001/charts` creates `charts/shipping-service:1.0.0`.

Two digests exist, and they answer different questions. The chart layer digest is the SHA-256 of the `.tgz`, the same value `index.yaml` showed in chapter 19. The manifest digest is what `helm push` prints as `Digest:` and what a registry uses to address the whole artifact. Pin the manifest digest when you want an install that cannot change underneath you, because a tag is a mutable pointer and a digest is not.

The Helm documentation describes the registry commands and the `oci://` reference format in [Use OCI-based registries](https://helm.sh/docs/topics/registries/), including installing by digest ("digests are immutable"). The [Helm 4 release announcement](https://helm.sh/blog/helm-4-released/) adds content-based caching and reproducible builds, which matter in chapter 21. Every command below was checked against `helm <command> --help` from Helm 4.3.0.

## How the code works

`demo.sh` is the walk-through; each function maps to a section of the flow.

**Starting registries.** The reference implementation of a registry is the `registry:2` image (the CNCF Distribution project, documented at [distribution.github.io](https://distribution.github.io/distribution/)). The script runs it twice:

```bash
[host]$ docker run -d --name hfd-registry -p 127.0.0.1:5001:5000 docker.io/library/registry:2
```

Binding to `127.0.0.1` keeps the registry off the network. The second container, `hfd-registry-auth` on port 5002, enables `REGISTRY_AUTH=htpasswd` and reads a bcrypt file created with `htpasswd -Bbn`. The script uses `create`, `cp` and `start` rather than a bind mount because some container engines refuse mounts outside configured shared paths; that happened on the authoring machine. `ENGINE=podman` swaps the engine.

**Push.** The first attempt leaves out `--plain-http` to show the failure:

```text
Error: failed to perform "Exists" on destination: Head "https://127.0.0.1:5001/v2/charts/shipping-service/manifests/sha256:...": http: server gave HTTP response to HTTPS client
```

Helm assumes HTTPS. The local registry has no certificate, so every command that contacts it needs the flag:

```bash
[host]$ helm push .work/pkg/shipping-service-1.0.0.tgz oci://127.0.0.1:5001/charts --plain-http
```

The target is a path without the chart name or tag; Helm appends both from the archive. The output is `Pushed: 127.0.0.1:5001/charts/shipping-service:1.0.0` and a `Digest: sha256:...` line, which the script captures with `awk` for the later steps. The registry API confirms the result:

```bash
[host]$ curl -s http://127.0.0.1:5001/v2/charts/shipping-service/tags/list
```

```text
{"name":"charts/shipping-service","tags":["1.0.0"]}
```

**Show and pull.** `helm show chart`, `helm show values` and `helm pull` accept `oci://` references with `--version`:

```bash
[host]$ helm show chart oci://127.0.0.1:5001/charts/shipping-service --version 1.0.0 --plain-http
[host]$ helm pull oci://127.0.0.1:5001/charts/shipping-service --version 1.0.0 --plain-http -d .work/pull
```

`sha256sum` of the pulled archive printed `f8d507c0...`, identical to the digest in chapter 19's `index.yaml`. The archive is the same bytes; only the transport changed.

**Digest references.** Append `@sha256:<manifest digest>` to the chart path and drop `--version`:

```bash
[host]$ helm pull oci://127.0.0.1:5001/charts/shipping-service@sha256:<manifest digest> --plain-http -d .work/pull
```

Helm saves the archive as `shipping-service@sha256-<digest>.tgz`. The same reference works on `helm template` and on `helm install`; the demo installs this way:

```bash
[host]$ helm upgrade --install shipping oci://127.0.0.1:5001/charts/shipping-service@sha256:<manifest digest> --plain-http -n hfd-20 --create-namespace --set service.type=NodePort --set service.nodePort=30080 --wait --rollback-on-failure
```

If someone re-pushes a different chart to tag `1.0.0`, the tag moves and this install does not. In the demo run, pushing the same archive to both registries produced the same manifest digest (`sha256:a16196c9...`), so a digest you recorded stays valid after you mirror the artifact to another registry.

That property is why the signing flow in chapter 21 signs a digest and not a tag: a reference that names bytes is something you can verify, and a reference that names a tag is something you have to trust.

**Login.** The auth registry refuses an unauthenticated push with `basic credential not found`. Credentials go through standard input so they stay out of shell history and the process list:

```bash
[host]$ echo hfd-pass | helm registry login 127.0.0.1:5002 -u hfd --password-stdin --plain-http
```

Helm writes them to `registry/config.json` under `HELM_CONFIG_HOME`, which `env.sh` points inside the project. `helm registry logout 127.0.0.1:5002` removes them. The host argument is a registry name with an optional port, never a URL scheme or a path. For a real registry such as `ghcr.io`, use a scoped token as the password.

**OCI dependencies.** A dependency can name a registry as its `repository`, using the path without a chart name:

```yaml
dependencies:
  - name: pc-lib
    version: 1.0.0
    repository: oci://127.0.0.1:5001/charts
```

The script pushes `pc-lib` first, rewrites that line in a copy of the chart, and runs `helm dependency update --skip-refresh --plain-http`. Helm prints `Downloading pc-lib from repo oci://127.0.0.1:5001/charts`, saves `charts/pc-lib-1.0.0.tgz` and writes `Chart.lock`; `helm dependency list` reports status `ok`. `--skip-refresh` avoids contacting the classic repositories configured on the machine.

**The minikube registry addon.** The cluster has its own registry on node port 5000. `scripts/tunnel.sh start registry` forwards it to `127.0.0.1:5000`, and `REGISTRY_ADDON=1 ./demo.sh` pushes the same archive with `oci://127.0.0.1:5000/charts --plain-http`. Argo CD uses that registry in chapter 25. The minikube [registry handbook](https://minikube.sigs.k8s.io/docs/handbook/registry/) covers the addon itself.

## Build, run, observe

```bash
[host]$ cd examples/20-oci && ./demo.sh
```

The demo prints a heading per step, in this order: registries start, push without and with `--plain-http`, tag list, show and pull by tag, SHA-256 comparison, pull by digest, push to the authenticated registry before and after login, the OCI dependency, and the install by digest. Each failing command is expected where the heading says so; the script continues past them with `|| true` and stops on any unexpected error.

The demo stops after the install and leaves both registries running so you can query them with `curl` against `/v2/_catalog`. Remove everything with `./demo.sh clean`.

## Troubleshooting

Four failures account for most registry problems, and each prints a message that names the cause.

- **`server gave HTTP response to HTTPS client`.** Helm assumes TLS for every registry. A local `registry:2` container speaks plain HTTP, so `helm push`, `pull`, `show` and `dependency update` all need `--plain-http`. A registry behind real TLS never needs the flag; if you find yourself adding it for a production host, the URL scheme or the proxy is wrong.
- **`basic credential not found`.** The registry requires authentication and Helm found no stored credential for that host. Run `helm registry login 127.0.0.1:5002 --username demo --password-stdin --plain-http` and pipe the password in. Credentials live in the registry config under `HELM_CONFIG_HOME`, which the project-local `scripts/env.sh` keeps separate from any other Helm installation on the machine.
- **A tag points at different bytes than yesterday.** Pushing `1.0.0` again replaces the tag's manifest, and nothing in the registry objects. Consumers that pinned the tag follow it silently. Consumers that pinned `@sha256:<manifest digest>` keep getting the original content, or fail if the registry has garbage-collected it. Treat tags as mutable and digests as the record of what shipped.
- **`helm dependency update` contacts unrelated repositories.** The command refreshes every classic repository configured on the machine before it resolves dependencies, so an unreachable one slows or breaks an OCI-only update. `--skip-refresh` skips that step, which is correct whenever every dependency comes from an `oci://` URL.

One environment detail belongs to the demo, not to Helm. The authenticated registry needs an `htpasswd` file inside the container. A bind mount from a scratch directory was denied on the authoring machine, so the script uses `docker create`, `docker cp` and `docker start` to place the file. If you adapt the demo to rootless podman, expect to adjust that step.

## Cross-check

Compare the registry's view with Helm's. `curl -H 'Accept: application/vnd.oci.image.manifest.v1+json' http://127.0.0.1:5001/v2/charts/shipping-service/manifests/1.0.0` returns a manifest whose chart layer digest matches `sha256sum` of the pulled archive. `helm get metadata shipping -n hfd-20` reports the installed chart version `1.0.0`. Two independent views of the same bytes confirm the pull path did not alter the chart.

## What you learned

- Helm stores a chart as an OCI artifact: tag from the chart version, a config blob, a chart layer, and an optional provenance layer.
- `--plain-http` is required for an HTTP registry, and `helm registry login --password-stdin` keeps credentials out of the command line.
- `oci://host/path/chart@sha256:<manifest digest>` pins an install to exact content; a tag can move.
- Dependencies can come from an OCI registry with `repository: oci://host/path`.

Chapter 21 signs both the package and the registry artifact so a consumer can check who published it.

## Further reading

- Helm documentation, [Use OCI-based registries](https://helm.sh/docs/topics/registries/).
- Helm project, [Helm 4 release announcement](https://helm.sh/blog/helm-4-released/) (content-based caching, reproducible builds).
- Helm documentation, [`helm push`](https://helm.sh/docs/helm/helm_push/).
- CNCF Distribution, [registry documentation](https://distribution.github.io/distribution/).
- minikube, [Registry addon handbook](https://minikube.sigs.k8s.io/docs/handbook/registry/).

---

*Verification status: <span class="status status--unverified">unverified</span>. To confirm on a live run: install by digest reaches Ready in `hfd-20`, the registry addon push through `scripts/tunnel.sh start registry` succeeds, and a tag re-pushed with different content does not affect the digest install.*
