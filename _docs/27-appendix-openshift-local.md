---
title: "Appendix: OpenShift Local"
order: 27
part: "Appendices"
description: "Deploy the umbrella chart to OpenShift Local (CRC): the restricted-v2 SCC and arbitrary UIDs, Routes instead of NodePorts, the internal registry, and operators from OperatorHub."
duration: 45 minutes
---

> **Verified on OpenShift Local 2.64.0 (OpenShift 4.22.14) on 2026-10-08**, both the full and the minimal profile. Not run: the Developer console Helm view (the Custom Resource is accepted, the console listing was not opened) and Red Hat's Streams for Apache Kafka operator. Output below is from that run, with the kubeadmin password and tokens left out.

Chapter 16's umbrella chart already carries two OpenShift decisions: no `runAsUser` in any security context, and a Route template that renders only where the cluster serves `route.openshift.io/v1`. This appendix uses both. The chart does not change. A different values file, a different registry and an operator install path do the work.

The code is in `examples/27-openshift-crc/`. Its `verify-crc.sh` checks the whole path and `CHECKLIST.md` lists the same steps by hand. Commands below run on the CRC machine, shown as `[crc-host]$`.

{% include excalidraw.html
   file="27-openshift-deploy"
   alt="Diagram of the OpenShift Local deployment: podman pushes images to the internal registry, helm installs release platform, pods run under restricted-v2 with an assigned UID, and a Route with edge TLS reaches the Service"
   caption="Figure 27.1 — Images, release and traffic path on OpenShift Local" %}

## Prerequisites

