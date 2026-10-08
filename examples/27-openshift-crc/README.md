# Example 27: OpenShift Local

> **Untested on the authoring machine; run on the CRC host.** Everything except `./demo.sh offline` needs an OpenShift Local (CRC) cluster, which the authoring machine does not have.

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

## Local deviation from the golden chart

`charts/shipping-platform/templates/route.yaml` and `templates/tests/test-connection.yaml` are gated on `tags.messaging` in this snapshot. The golden umbrella renders a notification Route and probes the notification service even when `tags.messaging=false`, which breaks the minimal profile. See `_plans/claims/s6-8.md`.

## Verification status

Unverified. Not run on a CRC cluster. A real run must confirm every check in `verify-crc.sh` prints PASS, and that the pod UID differs from 1001.
