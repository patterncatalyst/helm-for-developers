---
title: "Appendix: OpenShift Local"
order: 27
part: "Appendices"
description: "Deploy the umbrella chart to OpenShift Local (CRC): the restricted-v2 SCC and arbitrary UIDs, Routes instead of NodePorts, the internal registry, and operators from OperatorHub."
duration: 45 minutes
---

> **Untested on the authoring machine; run on the CRC host.** The charts render and pass kubeconform offline. Nothing in this chapter has run against a live OpenShift cluster, and the footer stays `unverified` until it has.

Chapter 16's umbrella chart already carries two OpenShift decisions: no `runAsUser` in any security context, and a Route template that renders only where the cluster serves `route.openshift.io/v1`. This appendix uses both. The chart does not change. A different values file, a different registry and an operator install path do the work.

The code is in `examples/27-openshift-crc/`. Its `verify-crc.sh` checks the whole path and `CHECKLIST.md` lists the same steps by hand. Commands below run on the CRC machine, shown as `[crc-host]$`.

{% include excalidraw.html
   file="27-openshift-deploy"
   alt="Diagram of the OpenShift Local deployment: podman pushes images to the internal registry, helm installs release platform, pods run under restricted-v2 with an assigned UID, and a Route with edge TLS reaches the Service"
   caption="Figure 27.1 — Images, release and traffic path on OpenShift Local" %}

## Prerequisites

