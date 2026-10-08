---
title: "Your first chart"
order: 4
part: "From manifests to a chart"
description: "Build the shipping-service chart by hand from the three raw manifests, install it as a release, upgrade and roll it back, and find the release record Helm stores in the cluster."
duration: 40 minutes
---

Chapter 03 ended with nine copied files. This chapter replaces them with one chart: a directory with a metadata file, a defaults file and three templates, installed under a release name. The new ideas are chart anatomy, the difference between a chart `version` and an `appVersion`, and the release record that makes `upgrade`, `history` and `rollback` possible.

The code is in `examples/04-first-chart/`. `./demo.sh offline` lints and renders the chart without a cluster; `./demo.sh` installs it into `hfd-04`, upgrades it and rolls it back.

{% include excalidraw.html
   file="04-chart-anatomy"
   alt="Diagram: a shipping-service chart directory with Chart.yaml, values.yaml, templates and .helmignore feeds the helm client, which applies a Deployment, Service and ConfigMap and stores the release record as a Secret in the cluster"
   caption="Figure 4.1 — A chart directory is rendered by the client; the release record is stored in the cluster" %}

## helm create and a lean chart

`helm create shipping-service` generates a working chart. In Helm 4.3.0 it writes `Chart.yaml`, `values.yaml`, `.helmignore`, and under `templates/` a deployment, service, service account, HPA, ingress, HTTPRoute, `_helpers.tpl`, `NOTES.txt` and a test pod. That is a useful reference and too much to start from, because most of the files and conditionals solve problems the shipping service does not have yet. The chart here is built the other way: start with the raw manifests and replace only what must change per release. `./demo.sh offline` prints the generated file list so you can compare.

## How the code works

**`Chart.yaml`** is the only required file besides `templates/`.

```yaml
apiVersion: v2
name: shipping-service
type: application
version: 0.4.0
appVersion: "0.1.0"
```

`apiVersion: v2` is the chart format Helm 3 introduced and Helm 4 still uses; chart API v3 is not released. `name` becomes `.Chart.Name` and is part of every resource name below. `type: application` is the default and means the chart can be installed; the alternative, `library`, is chapter 17. `version` identifies the chart package and follows SemVer. `appVersion` identifies the application the chart deploys, and the two move independently: a template fix bumps `version`, a new image bumps `appVersion`. The chart's `version` follows the chapter number (0.4.0) until chapter 19. `appVersion` is quoted because `0.1.0` is a string and an unquoted `1.10` would be read as the number 1.1.

**`values.yaml`** holds the defaults that templates read through `.Values`: `replicaCount`, the `image` block and the `service` block. It contains only what the templates use so far; chapter 05 designs the full interface.

**`templates/*.yaml`** are the chapter 03 manifests with a few expressions. Three kinds appear:

```yaml
{% raw %}name: {{ .Release.Name }}-{{ .Chart.Name }}
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
{{- if .Values.service.nodePort }}{% endraw %}
```

`.Release.Name` comes from the first argument to `helm install`, so one chart can be installed twice in one namespace without a name clash. Joining it to `.Chart.Name` gives `shipping-shipping-service` for release `shipping`. `.Values.image.tag | default .Chart.AppVersion` pipes the tag into `default`, so an empty tag falls back to the application version and the image tag tracks `appVersion` without a second edit. The `if` wraps the `nodePort` line and the `{% raw %}{{-{% endraw %}` trims the newline before it, so no blank line is left when the value is `null`. Chapter 06 covers these constructs in full.

The selector labels are `app.kubernetes.io/name` and `app.kubernetes.io/instance`. The instance label is the release name, which keeps two releases of the same chart from selecting each other's pods.

**`.helmignore`** lists files left out when the chart is packaged and loaded, with `.gitignore` syntax. The entry is `/tests/` with a leading slash so that it matches only the top-level `tests/` directory. An unanchored `tests/` would also match `templates/tests/`, which chapter 14 relies on.

The fragile bits: the resource name is built inline in four places (`{% raw %}{{ .Release.Name }}-{{ .Chart.Name }}{% endraw %}`) and the labels are repeated in each file. A typo in one of them produces a Service that selects nothing. Chapter 07 removes the repetition with named templates.

## Install, upgrade, roll back

```bash
cd examples/04-first-chart && ./demo.sh
```

The live part of the script runs these commands, plus `--set` flags that make the Service a NodePort on 30080, a port the profile publishes to the host.

```bash
[host]$ helm lint examples/04-first-chart/shipping-service
[host]$ helm template shipping examples/04-first-chart/shipping-service
[host]$ helm upgrade --install shipping examples/04-first-chart/shipping-service -n hfd-04 --create-namespace --wait
[host]$ helm list -n hfd-04
[host]$ helm upgrade shipping examples/04-first-chart/shipping-service -n hfd-04 --reuse-values --set replicaCount=2 --wait
[host]$ helm history shipping -n hfd-04
[host]$ helm rollback shipping 1 -n hfd-04 --wait
[host]$ helm history shipping -n hfd-04
```

The `helm lint` command checks the chart structure and renders it once. `helm template` renders without contacting a cluster, which is how you read the YAML before it exists in the cluster. For Helm 4's `--wait` strategies (`watcher`, `hookOnly`, `legacy`), see the [`helm install` reference](https://helm.sh/docs/helm/helm_install/); chapter 12 covers them. Here `--wait` blocks until the pods are ready.

