---
title: "S7d results (chapter 27, OpenShift Local)"
render_with_liquid: false
---
# S7d results, 2026-10-08, Helm 4.3.0, CRC 2.64.0 (OpenShift 4.22.14), oc 4.22.17, podman 5.8.7

Setup: CRC (20480 MiB, 6 CPUs) with the kubeadmin context `crc-admin`. Project `hfd-ocp`. CloudNativePG 1.30.1 (certified-operators, channel `stable-v1`) and Strimzi 1.2.0 (community-operators, channel `strimzi-1.2.x`) installed through OperatorHub Subscriptions in `openshift-operators`. Release `platform` left installed (full profile). Passwords and tokens are not recorded anywhere. Evidence: `_plans/evidence/27-openshift-crc.txt`.

| Claim | Chapter | Result | Evidence | Note |
|---|---|---|---|---|
| Whole of ch27 and its example is untested on a live OpenShift cluster | 27 | verified | 27-openshift-crc.txt | `PROFILE=full ./verify-crc.sh` and the default minimal run print PASS on every check. Not run: console Helm view, Streams for Apache Kafka |
| `restricted-v2` annotates every app pod and assigns a UID that is not 1001 | 27 | verified | 27-openshift-crc.txt | All 5 pods in the full profile (incl. Kafka, entity operator, Postgres) have `restricted-v2`. Project range `1000650000/10000`; `id` gives `uid=1000650000 gid=0(root) groups=0,1000650000` in both services. Read-only root FS: `touch /x` fails, `/tmp` works, app serves. Live pod spec shows SCC-injected `runAsUser`, `fsGroup`, `seLinuxOptions`; `helm get manifest` has 0 `runAsUser`. The chapter cross-check wrongly said the live pod shows no `runAsUser`; corrected |
| `helm upgrade --install` with the minimal overlay reaches Ready under `--wait --rollback-on-failure` | 27 | verified | 27-openshift-crc.txt | First minimal verify run: 1 FAIL, Route returned HTTP 503 right after install (router not yet programmed). `verify-crc.sh` now retries (`curl --retry 10 --retry-delay 2`); rerun all PASS. Minimal API: `"storage":"memory","kafkaEnabled":false`, one Route, POST and dispatch work |
| Full profile install reaches Ready | 27 | verified | 27-openshift-crc.txt | `helm upgrade --install platform ... -f values-openshift.yaml --wait --rollback-on-failure`: 57 s, shipping restarts 3 times during Kafka start (as on minikube) |
| Registry `defaultRoute` patch publishes `default-route-openshift-image-registry.apps-crc.testing`; `podman login` and push create ImageStreams | 27 | verified | 27-openshift-crc.txt | `build-and-push.sh` worked unmodified on first run; both streams tagged 0.1.0; pods pull via `image-registry.openshift-image-registry.svc:5000/hfd-ocp/...` |
| Route host generated; `/api/info` 200 with `"environment":"openshift"`; HTTP redirects to HTTPS | 27 | verified | 27-openshift-crc.txt | Host `platform-shipping-hfd-ocp.apps-crc.testing` resolves (CRC /etc/hosts entry), 200, `http://` gives 302 to `https://`. Route spec: edge, Redirect, targetPort http |
| Bearer-token POST and dispatch work through the Route; notification received via Kafka | 27 | verified | 27-openshift-crc.txt | No token gives 401; token `openshift-token` (from `values-openshift.yaml`) gives 201 and DISPATCHED; `platform-notification` Route `/api/notifications` shows the `shipment.dispatched` event. The notification service has no `/api/info` (404), so the chapter does not claim one |
| `helm test` passes with `tests.image` set to the registry path | 27 | verified | 27-openshift-crc.txt | Full: 3 suites Succeeded. Minimal: 1 suite |
| Route renders only where the cluster serves `route.openshift.io/v1` (negative control) | 27 | verified | 27-openshift-crc.txt | `helm template` without the flag: 0 Routes even logged in to CRC; with `--api-versions`: 2; `helm upgrade --dry-run=server` and `helm template --validate` (no flag): 2. `oc api-versions` lists `route.openshift.io/v1` |
| Full profile: CNPG and Strimzi/Streams from OperatorHub; Streams may require `kafka.strimzi.io/v1beta2` | 27 | partial | 27-openshift-crc.txt | CNPG and Strimzi installed in under 90 s. The Kafka CRD serves `v1` only (Strimzi 1.2.0); rendering with `v1beta2` fails with `no matches for kind "Kafka" in version "kafka.strimzi.io/v1beta2"`. Strimzi `stable` channel is 0.51.0, `strimzi-1.2.x` is 1.2.0. `amq-streams` package (`stable` = 3.2.1-14) not installed, so what it serves is untested |
| `helm uninstall --wait` of the full profile completes | 27 | refuted-and-fixed | 27-openshift-crc.txt | Times out: `resource KafkaTopic/hfd-ocp/shipment.dispatched still exists. status: Terminating` (finalizer `strimzi.io/topic-operator`, entity operator already gone). A reinstall straight afterwards ran its full 10 minutes and rolled back (cause inferred, not confirmed). `oc delete kafkatopic --all --wait` before the uninstall works. `demo.sh clean`, chapter and README updated |
| `ProjectHelmChartRepository` lists a classic repo in the Developer console | 27 | partial | 27-openshift-crc.txt | CRD present; CR accepted and listed by `oc get`. The console view was not opened and `https://patterncatalyst.github.io/helm-for-developers/index.yaml` returns 404 (not published), so the listing could not work yet |
| `oc set image-lookup shipping-service` enables short image references | 27 | verified | 27-openshift-crc.txt | `lookupPolicy: {"local":true}`; a pod created with `--image=shipping-service:0.1.0` ran with `...shipping-service@sha256:...` |

## Golden chart bug (s6-8)

Already fixed in golden `charts/` before this run: `route.yaml` and `test-connection.yaml` gate the notification pieces on `tags.messaging`, and `route_test.yaml` has a messaging-off case. The ex27 chart copy is identical to golden for those templates. The minimal profile confirmed it on CRC (one Route, one test suite). The "Local deviation" section of the ex27 README was stale and was replaced. No golden change was needed; `examples/26-observability/charts` still matches golden.

## Fixes

- `examples/27-openshift-crc/verify-crc.sh`: Route curl retries transient 503s; UID check covers every app pod; banner updated.
- `examples/27-openshift-crc/demo.sh`: `clean` deletes KafkaTopics before `helm uninstall`; final curl retries; banner updated.
- `examples/27-openshift-crc/values-openshift.yaml`, `README.md`, `CHECKLIST.md`: banners, Kafka apiVersion guidance, channel names, cpus 6.
- `_docs/27-appendix-openshift-local.md`: banner, footer, real output quoted, operator channels, KafkaTopic uninstall note, corrected cross-check.
- `presentation/helm-201/deck.js`: "untested" notes replaced (42 slides).
