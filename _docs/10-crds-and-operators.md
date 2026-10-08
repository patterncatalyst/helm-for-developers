---
title: "CRDs and operators"
order: 10
part: "Data and lifecycle"
description: "What the crds/ directory does and does not do, why an application chart ships custom resources and not operators, and how to fail fast when an operator is missing."
duration: 30 minutes
---

The `shipping-postgres` subchart from chapter 09 renders a `Cluster` object, and the object means nothing unless the CloudNativePG operator is installed and its CustomResourceDefinition (CRD) exists. This chapter covers the division of labor between charts and operators, the one directory where Helm installs CRDs, and a render-time guard that turns a confusing server error into a readable one.

The code is in `examples/10-crds-operators/`. `./demo.sh offline` needs no cluster, and `./demo.sh` runs the live comparison against the lab cluster.

{% include excalidraw.html
   file="10-crd-ownership"
   alt="Diagram of three layers: the application chart with crds/, templates and an operator guard; the Helm actions install, upgrade and uninstall on crds/; and the platform layer with the CRD in the API server and the operator"
   caption="Figure 10.1 — Which side owns the CRD, the custom resources and the operator" %}

## Operators belong to the platform

An operator is a controller plus its CRDs, installed once per cluster by someone with cluster-wide rights. A chart for one application should not install it: two releases would fight over one cluster-scoped object, and uninstalling your app would remove the database operator for everyone. So the split is fixed. The platform installs CloudNativePG, Strimzi and the observability stack (`scripts/platform/bootstrap.sh` does this for the lab). The application chart declares what it wants as custom resources, here a `Cluster`, and the operator reconciles them. That is the Operator pattern: your chart states desired state, a controller drives the cluster toward it.

## The `crds/` directory

