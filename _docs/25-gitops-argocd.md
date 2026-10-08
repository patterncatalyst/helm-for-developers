---
title: "GitOps with Argo CD"
order: 25
part: "Delivery and operations"
description: "Install Argo CD from its Helm chart and let it sync the umbrella chart from an OCI registry. Covers valueFiles and valuesObject, how helm hooks map to sync hooks, why lookup returns nothing, and sync waves."
duration: 40 minutes
---

Chapter 24 promoted a chart by running Helmfile from a workstation. GitOps moves the running of `helm` into the cluster: a controller watches a declared source and keeps the namespace equal to it. This chapter installs Argo CD with Helm, points an `Application` at the umbrella chart in the registry addon, and works through the one thing that surprises Helm users: Argo CD renders charts but does not install them as Helm releases.

The code is in `examples/25-gitops-argocd/`. Run `./demo.sh offline` there for the checks that need no cluster; its `README.md` lists the rest.

{% include excalidraw.html file="25-gitops-loop" alt="Argo CD's repo server fetches a chart from an OCI registry or Git, runs helm template with value files and inline values, and hands manifests to the application controller. The controller applies them to namespace hfd-25 in PreSync, Sync and PostSync phases." caption="Figure 25.1 — The Argo CD loop around a Helm chart" %}

## The loop

GitOps rests on a few principles: the desired state is declared, the declaration is versioned and immutable, an agent pulls it, and the agent keeps reconciling, which also corrects drift. Argo CD is that agent. Its repo server fetches the source and renders manifests. Its application controller compares them with live objects and applies the difference. With `syncPolicy.automated`, `selfHeal` reverts manual edits and `prune` removes objects that left the source.

For a Helm chart, "renders" is literal. Argo CD runs `helm template`, not `helm install`. The consequences, in order of how often they bite:

- **There is no Helm release.** `helm list -n hfd-25` shows nothing and there is no `sh.helm.release.v1.*` Secret. Argo CD tracks objects through its own tracking label and the Application's status.
- **`lookup` returns an empty map.** Rendering happens without a live API call, so a template that reads a Secret with `lookup` takes its "not found" branch on every sync. The golden charts do not use `lookup`; a chart that generates a password once and reuses it (chapter 8) would regenerate it on each render. Use `existingSecret` under Argo CD.
- **Helm hooks become Argo CD hooks.** Argo CD maps `pre-install` and `pre-upgrade` to `PreSync`, `post-install` and `post-upgrade` to `PostSync`, and `helm.sh/hook-weight` to a sync wave. Argo CD cannot tell install from upgrade, so every sync runs both. `test` hooks have no equivalent and are ignored, so `helm test` does not apply. If a chart defines any native Argo CD hook, Argo CD ignores all its Helm hooks.

## Installing Argo CD with Helm

Argo CD itself is a Helm chart, so everything from the earlier chapters applies. The example pins chart `argo/argo-cd` 10.10.1 (Argo CD v3.5.4), the latest stable at the time of writing.

```yaml
dex:
  enabled: false
notifications:
  enabled: false
server:
  service:
    type: NodePort
    nodePortHttps: 30443
    nodePortHttp: 30082
```

`dex` and `notifications` are off to keep the footprint small; the lab logs in as `admin` with the password in `argocd-initial-admin-secret`. The Service becomes a NodePort so `scripts/tunnel.sh argocd` can map `127.0.0.1:8443` to node port 30443. `nodePortHttp: 30082` avoids a collision. The chart's default HTTP node port is 30080, which is shipping's port in this book, and Kubernetes rejects two Services on one node port. The chart ships its CRDs as templates; under Helm 4's server-side apply default, the large `Application` CRD applies without the annotation-size error that client-side apply can hit.

