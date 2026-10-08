---
title: "Environment promotion"
order: 24
part: "Delivery and operations"
description: "Run one umbrella chart in dev, stage and prod with layered values files, per-environment namespaces and version pins, and promote by changing a version line in Helmfile."
duration: 35 minutes
---

The umbrella chart from chapter 16 already carries `values-dev.yaml`, `values-stage.yaml` and `values-prod.yaml`. This chapter turns them into a promotion process: one chart build, three environments, and a promotion that is a reviewed change to a version pin rather than a rebuild. Helmfile 1.8.1 holds the pins. You need no cluster for the offline checks.

The code is in `examples/24-environments/`. Run `./demo.sh offline` there; its `README.md` lists the other modes.

{% include excalidraw.html file="24-promotion-flow" alt="A chart package and an image digest are built once, then promoted through dev, stage and prod. Each environment layers its own values file and pin file and installs into its own namespace, and helmfile.yaml records the versions." caption="Figure 24.1 — Build once, promote by editing pins" %}

## What an environment is

An environment in this chapter is three things: a namespace, a stack of values files, and a pair of pins. The namespace separates the releases (`hfd-24-dev`, `hfd-24-stage`, `hfd-24-prod`), and every environment uses the same release name, `platform`. Helm stores release state per namespace, so identical names do not collide.

The values stack has two layers. The chart's own `values.yaml` holds defaults that make sense everywhere. `values-<env>.yaml` ships inside the chart and holds what differs by environment: replica counts, log levels, Kafka replication, where the API token comes from. A second file, `pins/<env>.yaml`, lives outside the chart and holds only what a promotion changes: the image reference. Later files win, so the order is chart defaults, environment values, pins.

Keeping the pins outside the chart matters. A chart version is an immutable artifact (chapters 19 and 20). If the image tag lived in the chart, promoting an image would mean publishing a new chart. With a separate file, the chart stays the same and the pin file changes.

## Pins: chart version and image digest

Two pins identify what runs in an environment. The chart pin is an exact version such as `1.0.0`, never a range, because a range lets the registry decide what prod installs. The image pin is a tag plus a digest. A tag is a movable label: pushing `0.1.0` again changes what every node pulls next. A digest names the content. The reference `shipping-service:0.1.0@sha256:...` keeps the human-readable tag and adds the content check, and the container runtime resolves by digest when both are present.

The golden charts accept this without changes. `pc-lib.image` formats `repository:tag`, and the `tag` value is a free string, so a value of `0.1.0@sha256:<digest>` renders as a valid reference. Dev follows a tag so developers see their pushes. Stage and prod carry digests.

## How the code works

`helmfile.yaml` has no template syntax. Helmfile 1.x only evaluates Go templates in files named `*.gotmpl`; a plain `helmfile.yaml` containing `{% raw %}{{ .Environment.Name }}{% endraw %}` fails with "Started seeing this since Helmfile v1?". The file is therefore explicit: three releases, written out.

```yaml
helmDefaults:
  wait: true
  timeout: 600
  createNamespace: true
  rollbackOnFailure: true
```

`helmDefaults` applies to every release. `wait` and `timeout` map to Helm's `--wait` and `--timeout`. `rollbackOnFailure` maps to Helm 4's `--rollback-on-failure`; Helmfile refuses the setting under Helm 3, and it is mutually exclusive with the older `atomic`. `createNamespace` creates the per-environment namespace on first install.

```yaml
releases:
  - name: platform
    namespace: hfd-24-prod
    chart: ./charts/shipping-platform
    version: 1.0.0
    labels:
      env: prod
    values:
      - charts/shipping-platform/values-prod.yaml
      - pins/prod.yaml
```

`name` plus `namespace` identify a release, so three releases called `platform` coexist. `labels` give you selectors: `helmfile -l env=prod template` acts on one environment. `values` is the layering, in order. `version` is the chart pin, and it is the line a promotion edits.

One limit matters. For a chart given as a local path, Helmfile does not compare `version:` with the chart on disk. Changing it to `1.0.1` renders the same chart. The pin becomes an enforced constraint only when the chart comes from a repository or registry, as in `chart: oci://registry.example.com/charts/shipping-platform` with `version: 1.0.0`. The example uses a path so that it renders offline; the OCI form is what you run once chapter 20's registry is part of your pipeline.

`pins/dev.yaml` sets `shipping.image.tag` and `notification.image.tag` to `0.1.0`. `./demo.sh pin stage` replaces `pins/stage.yaml` with a digest it reads from the registry addon: it pushes the images, reads the `Docker-Content-Digest` header for `shipping-service:0.1.0`, and writes `tag: "0.1.0@sha256:..."` together with `global.imageRegistry: localhost:5000`. Only `shipping-service` is pinned this way; extend the script for the second image.