A chart may ship CRDs for APIs it defines itself. Helm gives that directory three special properties, documented in the [Helm CRD best practices](https://helm.sh/docs/chart_best_practices/custom_resource_definitions/) and the [chart guide](https://helm.sh/docs/topics/charts/#custom-resource-definitions-crds):

- Files in `crds/` are plain YAML. Helm does not template them, so no `{% raw %}{{ }}{% endraw %}` and no values.
- Helm installs them on `helm install`, before the rest of the chart. If the CRD already exists, it is left alone.
- Helm does not upgrade or delete them. `helm upgrade` skips `crds/`, and `helm uninstall` leaves the CRD in place.

The reason for the last rule is blast radius. Deleting a CRD deletes every object of that kind in every namespace, and a chart upgrade has no way to know who else uses them. `helm install --skip-crds` skips the directory, `helm template --include-crds` adds it to the output (it is omitted by default), and `helm show crds <chart>` prints it. When you need to manage a CRD's lifecycle, the docs recommend a separate chart for the CRD, or applying it with `kubectl`.

## Changing a CRD after release one

Because Helm never upgrades `crds/`, a CRD change needs its own step in the delivery path. Two patterns cover most cases:

- Apply the CRD files with `kubectl apply -f` in the pipeline before `helm upgrade`. The chart's `crds/` directory stays the source of truth, and the pipeline reads it.
- Move the CRD into a second chart, installed and upgraded on its own schedule, with ordinary templates. The application chart then depends on that API being present and uses the guard from this chapter to say so.

Neither is free. The first splits one change across two tools, and the second means two releases to track. Pick based on who owns the API. An API your team defines and versions with the application suits `crds/` plus `kubectl apply`. An API someone else defines, like CloudNativePG's, never belongs in your chart at all.

## How the code works

The demo CRD is `shipping-service/crds/shippingroute.yaml`. It defines `ShippingRoute` in the group `shipping.patterncatalyst.io`, version `v1alpha1`, namespaced, with the short name `sroute`. Its `openAPIV3Schema` requires `spec.carrier`, `spec.origin` and `spec.destination`, all strings, and two `additionalPrinterColumns` make `kubectl get shippingroute` readable. `served: true` and `storage: true` mark the only version as both reachable and persisted. The file is the whole chart-side footprint; there is no template for it.

`shippingroute-v2.crd.yaml` sits outside the chart and adds one property, `spec.priority`. The demo uses it to show the upgrade rule. It copies the chart to a temporary directory, swaps in the v2 file, and runs `helm upgrade` from there. Afterwards it reads the CRD back with `kubectl get crd` and prints the keys under `spec.properties`. They still list only three. Then `kubectl apply -f shippingroute-v2.crd.yaml` changes the CRD, and a second read shows `priority`. Last, `helm uninstall` runs, and the CRD and the sample `ShippingRoute` object are both still there. `./demo.sh clean` removes them explicitly.

The operator guard is in `shipping-postgres/templates/cluster.yaml`:

{% raw %}
```yaml
{{- if and .Values.requireOperator (not (.Capabilities.APIVersions.Has "postgresql.cnpg.io/v1")) }}
{{- fail "shipping-postgres needs the CloudNativePG operator: ..." }}
{{- end }}
```
{% endraw %}

`.Capabilities.APIVersions` is the list of group/versions the API server serves, discovered when Helm connects. `Has` tests membership. `fail` aborts rendering with a message, so a missing operator produces one sentence naming the missing API instead of `no matches for kind "Cluster"` from the server after upload. The condition checks `requireOperator` first so you can opt out (render now, install the operator later) and so the `shipping-postgres` unit tests can cover all three cases. In helm-unittest, `capabilities.apiVersions` at the test level supplies the fake API list. The suite asserts the failure message without it, a `Cluster` with it, and a `Cluster` when `requireOperator` is false.

Offline rendering has no cluster, so `helm template` sees only the built-in API list. `demo.sh offline` first runs the postgres render and expects it to fail. The observed error is:

```text
Error: execution error at (shipping-service/charts/shipping-postgres/templates/cluster.yaml:2:4): shipping-postgres needs the CloudNativePG operator: the API postgresql.cnpg.io/v1 is not served by this cluster. Install the operator (scripts/platform/bootstrap.sh), set requireOperator=false to skip this check, or pass --api-versions postgresql.cnpg.io/v1 to helm template.
```

It then repeats the render with `--api-versions postgresql.cnpg.io/v1` and expects four objects. This is also the pattern for any template that depends on an optional API: gate it with `Has`, and give offline renders a way to declare the API.

The `helm lint` command runs templates in a lenient mode: with `-f values-postgres.yaml` and no declared API, lint printed the `fail` message as `level=INFO msg="funcMap fail"` and still reported `0 chart(s) failed`. Do not count on lint to enforce a guard. Use `helm template` or a unit test.

## Build, run, observe

```bash
[host]$ cd examples/10-crds-operators && ./demo.sh offline
```

The output shows `0` for the CRD count when `--include-crds` is omitted, the guard error above, then 7 unit tests passing across two charts and a kubeconform summary. kubeconform validates the CRD against the built-in `apiextensions.k8s.io/v1` schema, and skips the `Cluster`, for which no schema is in its default catalog.

```bash
[host]$ ./demo.sh
```

The live run installs in memory mode, so no operator is needed, and prints the `spec` property list at each stage. Expect `['carrier', 'destination', 'origin']` after install and after `helm upgrade`, and `priority` appended only after the `kubectl apply`.

## Cross-check

Ask the cluster who installed the CRD and what it holds, independent of Helm:

```bash
[host]$ kubectl get crd shippingroutes.shipping.patterncatalyst.io -o jsonpath='{.metadata.managedFields[*].manager}'
[host]$ helm show crds examples/10-crds-operators/shipping-service | grep -c priority
```

The second command prints `0`, matching the live CRD before the manual apply. The `managedFields` list shows which clients wrote the object, and after the `kubectl apply` step it gains a `kubectl-client-side-apply` entry.

Observed after the full run on Helm 4.3.0 (`_plans/evidence/10-crds-operators.txt`):

```text
managers: [helm, kube-apiserver, kubectl-client-side-apply]
helm                       -> Apply
kube-apiserver             -> Update
kubectl-client-side-apply  -> Update
```

`kubectl apply` on the CRD that Helm created succeeded without a field conflict. It printed one warning, `resource customresourcedefinitions/shippingroutes.shipping.patterncatalyst.io is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply`, then `configured`, and the property list gained `priority`.

## What you learned

- Operators and their CRDs are platform-owned. An application chart ships custom resources, and ships a CRD only for an API it defines.
- `crds/` is install-only: not templated, not upgraded, not deleted. `--skip-crds` and `--include-crds` control it, and `kubectl apply` is the way to change a CRD.
- `.Capabilities.APIVersions.Has` plus `fail` converts a missing operator into a clear render-time error. `helm template` needs `--api-versions` to pass offline, and lint does not enforce the guard.

Chapter 11 adds the migration Job, and with it the first conflict between Helm's ordering and the application's readiness.

## Further reading

- Bilgin Ibryam and Roland Huß, *Kubernetes Patterns, 2nd ed.* (O'Reilly, 2023), ISBN 9781098131678. Used here for: the Operator and Controller patterns and the custom resource model.
- Helm project, [Custom Resource Definitions best practices](https://helm.sh/docs/chart_best_practices/custom_resource_definitions/). Used here for: `crds/` install-only semantics and the separate-chart pattern.
- Helm project, [Charts: Custom Resource Definitions](https://helm.sh/docs/topics/charts/#custom-resource-definitions-crds). Used here for: `crds/` limitations and `--skip-crds`.

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/10-crds-operators.txt`. Observed on Helm 4.3.0: `helm upgrade` left the CRD unchanged, `kubectl apply` updated it without a conflict and added `kubectl-client-side-apply` to `managedFields`, `helm uninstall` kept the CRD and the sample object, the lint guard printed `level=INFO msg="funcMap fail"` with 0 failures, and the guard passed on a cluster with the CNPG operator.*