OpenShift Local runs a single-node OpenShift cluster in a local VM. It needs a free Red Hat account and a pull secret, both covered on the [OpenShift Local product page](https://developers.redhat.com/products/openshift-local/overview) and in the [CRC documentation](https://crc.dev/docs/introducing/).

1. Create a Red Hat account, then download the `crc` archive and the pull secret from console.redhat.com/openshift/create/local. Save the secret as `~/Downloads/pull-secret.txt`.
2. Size the VM. The defaults suit the minimal profile. The full profile (Postgres, Kafka, both services) wants more: `[crc-host]$ crc config set memory 20480` and `[crc-host]$ crc config set cpus 6`. Memory is in MiB. The full profile ran in that size, with CloudNativePG, Strimzi, Postgres, Kafka and both services using about 9 GB of the VM's 21.
3. Run `[crc-host]$ crc setup` once, then `[crc-host]$ crc start --pull-secret-file ~/Downloads/pull-secret.txt`. The first start takes 10 to 15 minutes.
4. Put the bundled `oc` on the path and log in: `[crc-host]$ eval $(crc oc-env)`, then `[crc-host]$ oc login -u kubeadmin https://api.crc.testing:6443`. The password is printed at the end of `crc start`.
5. Helm must be 4.x. Source `scripts/env.sh` from the repository root.

## The security context

OpenShift admits every pod through a Security Context Constraint. The default for ordinary workloads, `restricted-v2`, assigns each pod a UID from a range reserved for the project, sets the group to 0, and rejects a pod that asks for a specific UID. A manifest with `runAsUser: 1001` fails admission. This is the one place where a chart written for minikube can break on OpenShift without any template error.

The reference charts avoid it by construction. `pc-lib` renders `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, dropped capabilities and a `RuntimeDefault` seccomp profile, and never emits `runAsUser` or `fsGroup`. The image's `USER 1001:0` is only a default. On OpenShift the assigned UID replaces it, and the container still works because the image makes its files group-0 readable. The Containerfile from the services directory was built for this. A UID near `1000650000` inside the pod, not 1001, is the observable proof. On the verified run the project's range was `1000650000/10000` and both services reported the same UID, with group 0:

```
[crc-host]$ oc exec -n hfd-ocp deploy/platform-shipping -- id
uid=1000650000(1000650000) gid=0(root) groups=0(root),1000650000
```

The container's `securityContext` keeps `readOnlyRootFilesystem: true`, so the application writes only to `/tmp`:

```
[crc-host]$ oc get pod -n hfd-ocp -l app.kubernetes.io/name=shipping -o jsonpath='{.items[0].spec.containers[0].securityContext.readOnlyRootFilesystem}'
true
```

## Route versus Ingress

A Route is OpenShift's own entry point, served by the cluster router. The umbrella gates it on the API:

{% raw %}
```yaml
{{- if and .Values.route.enabled (.Capabilities.APIVersions.Has "route.openshift.io/v1") }}
{{- range $alias := list "shipping" "notification" }}
{{- $svc := include "shipping-platform.svcName" (dict "root" $ "alias" $alias) }}
---
apiVersion: route.openshift.io/v1
kind: Route
```
{% endraw %}

`.Capabilities.APIVersions.Has` asks the cluster at install time which APIs it serves. On minikube the Route API does not exist, so the template renders nothing and `route.enabled: true` is harmless. On CRC it renders one Route per service, with `to.name` set by the same `svcName` helper the test pod uses and `targetPort: http` matching the named Service port. `tls.termination: edge` ends TLS at the router, and `insecureEdgeTerminationPolicy: Redirect` sends plain HTTP to HTTPS, so no certificate is configured in the chart. Leaving `route.hosts.shipping` empty lets the router generate `platform-shipping-hfd-ocp.apps-crc.testing`.

An Ingress also works on OpenShift, because the router honors it by creating a Route behind the scenes. The Route is the native object and exposes options such as edge termination directly. The chart uses it for that reason.

Offline, `helm template` has no cluster to ask, so pass the API yourself. On a fresh clone, run `helm dependency build` on `charts/shipping-service` and `charts/notification-service` and then on `charts/shipping-platform` first; the demo does this in its `deps` step.

```
[host]$ helm template platform charts/shipping-platform -n hfd-ocp --api-versions route.openshift.io/v1 -f values-openshift.yaml
```

Without `--api-versions` the same command prints no Route. The example's `demo.sh offline` asserts both outcomes. On the live cluster the counts were:

```
[crc-host]$ helm template platform charts/shipping-platform -n hfd-ocp -f values-openshift.yaml | grep -c '^kind: Route$'
0
[crc-host]$ helm template platform charts/shipping-platform -n hfd-ocp --api-versions route.openshift.io/v1 -f values-openshift.yaml | grep -c '^kind: Route$'
2
[crc-host]$ helm upgrade platform charts/shipping-platform -n hfd-ocp -f values-openshift.yaml --dry-run=server | grep -c '^kind: Route$'
2
```

Offline rendering never asks the cluster, so it reports 0 even when you are logged in to CRC. A server dry run asks, and the cluster answers `route.openshift.io/v1`. Running `helm template` with `--dry-run=server` also asks the cluster.

## How the code works

`values-openshift.yaml` is the entire difference from the minikube values:

{% raw %}
```yaml
global:
  environment: openshift
  imageRegistry: image-registry.openshift-image-registry.svc:5000/hfd-ocp
shipping:
  service:
    type: ClusterIP
tests:
  image: image-registry.openshift-image-registry.svc:5000/hfd-ocp/shipping-service:0.1.0
```
{% endraw %}

`global.imageRegistry` is read by `pc-lib.image`, which builds `registry/repository:tag` with the tag defaulting to `appVersion`. The value is the in-cluster Service name of the internal registry plus the project, so every pod pulls `.../hfd-ocp/shipping-service:0.1.0`. Pods in the project pull from the project's own image streams without a pull secret. `ClusterIP` replaces the NodePort values because the Route is the way in. `tests.image` is set separately because the umbrella's test pod reads that key directly and does not go through `pc-lib.image`. Miss it and `helm test` fails on an unresolvable short image name. The project name appears in two values, and both must match the `oc new-project` argument.

`values-openshift-minimal.yaml` is an overlay for a cluster with no operators: `db.enabled: false`, `tags.messaging: false`, `shipping.config.storage: memory` and `shipping.kafka.enabled: false`, the same four switches as the chart's CI values. The umbrella's Route and test templates skip the notification Route and its probe when `tags.messaging` is false, so this profile renders one Route and `helm test` probes only the shipping service. The chart's unit tests cover that case.

`build-and-push.sh` has four steps. It creates the project if missing. It patches the registry operator's `configs.imageregistry.operator.openshift.io/cluster` with `defaultRoute: true`, which publishes the registry at `default-route-openshift-image-registry.apps-crc.testing`. It runs `podman login --tls-verify=false -u "$(oc whoami)" -p "$(oc whoami -t)"`, using the session token as the password, so no registry credential is stored in the repository. Then it builds each image from `services/Containerfile` and pushes it as `$REG/hfd-ocp/<name>:0.1.0`. The first push creates an ImageStream of that name in the project. `--tls-verify=false` is needed because the route's certificate comes from the cluster's own CA.

`verify-crc.sh` sources `scripts/env.sh` when it exists, so Helm 4 comes from the project toolchain. It prints PASS or FAIL per check and counts failures, then exits non-zero at the end instead of stopping at the first one, so one run shows everything that is wrong. The install check is `helm upgrade --install platform ... --wait --rollback-on-failure`. The pod checks read the `openshift.io/scc` annotation and compare `id -u` with the image's 1001.

## Operators on OpenShift

CloudNativePG and Strimzi are operators, and the full profile needs both. On minikube the bootstrap script applied manifests. On OpenShift the supported path is OperatorHub: in the console, Operators, OperatorHub, search for CloudNativePG and for Strimzi, and install each for all namespaces. The same install works from the command line with one Subscription each. On the verified run the catalog (CRC ships the Red Hat, Certified and Community sources) offered these:

```
[crc-host]$ oc get subscription -n openshift-operators -o custom-columns=NAME:.metadata.name,CHANNEL:.spec.channel,SOURCE:.spec.source
NAME                     CHANNEL         SOURCE
cloudnative-pg           stable-v1       certified-operators
strimzi-kafka-operator   strimzi-1.2.x   community-operators
[crc-host]$ oc get csv -n openshift-operators
NAME                              DISPLAY         VERSION   RELEASE   REPLACES                          PHASE
cloudnative-pg.v1.30.1            CloudNativePG   1.30.1              cloudnative-pg.v1.30.0            Succeeded
strimzi-cluster-operator.v1.2.0   Strimzi         1.2.0               strimzi-cluster-operator.v1.1.0   Succeeded
```

Both reached `Succeeded` in under 90 seconds. Choose the Strimzi channel explicitly: the community package's default channel, `stable`, resolved to Strimzi 0.51.0, while `strimzi-1.2.x` carries the 1.2.0 release this book pins. Red Hat's build of Strimzi is Streams for Apache Kafka (formerly AMQ Streams, package `amq-streams`, channel `stable` at 3.2.1 in the same catalog). It needs the pull secret's entitlement, and it was not installed in this run. After installing, `[crc-host]$ oc get crd clusters.postgresql.cnpg.io kafkas.kafka.strimzi.io` should list both.

Check the Kafka API version the operator serves. The chart defaults to `kafka.strimzi.io/v1`, and Strimzi 1.2.0 serves only that version:

```
[crc-host]$ oc get crd kafkas.kafka.strimzi.io -o jsonpath='{range .spec.versions[*]}{.name} served={.served} storage={.storage}{"\n"}{end}'
v1 served=true storage=true
```

Rendering the Kafka resources with `--set kafka.strimzi.apiVersion=kafka.strimzi.io/v1beta2` against this operator fails at the API server with `no matches for kind "Kafka" in version "kafka.strimzi.io/v1beta2"`. If your operator is older than 0.49, uncomment the `kafka.strimzi.apiVersion: kafka.strimzi.io/v1beta2` lines in `values-openshift.yaml`; that direction was not run here. Without operators, layer the minimal overlay instead:

```
[crc-host]$ helm upgrade --install platform charts/shipping-platform -n hfd-ocp -f values-openshift.yaml -f values-openshift-minimal.yaml --wait --rollback-on-failure
```

Helm 4's `--rollback-on-failure` implies `--wait`, and `--wait` uses the kstatus watcher. See the [Helm 4 overview](https://helm.sh/docs/overview/) for both. The full profile installed in 57 seconds, Postgres and Kafka included. The shipping pod restarts about three times while Kafka comes up, the same startup race as on minikube, and the startup probe absorbs it:

```
[crc-host]$ oc get pods -n hfd-ocp
NAME                                              READY   STATUS    RESTARTS      AGE
platform-notification-6f795cb545-lkvwc            1/1     Running   0             90s
platform-shipping-6665cbb97c-97jjj                1/1     Running   3 (69s ago)   90s
shipping-kafka-dual-0                             1/1     Running   0             88s
shipping-kafka-entity-operator-69c84b689f-jvwkk   2/2     Running   0             58s
shipping-postgres-1                               1/1     Running   0             68s
```

Every pod, the operator-managed ones included, carries `openshift.io/scc: restricted-v2`.

Uninstalling the full profile needs one extra step. `helm uninstall --wait` removes the Kafka cluster and the Topic Operator in the entity-operator pod at the same time, and the `KafkaTopic` then keeps its `strimzi.io/topic-operator` finalizer with nobody left to clear it. The uninstall times out with `resource KafkaTopic/hfd-ocp/shipment.dispatched still exists. status: Terminating`, and a reinstall into the same project straight afterwards ran its full 10 minutes and rolled back, most likely stuck on that half-deleted topic. After the topic was cleared the same install finished in under two minutes. Delete the topic first, while the operator runs, which is what `./demo.sh clean` does:

```
[crc-host]$ oc delete kafkatopic --all -n hfd-ocp --wait --timeout=120s
[crc-host]$ helm uninstall platform -n hfd-ocp --wait
release "platform" uninstalled
```

If a topic is already stuck, `[crc-host]$ oc patch kafkatopic shipment.dispatched -n hfd-ocp --type=merge -p '{"metadata":{"finalizers":null}}'` clears it.

## The Developer console and chart repositories

OpenShift's Developer perspective has a Helm view that installs charts from repositories registered as custom resources. `HelmChartRepository` is cluster-scoped and `ProjectHelmChartRepository` is namespaced:

```yaml
apiVersion: helm.openshift.io/v1beta1
kind: ProjectHelmChartRepository
metadata:
  name: hfd-charts
  namespace: hfd-ocp
spec:
  connectionConfig:
    url: https://<your-chart-repo-host>/charts
```

Replace the placeholder URL with a classic repository that serves an `index.yaml`, the kind Chapter 19 builds. The console reads that index to list charts. The cluster accepted the resource (`oc apply` printed `projecthelmchartrepository.helm.openshift.io/hfd-charts created`, and `oc get projecthelmchartrepositories -n hfd-ocp` listed it), but the URL tried returned 404 for `index.yaml` because no chart repository was published there, so the Developer console listing was not opened. Whether the console can install from an OCI registry depends on your OpenShift release, so check the release documentation before relying on it.

Optionally, `[crc-host]$ oc set image-lookup shipping-service -n hfd-ocp` turns on local lookup for the ImageStream, so a short reference such as `shipping-service:0.1.0` resolves through the stream. A pod created with that short image reference ran with the image rewritten to `image-registry.openshift-image-registry.svc:5000/hfd-ocp/shipping-service@sha256:...`. The chart does not need it, because the values file uses the full registry path.

## Build, run, observe

```
[crc-host]$ cd examples/27-openshift-crc && PROFILE=full ./verify-crc.sh
PASS  helm is 4.x (v4.3.0+gbec5b06)
PASS  crc status: OpenShift Running
PASS  oc whoami (kubeadmin)
PASS  oc new-project hfd-ocp (idempotent)
PASS  image push to the internal registry
PASS  ImageStream shipping-service has tag 0.1.0
PASS  ImageStream notification-service has tag 0.1.0
PASS  helm upgrade --install platform (full profile) --wait --rollback-on-failure
PASS  pod/platform-notification-6f795cb545-946bk Ready, openshift.io/scc=restricted-v2
PASS  pod/platform-shipping-6665cbb97c-vgfzn Ready, openshift.io/scc=restricted-v2
PASS  uid inside pod/platform-notification-6f795cb545-946bk is 1000650000 (not 1001, not 0)
PASS  uid inside pod/platform-shipping-6665cbb97c-vgfzn is 1000650000 (not 1001, not 0)
PASS  Route platform-shipping host: platform-shipping-hfd-ocp.apps-crc.testing
PASS  Route host resolves
PASS  curl -k https://platform-shipping-hfd-ocp.apps-crc.testing/api/info -> 200 ({"service":"platform-shipping","version":"0.1.0","environment":"openshift","defaultCarrier":"ACME-Post","storage":"postgres","kafkaEnabled":true})
PASS  plain HTTP redirects to HTTPS (HTTP 302)
PASS  helm test platform

verify-crc: all checks passed
```

Without the operators, drop `PROFILE=full` and the script installs the minimal profile. That run also passed, with `"storage":"memory","kafkaEnabled":false`, one Route and one pod. The first minimal run failed once, with HTTP 503 from the Route, because the router had not programmed it yet when the check ran; the script now retries the request for up to 20 seconds.

The Route reaches the services from the host. The shipping API needs the bearer token that `values-openshift.yaml` sets, `openshift-token`, for writes. Dispatching a shipment publishes an event that the notification service consumes from Kafka:

```
[crc-host]$ curl -sk -X POST https://platform-shipping-hfd-ocp.apps-crc.testing/api/shipments -H 'content-type: application/json' -d '{"orderId":27001,"address":"27 Route Rd, Springfield"}'
{"detail":"missing or invalid bearer token"}
[crc-host]$ curl -sk -X POST https://platform-shipping-hfd-ocp.apps-crc.testing/api/shipments -H 'Authorization: Bearer openshift-token' -H 'content-type: application/json' -d '{"orderId":27002,"address":"27 Route Rd, Springfield"}'
{"id":1,"orderId":27002,"address":"27 Route Rd, Springfield","status":"PENDING","createdAt":"2026-10-08T17:27:33.204235Z"}
[crc-host]$ curl -sk -X POST https://platform-shipping-hfd-ocp.apps-crc.testing/api/shipments/1/dispatch -H 'Authorization: Bearer openshift-token'
{"id":1,"orderId":27002,"address":"27 Route Rd, Springfield","status":"DISPATCHED","createdAt":"2026-10-08T17:27:33.204235Z"}
[crc-host]$ curl -sk https://platform-notification-hfd-ocp.apps-crc.testing/api/notifications
[{"receivedAt":"2026-10-08T17:27:33.254969+00:00","topic":"shipment.dispatched","partition":0,"offset":0,"event":{"orderId":27002,"shipmentId":1,"address":"27 Route Rd, Springfield","status":"DISPATCHED","occurredAt":"2026-10-08T17:27:33.237855+00:00"}}]
```

Plain HTTP answers `302` with `location: https://...`, which is the `Redirect` policy at work. The edge TLS certificate comes from the cluster's ingress CA, so `curl` needs `-k`.

## Cross-check

Compare Helm's view with the cluster's. `[crc-host]$ helm get manifest platform -n hfd-ocp | grep -c 'kind: Route'` and `[crc-host]$ oc get routes -n hfd-ocp --no-headers | wc -l` both print `2` in the full profile. `[crc-host]$ helm get manifest platform -n hfd-ocp | grep -c runAsUser` prints `0`: the chart pins no UID.

The live pod disagrees with the manifest. The SCC admission fills in the fields the chart left out:

```
[crc-host]$ oc get pod -n hfd-ocp -l app.kubernetes.io/name=shipping -o jsonpath='{.items[0].spec.securityContext}'
{"fsGroup":1000650000,"runAsNonRoot":true,"seLinuxOptions":{"level":"s0:c26,c0"},"seccompProfile":{"type":"RuntimeDefault"}}
[crc-host]$ oc get pod -n hfd-ocp -l app.kubernetes.io/name=shipping -o jsonpath='{.items[0].spec.containers[0].securityContext}'
{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true,"runAsNonRoot":true,"runAsUser":1000650000,"seccompProfile":{"type":"RuntimeDefault"}}
```

`runAsUser`, `fsGroup` and the SELinux level come from the SCC, not from Helm. A diff between `helm get manifest` and the live object shows them, and they are expected.

## What you learned

- `restricted-v2` assigns the UID and rejects a pinned one, so charts for OpenShift omit `runAsUser`.
- A Route template gated on `.Capabilities.APIVersions.Has "route.openshift.io/v1"` is inert on minikube and active on OpenShift, and offline rendering needs `--api-versions`.
- The internal registry is reached through `default-route` with a token login, and images pull from it by the in-cluster Service name.
- Operators install through OperatorHub, or the minimal overlay turns them off. Delete the `KafkaTopic` before uninstalling the full profile.

The next appendix collects the Helm 3 to Helm 4 changes in one place.

## Further reading

- [OpenShift Local product page](https://developers.redhat.com/products/openshift-local/overview) and [CRC documentation](https://crc.dev/docs/introducing/): accounts, pull secret, `crc setup` and `crc start`.
- [OpenShift Container Platform documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/latest): security context constraints, Routes, the internal registry and Helm charts on OpenShift.
- [Helm 4 overview](https://helm.sh/docs/overview/): `--rollback-on-failure` and the kstatus `--wait`.

---

*Verification status: <span class="status status--verified">verified</span> on OpenShift Local 2.64.0 (OpenShift 4.22.14), Helm 4.3.0, 2026-10-08, with both profiles (evidence: `_plans/evidence/27-openshift-crc.txt`). Not run: the Developer console Helm view (the `ProjectHelmChartRepository` was only accepted by the API) and the Streams for Apache Kafka operator, so the `v1beta2` fallback for older operators is untested.*
