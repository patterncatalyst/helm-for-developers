# Example 27: OpenShift Local

> **Verified on OpenShift Local 2.64.0 (OpenShift 4.22.14) on 2026-10-08**, full and minimal profiles. Everything except `./demo.sh offline` needs an OpenShift Local (CRC) cluster.

The final umbrella chart (`shipping-platform` 1.0.0 and its subcharts) deployed to OpenShift Local. The chart is unchanged from the minikube chapters except for the values file: `values-openshift.yaml` swaps NodePorts for ClusterIP plus Routes, points images at the internal registry, and sets no `runAsUser` anywhere, so the `restricted-v2` SCC can assign the UID.

## Contents

| File | Purpose |
|---|---|
| `charts/` | Self-contained copies of the six golden charts (the Chapter 16 umbrella and its dependencies) |
| `values-openshift.yaml` | Full profile: Routes, internal registry, ClusterIP, database and Kafka on |
| `values-openshift-minimal.yaml` | Overlay for a run without operators: in-memory storage, no Kafka, no notification service |
| `build-and-push.sh` | Exposes the registry `default-route`, logs podman in with `oc whoami -t`, builds and pushes both images |
| `verify-crc.sh` | PASS/FAIL checks for the whole path, exit non-zero on any FAIL |
| `CHECKLIST.md` | Manual checklist for the same path, including the operator installs |
| `demo.sh` | No argument: build, push, install, test. `offline`: lint, template, kubeconform. `clean`: uninstall and delete the project |

## Run

```
[crc-host]$ eval $(crc oc-env)
[crc-host]$ oc login -u kubeadmin https://api.crc.testing:6443
[crc-host]$ cd examples/27-openshift-crc
[crc-host]$ ./verify-crc.sh
```

`verify-crc.sh` runs the minimal profile by default. After installing the CloudNativePG and Strimzi (or Streams for Apache Kafka) operators from OperatorHub, run `PROFILE=full ./verify-crc.sh`.

Without a cluster:

```
[host]$ ./demo.sh offline
```

That renders both profiles with `--api-versions route.openshift.io/v1`, asserts the Routes appear (and do not appear without the flag), asserts no `runAsUser` is rendered, and runs kubeconform with the custom resource kinds (`Route`, `Cluster`, `Kafka`, `KafkaNodePool`, `KafkaTopic`) skipped.

## Chart copy

`charts/` is a snapshot of the golden charts (Chapter 16 umbrella and dependencies). The umbrella's Route and test templates are gated on `tags.messaging`, so the minimal profile renders one Route and probes only the shipping service.

## Cleaning up

`./demo.sh clean` deletes the `KafkaTopic` before `helm uninstall`. Without that, the uninstall of the full profile times out on a topic that keeps its `strimzi.io/topic-operator` finalizer after the entity operator pod is gone.

## Verification status

Verified on OpenShift Local 2.64.0 (OpenShift 4.22.14), Helm 4.3.0, 2026-10-08: `PROFILE=full ./verify-crc.sh` and the default minimal run print PASS on every check (evidence `_plans/evidence/27-openshift-crc.txt`). Operators came from OperatorHub: CloudNativePG 1.30.1 (certified-operators, `stable-v1`) and Strimzi 1.2.0 (community-operators, `strimzi-1.2.x`). Not run: the Developer console Helm view and Streams for Apache Kafka.