OpenShift Local runs a single-node OpenShift cluster in a local VM. It needs a free Red Hat account and a pull secret, both covered on the [OpenShift Local product page](https://developers.redhat.com/products/openshift-local/overview) and in the [CRC documentation](https://crc.dev/docs/introducing/).

1. Create a Red Hat account, then download the `crc` archive and the pull secret from console.redhat.com/openshift/create/local. Save the secret as `~/Downloads/pull-secret.txt`.
2. Size the VM. The defaults suit the minimal profile. The full profile (Postgres, Kafka, both services) wants more: `[crc-host]$ crc config set memory 20480` and `[crc-host]$ crc config set cpus 8`. Memory is in MiB.
3. Run `[crc-host]$ crc setup` once, then `[crc-host]$ crc start --pull-secret-file ~/Downloads/pull-secret.txt`. The first start takes 10 to 15 minutes.
4. Put the bundled `oc` on the path and log in: `[crc-host]$ eval $(crc oc-env)`, then `[crc-host]$ oc login -u kubeadmin https://api.crc.testing:6443`. The password is printed at the end of `crc start`.
5. Helm must be 4.x. Source `scripts/env.sh` from the repository root.

## The security context

OpenShift admits every pod through a Security Context Constraint. The default for ordinary workloads, `restricted-v2`, assigns each pod a UID from a range reserved for the project, sets the group to 0, and rejects a pod that asks for a specific UID. A manifest with `runAsUser: 1001` fails admission. This is the one place where a chart written for minikube can break on OpenShift without any template error.

The golden charts avoid it by construction. `pc-lib` renders `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, dropped capabilities and a `RuntimeDefault` seccomp profile, and never emits `runAsUser` or `fsGroup`. The image's `USER 1001:0` is only a default. On OpenShift the assigned UID replaces it, and the container still works because the image makes its files group-0 readable. The Containerfile from the services directory was built for this. A UID near `1000650000` inside the pod, not 1001, is the observable proof.

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

Offline, `helm template` has no cluster to ask, so pass the API yourself:

```
[host]$ helm template platform charts/shipping-platform -n hfd-ocp --api-versions route.openshift.io/v1 -f values-openshift.yaml
```

Without `--api-versions` the same command prints no Route. The example's `demo.sh offline` asserts both outcomes.

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

`global.imageRegistry` is read by `pc-lib.image`, which builds `registry/repository:tag` with the tag defaulting to `appVersion`. The value is the in-cluster Service name of the internal registry plus the project, so every pod pulls `.../hfd-ocp/shipping-service:0.1.0`. Pods in the project can pull from the project's own image streams without a pull secret. `ClusterIP` replaces the NodePort values because the Route is the way in. `tests.image` is set separately because the umbrella's test pod reads that key directly and does not go through `pc-lib.image`. Miss it and `helm test` fails on an unresolvable short image name. The project name appears in two values, and both must match the `oc new-project` argument.

`values-openshift-minimal.yaml` is an overlay for a cluster with no operators: `db.enabled: false`, `tags.messaging: false`, `shipping.config.storage: memory` and `shipping.kafka.enabled: false`, the same four switches as the chart's CI values. The umbrella's own route and test templates rendered a notification Route and probed the notification service even with messaging off. The example's chart copy gates both on `tags.messaging`, and the divergence is recorded in the example README.

`build-and-push.sh` has four steps. It creates the project if missing. It patches the registry operator's `configs.imageregistry.operator.openshift.io/cluster` with `defaultRoute: true`, which publishes the registry at `default-route-openshift-image-registry.apps-crc.testing`. It runs `podman login --tls-verify=false -u "$(oc whoami)" -p "$(oc whoami -t)"`, using the session token as the password, so no registry credential is stored in the repository. Then it builds each image from `services/Containerfile` and pushes it as `$REG/hfd-ocp/<name>:0.1.0`. The first push creates an ImageStream of that name in the project. `--tls-verify=false` is needed because the route's certificate comes from the cluster's own CA.

`verify-crc.sh` sources `scripts/env.sh` when it exists, so Helm 4 comes from the project toolchain. It prints PASS or FAIL per check and counts failures, then exits non-zero at the end instead of stopping at the first one, so one run shows everything that is wrong. The install check is `helm upgrade --install platform ... --wait --rollback-on-failure`. The pod checks read the `openshift.io/scc` annotation and compare `id -u` with the image's 1001.

## Operators on OpenShift

CloudNativePG and Strimzi are operators, and the full profile needs both. On minikube the bootstrap script applied manifests. On OpenShift the supported path is OperatorHub: in the console, Operators, OperatorHub, search for CloudNativePG and for Strimzi, and install each for all namespaces. Red Hat's build of Strimzi is Streams for Apache Kafka (formerly AMQ Streams), which needs the pull secret's entitlement. After installing, `[crc-host]$ oc get crd clusters.postgresql.cnpg.io kafkas.kafka.strimzi.io` should list both.

Check the Kafka API version the operator serves. The chart defaults to `kafka.strimzi.io/v1`. If your operator is older, uncomment the `kafka.strimzi.apiVersion: kafka.strimzi.io/v1beta2` lines in `values-openshift.yaml`. Without operators, layer the minimal overlay instead:

```
[crc-host]$ helm upgrade --install platform charts/shipping-platform -n hfd-ocp -f values-openshift.yaml -f values-openshift-minimal.yaml --wait --rollback-on-failure
```

Helm 4's `--rollback-on-failure` implies `--wait`, and `--wait` uses the kstatus watcher. See the [Helm 4 overview](https://helm.sh/docs/overview/) for both.

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
    url: https://patterncatalyst.github.io/helm-for-developers
```

The URL must point at a classic repository with an `index.yaml`, the kind Chapter 19 builds. The console reads that index to list charts. Whether it can install from an OCI registry depends on your OpenShift release, so check the release documentation before relying on it.

Optionally, `[crc-host]$ oc set image-lookup shipping-service -n hfd-ocp` turns on local lookup for the ImageStream, so a short reference such as `shipping-service:0.1.0` resolves through the stream. The chart does not need it, because the values file uses the full registry path.

## Build, run, observe

```
[crc-host]$ cd examples/27-openshift-crc && ./verify-crc.sh
```

Expect a PASS line for each check: `crc status`, `oc whoami`, the project, the image push and image streams, the install, every pod Ready under `restricted-v2`, a UID that is not 1001, the Route host, `curl -k https://<route>/api/info` returning 200, the HTTP redirect, and `helm test`. Any FAIL prints the last lines of the failing command's output. Use `PROFILE=full ./verify-crc.sh` after the operators are installed.

## Cross-check

Compare Helm's view with the cluster's. `[crc-host]$ helm get manifest platform -n hfd-ocp | grep -c 'kind: Route'` should equal the Route count from `[crc-host]$ oc get routes -n hfd-ocp --no-headers | wc -l`. A pod's `[crc-host]$ oc get pod <name> -n hfd-ocp -o jsonpath='{.spec.securityContext}'` should show no `runAsUser`, while `oc exec <name> -- id -u` shows an assigned one.

## What you learned

- `restricted-v2` assigns the UID and rejects a pinned one, so charts for OpenShift omit `runAsUser`.
- A Route template gated on `.Capabilities.APIVersions.Has "route.openshift.io/v1"` is inert on minikube and active on OpenShift, and offline rendering needs `--api-versions`.
- The internal registry is reached through `default-route` with a token login, and images pull from it by the in-cluster Service name.
- Operators install through OperatorHub, or the minimal overlay turns them off.

The next appendix collects the Helm 3 to Helm 4 changes in one place.

## Further reading

- [OpenShift Local product page](https://developers.redhat.com/products/openshift-local/overview) and [CRC documentation](https://crc.dev/docs/introducing/): accounts, pull secret, `crc setup` and `crc start`.
- [OpenShift Container Platform documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/latest): security context constraints, Routes, the internal registry and Helm charts on OpenShift.
- [Helm 4 overview](https://helm.sh/docs/overview/): `--rollback-on-failure` and the kstatus `--wait`.

---

*Verification status: <span class="status status--unverified">unverified</span>. Untested on the authoring machine. A CRC run must confirm that pods carry `openshift.io/scc: restricted-v2`, the in-pod UID is not 1001, the Route returns 200 on `/api/info`, `helm test` passes, and the Kafka `apiVersion` the installed operator accepts.*
