# OpenShift Local checklist

> Verified on OpenShift Local 2.64.0 (OpenShift 4.22.14), 2026-10-08.

Tick each box in order. `verify-crc.sh` automates steps 5 to 10.

## 1. Host

- [ ] Red Hat account exists (free Developer account)
- [ ] Pull secret downloaded from console.redhat.com/openshift/create/local, saved as `~/Downloads/pull-secret.txt`
- [ ] `crc version` prints a version; `crc` is on `PATH`
- [ ] 12 GB or more RAM and 6 or more CPUs free for the full profile (the minimal profile fits in the defaults)

## 2. Cluster

- [ ] `[crc-host]$ crc config set memory 16384` and `crc config set cpus 6` (full profile: 20480 and 8)
- [ ] `[crc-host]$ crc setup` finished without errors
- [ ] `[crc-host]$ crc start --pull-secret-file ~/Downloads/pull-secret.txt` finished and printed the kubeadmin password
- [ ] `[crc-host]$ crc status` shows `OpenShift: Running`
- [ ] `[crc-host]$ eval $(crc oc-env)` puts `oc` on `PATH`
- [ ] `[crc-host]$ oc login -u kubeadmin https://api.crc.testing:6443` succeeds
- [ ] `[crc-host]$ helm version --short` prints `v4.*` (source `scripts/env.sh`)

## 3. Operators (full profile only)

- [ ] Console, Operators, OperatorHub: CloudNativePG installed (all namespaces)
- [ ] Console, Operators, OperatorHub: Strimzi (channel `strimzi-1.2.x`), or Streams for Apache Kafka (`amq-streams`, channel `stable`, 3.2.1-14), installed (all namespaces). Install one, not both: they own the same CRDs
- [ ] `[crc-host]$ oc get crd clusters.postgresql.cnpg.io kafkas.kafka.strimzi.io` lists both
- [ ] `oc get crd kafkas.kafka.strimzi.io -o jsonpath='{.spec.versions[*].name}'` prints `v1` (Streams 3.2.1 prints `v1 v1beta2`, either works); if it prints only `v1beta2`, set `kafka.strimzi.apiVersion` to `kafka.strimzi.io/v1beta2` in `values-openshift.yaml`

## 4. Project and images

- [ ] `[crc-host]$ oc new-project hfd-ocp` (or `oc project hfd-ocp` when it exists)
- [ ] `[crc-host]$ ./build-and-push.sh` pushed both images
- [ ] `[crc-host]$ oc get imagestream -n hfd-ocp` lists `shipping-service` and `notification-service` with tag `0.1.0`

## 5. Install

- [ ] `[crc-host]$ helm upgrade --install platform charts/shipping-platform -n hfd-ocp -f values-openshift.yaml -f values-openshift-minimal.yaml --wait --rollback-on-failure` exits 0 (drop the second `-f` for the full profile)
- [ ] `[crc-host]$ helm list -n hfd-ocp` shows `platform` as `deployed`

## 6. Security context

- [ ] Every application pod is Ready
- [ ] `[crc-host]$ oc get pod -n hfd-ocp -o custom-columns=NAME:.metadata.name,SCC:.metadata.annotations.openshift\.io/scc` shows `restricted-v2`
- [ ] `[crc-host]$ oc exec -n hfd-ocp deploy/platform-shipping -- id -u` prints a UID in the project range (for example 1000650000), not 1001

## 7. Route

- [ ] `[crc-host]$ oc get route -n hfd-ocp` lists `platform-shipping` (and `platform-notification` in the full profile)
- [ ] `[crc-host]$ curl -sk https://$(oc get route platform-shipping -n hfd-ocp -o jsonpath='{.spec.host}')/api/info` returns JSON with `"environment":"openshift"`
- [ ] Plain HTTP to the same host answers with a redirect

## 8. Tests and cleanup

- [ ] `[crc-host]$ helm test platform -n hfd-ocp` passes
- [ ] `[crc-host]$ ./verify-crc.sh` prints PASS on every line and exits 0
- [ ] Optional, console Helm view: `oc apply` the `ProjectHelmChartRepository` from chapter 27 (URL `https://patterncatalyst.github.io/helm-for-developers/charts`), then open Developer perspective, Helm, Create, Helm Release and look for the `hfd-charts` repository filter; `CONSOLE_CHECK=1 ./verify-crc.sh` covers the reachable parts
- [ ] `[crc-host]$ ./demo.sh clean` removes the release and the project (it deletes the KafkaTopic first)
