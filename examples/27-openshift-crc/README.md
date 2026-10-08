# Example 27: OpenShift Local

> **Verified on OpenShift Local 2.64.0 (OpenShift 4.22.14) on 2026-10-08**, full and minimal profiles, with community Strimzi 1.2.0 and with Streams for Apache Kafka 3.2.1. Everything except `./demo.sh offline` needs an OpenShift Local (CRC) cluster.

The final umbrella chart (`shipping-platform` 1.0.0 and its subcharts) deployed to OpenShift Local. The chart is unchanged from the minikube chapters except for the values file: `values-openshift.yaml` swaps NodePorts for ClusterIP plus Routes, points images at the internal registry, and sets no `runAsUser` anywhere, so the `restricted-v2` SCC can assign the UID.

## Contents

| File | Purpose |
|---|---|
| `charts/` | Self-contained copies of the six reference charts (the Chapter 16 umbrella and its dependencies) |
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

`verify-crc.sh` runs the minimal profile by default. After installing the CloudNativePG and Strimzi (or Streams for Apache Kafka) operators from OperatorHub, run `PROFILE=full ./verify-crc.sh`; it then also posts and dispatches a shipment and waits for the notification through Kafka. `CONSOLE_CHECK=1` adds a check that the `ProjectHelmChartRepository` exists and that the console pod can read the published chart index. Community Strimzi and Streams for Apache Kafka own the same CRDs, so install one of them: Strimzi channel `strimzi-1.2.x`, or `amq-streams` channel `stable` (3.2.1-14, serves `v1` and `v1beta2`).

Without a cluster:

```
[host]$ ./demo.sh offline
```

That renders both profiles with `--api-versions route.openshift.io/v1`, asserts the Routes appear (and do not appear without the flag), asserts no `runAsUser` is rendered, and runs kubeconform with the custom resource kinds (`Route`, `Cluster`, `Kafka`, `KafkaNodePool`, `KafkaTopic`) skipped.

## Chart copy

`charts/` is a snapshot of the reference charts (Chapter 16 umbrella and dependencies). The umbrella's Route and test templates are gated on `tags.messaging`, so the minimal profile renders one Route and probes only the shipping service.

## Cleaning up

`./demo.sh clean` deletes the `KafkaTopic` before `helm uninstall`. Without that, the uninstall of the full profile times out on a topic that keeps its `strimzi.io/topic-operator` finalizer after the entity operator pod is gone.

## Verification status

Verified on OpenShift Local 2.64.0 (OpenShift 4.22.14), Helm 4.3.0, 2026-10-08: `PROFILE=full ./verify-crc.sh` and the default minimal run print PASS on every check (evidence `_plans/evidence/27-openshift-crc.txt`). Operators came from OperatorHub: CloudNativePG 1.30.1 (certified-operators, `stable-v1`) and either Strimzi 1.2.0 (community-operators, `strimzi-1.2.x`) or Streams for Apache Kafka 3.2.1-14 (redhat-operators, `stable`); the Streams run, including the `kafka.strimzi.io/v1beta2` setting, is in `_plans/evidence/27-openshift-crc-streams.txt`. Console Helm view: the repository resource is accepted, the console pod reads the published index and `helm search` lists the six charts (`_plans/evidence/27-openshift-crc-console.txt`); the console's own catalog listing needs a browser login and was not opened.