The install in `demo.sh` is `helm upgrade --install argocd argo/argo-cd --version 10.10.1 -n argocd --create-namespace -f argocd-values.yaml --wait --timeout 10m --rollback-on-failure`. `--rollback-on-failure` rolls a failed install back and defaults `--wait` to the watcher; see the [Helm 4 announcement](https://helm.sh/blog/helm-4-released/).

## How the code works

The registry addon runs inside the cluster as `registry.kube-system.svc.cluster.local:80` and speaks plain HTTP. Argo CD needs to be told this once, through a repository Secret:

```yaml
metadata:
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: helm
  url: registry.kube-system.svc.cluster.local:80/charts
  enableOCI: "true"
  insecureOciForceHttp: "true"
```

The label makes Argo CD read the Secret as a repository definition. `type: helm` with `enableOCI: "true"` says the URL is an OCI registry, and the URL has no `oci://` prefix; that is Argo CD's convention. `insecureOciForceHttp` is the equivalent of Helm's `--plain-http`. The demo pushes the chart first with `helm push shipping-platform-1.0.0.tgz oci://127.0.0.1:5000/charts --plain-http`, reaching the same registry through the tunnel.

The `Application` then names the chart:

```yaml
source:
  repoURL: registry.kube-system.svc.cluster.local:80/charts
  chart: shipping-platform
  targetRevision: 1.0.0
  helm:
    releaseName: platform
    valueFiles:
      - values-dev.yaml
    valuesObject:
      shipping:
        config:
          defaultCarrier: ARGO-Post
```

`repoURL` plus `chart` plus `targetRevision` resolve to one artifact, and the exact version is the promotion pin from chapter 24. `releaseName` sets `.Release.Name`; without it Argo CD uses the Application name, and here both are `platform`, which gives the Service names `platform-shipping` and `platform-notification` that the NOTES and tests expect. `valueFiles` entries are paths inside the chart package, so `values-dev.yaml` is the file that shipped in the tarball. `valuesObject` is inline YAML. Argo CD's precedence is parameters, then `valuesObject`, then `values`, then `valueFiles`, then the chart's `values.yaml`; with several `valueFiles`, the last wins. The `defaultCarrier` override is visible at `/api/info`.

`destination.namespace: hfd-25` with `CreateNamespace=true` creates the namespace. `ServerSideApply=true` makes Argo CD use server-side apply, matching Helm 4's default.

A second manifest, `apps/shipping-platform-git.yaml`, sources the same chart from `https://github.com/patterncatalyst/helm-for-developers` at `path: charts/shipping-platform`. It is pending: the repository does not exist until the project is pushed, and the demo does not apply it. Argo CD resolves the `file://` dependencies from the checkout.

## Sync waves and hook weights

The umbrella's migration Job is `post-install,post-upgrade` with weight 0 (chapters 11 and 16). Under Argo CD that is a PostSync hook, which runs after every non-hook resource is Healthy. This is why chapter 16's readiness change matters: the shipping pods must become Ready on `/health` before the hook that creates the tables can run, the same ordering Helm enforced with `--wait`.

Within a phase, order comes from weights and waves. Helm's `helm.sh/hook-weight` becomes `argocd.argoproj.io/sync-wave` for hooks, with lower numbers first. Regular resources have no weight, so they carry the wave 0 default; add `argocd.argoproj.io/sync-wave` annotations to order them, for example the CNPG `Cluster` at wave -1 before the services. The two mechanisms look alike but differ in scope: hook weights order hooks inside one phase, and waves order everything across the sync. The umbrella has no wave annotations, so Kafka and Postgres start in parallel with the services, and the services restart until their dependencies answer, as in chapter 15.

## Build, run, observe

```
[host]$ cd examples/25-gitops-argocd && ./demo.sh offline
```

Offline mode renders Argo CD's chart under Helm 4 through kubeconform, renders the umbrella the way Argo CD would (`values-dev.yaml`, then the `valuesObject` extracted from the manifest), confirms the override reached the output, lists the hook annotations that become sync hooks, and parses the manifests. The full run, `./demo.sh`, installs Argo CD, pushes the chart, applies the Secret and the Application and waits for `Synced` and `Healthy`. Open `https://127.0.0.1:8443` after `scripts/tunnel.sh argocd`, accept the self-signed certificate, and log in as `admin`.

## Cross-check

Ask the cluster what Argo CD created:

```
[host]$ kubectl -n hfd-25 get deploy,job,svc
[host]$ helm list -n hfd-25
```

The first shows the workloads; the second prints an empty table. Together they confirm that Argo CD rendered and applied the chart without creating a release.

## What you learned

- Argo CD installs from a Helm chart and syncs a chart by running `helm template`; there is no Helm release, `lookup` is empty and `helm test` does not apply.
- An OCI source needs a repository Secret (`enableOCI`, plus `insecureOciForceHttp` for the plain-HTTP lab registry) and an exact `targetRevision`.
- `valueFiles` and `valuesObject` layer like `-f` and `--set`; hooks map to PreSync and PostSync, and weights map to sync waves.

The last chapter in this part uses the same umbrella to follow a request through the LGTM stack.

## Further reading

- Argo CD, Helm user guide (rendering, hooks, value precedence): <https://argo-cd.readthedocs.io/en/stable/user-guide/helm/>
- Argo CD, sync phases and waves: <https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/>
- Helm 4 release announcement: <https://helm.sh/blog/helm-4-released/>
- Helm chart hooks: <https://helm.sh/docs/topics/charts_hooks/>
- Billy Yuen et al., *GitOps and Kubernetes* (Manning, 2021), ISBN 9781617297274. Used here for: GitOps principles (declarative state, pull-based reconciliation, drift correction).
- Mauricio Salatino, *Platform Engineering on Kubernetes* (Manning, 2024), ISBN 9781617299322. Used here for: continuous delivery as a platform capability.
- Andrew Block and Austin Dewey, *Managing Kubernetes Resources Using Helm* (Packt, 2022), ISBN 9781803242897. Used here for: Argo CD concepts (applications and sync).

---

*Verification status: <span class="status status--unverified">unverified</span>. The OCI repository Secret over plain HTTP, the Application reaching Synced and Healthy, the PostSync migration, and the empty `helm list` need a real run.*