The offline mode checks four things beyond a clean render. It lints each environment with `helm lint --strict`. It pipes `helmfile template --skip-deps` output through kubeconform for all three environments. It extracts the shipping Deployment's `replicas` from the rendered output and expects 3 for prod and 1 for dev, which proves the layering. It renders prod with a synthetic digest and expects `image: "shipping-service:0.1.0@sha256:..."` in the pod spec. The digest there is derived from a fixed string; it checks syntax only.

`--skip-deps` stops Helmfile from running `helm repo update` and rebuilding dependencies on every call. The demo runs `helm dependency build` on the umbrella first.

## Why layers, not copies

The alternative to layering is a full values file per environment. It looks safer because each file is complete, but the three files drift: a new chart value gets added to dev and forgotten in prod, and the first sign is a behavior difference nobody can explain. With layers, `values.yaml` is the single place a default lives. An environment file lists only differences, so reading `values-prod.yaml` answers the question "how does prod differ?" directly. The schema in `values.schema.json` catches misspelled keys in any layer, and `helm lint --strict` in the offline mode runs it against each environment's full stack.

The same reasoning separates the pin file from the environment file. `values-prod.yaml` changes when prod's shape changes, which is rare and deliberate. `pins/prod.yaml` changes on every promotion. Different change rates belong in different files, with different reviewers if you want that.

## Promotion by version bump

A promotion is a commit. A new chart build 1.1.0 lands in dev first: edit dev's `version:` line and `pins/dev.yaml`, run `helmfile -l env=dev apply`, and watch it. Stage follows with the same edit in its release block, then prod. At each step the diff shows exactly which version and image moved, and `helmfile -l env=stage diff` (using the helm-diff plugin) shows the manifest change before it applies. Rolling back is reverting the commit and applying again.

Secrets stay out of this flow. Stage and prod set `shipping.auth.existingSecret: shipping-api-token`, so the token Secret has to exist in each namespace before the first sync; the pin files carry no credentials.

Platform teams often wrap this in an internal developer platform that owns the environment list and the promotion gates; the principle of one artifact moving through environments is the same.

## Build, run, observe

```
[host]$ cd examples/24-environments && ./demo.sh offline
```

Expect three kubeconform summaries with zero invalid resources and `offline: OK`. The full run builds the images, runs `helmfile -l env=dev sync --skip-deps` and then `helm test platform -n hfd-24-dev`. After `scripts/tunnel.sh shipping`:

```
[host]$ curl -s http://127.0.0.1:8080/api/info
```

The response reports `"environment":"dev"`. Dev claims NodePorts 30080 and 30081, so only one release using them can run at a time.

## Cross-check

Compare what Helmfile renders with what Helm renders directly. These two commands produce the same Deployment for prod:

```
[host]$ helm template platform charts/shipping-platform -n hfd-24-prod -f charts/shipping-platform/values-prod.yaml -f pins/prod.yaml
[host]$ helmfile -l env=prod template --skip-deps
```

Helmfile adds nothing to the manifests; it assembles the same `helm` invocation, which is why the layering check holds for both.

## What you learned

- An environment is a namespace, a values stack (chart defaults, `values-<env>.yaml`, a pin file) and two pins.
- Pin charts to exact versions and images to tag plus digest; promote by editing the pins and reviewing the diff.
- Helmfile 1.8.1 drives Helm 4, including `rollbackOnFailure`, but it enforces `version:` only for repository and OCI charts.

The next chapter hands the reconcile loop to Argo CD, which reads the same chart from a registry and applies it for you.

## Further reading

- Helm 4 release announcement: <https://helm.sh/blog/helm-4-released/>
- Reference for installing a chart, including the wait and rollback flags: <https://helm.sh/docs/helm/helm_install/>
- Helmfile 1.8.1 release: <https://github.com/helmfile/helmfile/releases/tag/v1.8.1>
- Mauricio Salatino, *Platform Engineering on Kubernetes* (Manning, 2024), ISBN 9781617299322. Used here for: promoting one artifact through environments as a platform practice.
- Ajay Chankramath et al., *Effective Platform Engineering* (Manning, 2025), ISBN 9781633436497. Used here for: environments and paved-road delivery as platform concerns.

---

*Verification status: <span class="status status--unverified">unverified</span>. A live `helmfile -l env=dev sync`, `helm test`, and a `./demo.sh pin` digest that the node can pull need a real run.*