Observed output, from `./demo.sh offline` with Helm 4.3.0:

```text
==> Linting ./shipping-service
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

The `icon` message is informational. `helm template --show-only templates/service.yaml` renders the Service with the release name in place:

```text
  name: shipping-shipping-service
  ...
  selector:
    app.kubernetes.io/name: shipping-service
    app.kubernetes.io/instance: shipping
```

After the rollback, `helm history` lists revision 1 (install), 2 (upgrade) and 3 (rollback to 1). A rollback does not rewind the counter: it creates revision 3 with the contents of revision 1. By default Helm keeps the latest ten revisions per release (`--history-max`).

## What an install does

An install and a `helm upgrade --install` run the same sequence. Helm merges the values, renders the templates, parses the output as Kubernetes objects and validates them against the cluster's OpenAPI schema. It then writes the revision Secret with status `pending-install`, applies the objects, and updates the Secret to `deployed`, or `failed` if the apply or the wait fails. Helm 4 applies objects with server-side apply by default for new releases (`--server-side` is true on install, and `auto` on upgrade follows the method the previous revision used); the [`helm install` reference](https://helm.sh/docs/helm/helm_install/) lists the flags, and chapter 12 covers field-manager conflicts. `helm upgrade --install` is the form to use in scripts, because the same command works for the first release and every later one. Add `--dry-run=client` to render and validate without touching the cluster.

## Where the release lives

Helm has no server. Each revision is stored in the cluster as a Secret in the release's namespace, so any machine with access to the namespace sees the same releases.

{% include excalidraw.html
   file="04-release-revisions"
   alt="Diagram: three revisions of release shipping, install, upgrade to two replicas and rollback to one, each stored as a Secret named sh.helm.release.v1.shipping.v1, v2 and v3"
   caption="Figure 4.2 — Every install, upgrade and rollback writes one revision Secret" %}

```bash
[host]$ kubectl -n hfd-04 get secrets -l owner=helm
```

The listing shows one Secret per revision, named `sh.helm.release.v1.shipping.vN`, with type `helm.sh/release.v1`. The Secret holds the chart, the merged values, the rendered manifest and the status, compressed. This is what `helm get values`, `helm get manifest` and `helm rollback` read. The `HELM_DRIVER` environment variable chooses the backend: `secret` is the default, and `configmap` and `sql` are the alternatives; `memory` stores nothing and suits tests. Release data can contain secret values, so limit who may read Secrets in the namespace. The [Helm advanced topics page](https://helm.sh/docs/topics/advanced/) describes the storage backends.

Uninstalling removes the revision Secrets along with the workload. To keep them, add `--keep-history`:

```bash
[host]$ helm uninstall shipping -n hfd-04 --keep-history
[host]$ helm list -n hfd-04 --uninstalled
```

The release then shows as `uninstalled` and `helm history` still works. On Helm 4.3.0 a plain `helm list -n hfd-04` also listed the uninstalled release in the live run, so do not rely on the default listing to hide it. Run `./demo.sh clean` to remove the release and namespace.

## Cross-check

Compare the rendered manifest with what Helm stored and with what the cluster serves. All three should agree on the objects and their names.

```bash
[host]$ helm get manifest shipping -n hfd-04
[host]$ kubectl -n hfd-04 get deploy,svc,cm -l app.kubernetes.io/instance=shipping
```

`helm get manifest` prints the YAML recorded in the latest revision. The `kubectl get` output lists the same three names. A resource that appears in one and not the other points to a template that rendered to an empty document or an object created outside Helm.

## What you learned

- A chart is a directory: `Chart.yaml`, `values.yaml`, `templates/` and `.helmignore`. `helm create` generates a larger scaffold; a hand-built chart starts from your own manifests.
- `version` identifies the chart, `appVersion` the application, and the image tag defaults to `appVersion`.
- A release is a named install; each install, upgrade and rollback writes a revision Secret, and a rollback creates a new revision.

Chapter 05 gives the chart a designed values interface, a schema and per-environment overrides.

## Further reading

- Matt Butcher, Matt Farina, Josh Dolitsky, *Learning Helm* (O'Reilly, 2021), ISBN 9781492083641. Used here for: chart anatomy, the `Chart.yaml` fields and the `templates/` directory.
- Helm project, "Charts" and "Advanced Helm Techniques" (release storage backends), https://helm.sh/docs/topics/charts/ and https://helm.sh/docs/topics/advanced/.
- Helm project, `helm install` reference (`--wait` strategies), https://helm.sh/docs/helm/helm_install/.

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/04-first-chart.txt`. Observed on Helm 4.3.0: `helm history` showed revisions 1, 2 and 3 (3 = `Rollback to 1`), one `sh.helm.release.v1.shipping.vN` Secret per revision, `--keep-history` left an `uninstalled` release, the Deployment fields were owned by manager `helm` (apply), and the history cap held at 10. Re-run on r1.1 with published NodePorts on 2026-10-08 (helm4dev recreated with `HFD_NODE_PORTS`, host requests at `http://127.0.0.1:30080`, no tunnel); the behaviour above held.*
