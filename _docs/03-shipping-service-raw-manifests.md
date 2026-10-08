---
title: "The shipping service as raw manifests"
order: 3
part: "From manifests to a chart"
description: "Deploy the shipping service with three plain Kubernetes manifests, then copy them for a second and third environment to see the problem a chart solves."
duration: 30 minutes
---

Every chart in this book packages the same application, so the first step is to deploy it without Helm. This chapter writes a ConfigMap, a Deployment and a Service for the shipping service with in-memory storage, applies them with `kubectl`, and then counts what it costs to run that set in three environments. The result is the concrete list of things a chart has to parameterize.

The code is in `examples/03-raw-manifests/`. `./demo.sh offline` validates the manifests with kubeconform and needs no cluster; `./demo.sh` builds the image and applies them to `hfd-03`.

{% include excalidraw.html
   file="03-raw-manifest-sprawl"
   alt="Diagram: one manifests directory with three files is copied and edited for dev, stage and prod, producing nine files that must stay in step"
   caption="Figure 3.1 — Three environments from raw manifests means nine files to keep in step" %}

## The application contract

The shipping service is a FastAPI application that reads all configuration from environment variables. With `SHIPPING_STORAGE=memory` it needs no database, which keeps this chapter about Kubernetes objects. The variables used here are `SERVICE_NAME`, `SERVICE_VERSION`, `DEPLOY_ENV`, `LOG_LEVEL`, `SHIPPING_DEFAULT_CARRIER` and `SHIPPING_STORAGE`. The container listens on port 8080 and serves `/health` (process is alive) and `/healthz` (ready for traffic). The image is `shipping-service:0.1.0`, built once by `scripts/build-images.sh`; no later chapter changes it.

## How the code works

Three files carry the whole deployment.

**`manifests/configmap.yaml`** holds the non-secret settings as string data. A ConfigMap keeps configuration out of the image, so changing the carrier or log level never needs a rebuild. Every value is a quoted string because environment variables are strings, and an unquoted `memory` or `INFO` would be fine but an unquoted `1.0` or `true` would be parsed by YAML as a number or boolean and rejected by the API server.

**`manifests/deployment.yaml`** is the largest object, and each block in it answers a question the cluster would otherwise guess at.

- `selector.matchLabels` and the pod template labels must agree on `app.kubernetes.io/name: shipping-service`. The selector of a Deployment is immutable after creation, so this label pair is fixed for the life of the object.
- `envFrom.configMapRef` injects every key of `shipping-config` as an environment variable. It is the shortest way to expose a ConfigMap whose keys are already valid variable names.
- The three probes use the two endpoints. The `startupProbe` allows 30 attempts two seconds apart, a 60 second budget for a slow Python import. It gates the other two probes, so the liveness probe cannot kill a pod that is still starting. The `livenessProbe` calls `/health` and restarts a wedged process. The `readinessProbe` calls `/healthz` and removes the pod from Service endpoints while it cannot serve.
- `resources.requests` (100m CPU, 192Mi) is what the scheduler reserves; `limits.memory` (512Mi) is the point where the kernel kills the container. There is no CPU limit, so the pod is not throttled below what the node can give.
- The `securityContext` runs the container as a non-root user without choosing a UID: `runAsNonRoot: true`, no `runAsUser`, privilege escalation off, all capabilities dropped, the `RuntimeDefault` seccomp profile. Leaving the UID unset lets platforms that assign their own range, such as OpenShift, admit the pod unchanged (chapter 27).
- `readOnlyRootFilesystem: true` blocks writes to the image layers, so the `tmp` `emptyDir` mounted at `/tmp` gives the interpreter its only writable path.

**`manifests/service.yaml`** selects the pods by the same label and maps Service port 8080 to the container port named `http`. It is a `NodePort` fixed at 30080, which the lab's `scripts/tunnel.sh` forwards to 127.0.0.1:8080. A fixed `nodePort` is a hardcoded value that the chart will turn into a default (chapter 05).

The manifests are complete. They carry the same probes, resource requests and security settings as the finished chart, so the later chapters change how the YAML is produced, not what it says.

## Build, run, observe

```bash
cd examples/03-raw-manifests && ./demo.sh
```

The script runs these steps; they are also safe to type one at a time.

```bash
[host]$ source scripts/env.sh
[host]$ scripts/build-images.sh shipping-service
[host]$ kubectl create namespace hfd-03
[host]$ kubectl -n hfd-03 apply -f examples/03-raw-manifests/manifests/
[host]$ kubectl -n hfd-03 rollout status deployment/shipping-service
[host]$ scripts/tunnel.sh start shipping
[host]$ curl -s http://127.0.0.1:8080/api/info
```

A working deployment answers with `"storage":"memory"` and the settings from the ConfigMap. Without a cluster, the offline check is kubeconform, which validates each document against the Kubernetes JSON schemas:

```bash
[host]$ kubeconform -strict -summary examples/03-raw-manifests/manifests/
```

Observed output, from `./demo.sh offline`:

```text
Summary: 3 resources found in 3 files - Valid: 3, Invalid: 0, Errors: 0, Skipped: 0
```

## The cost of a second environment

Now make a staging copy. Copy the directory, change the namespace, set `DEPLOY_ENV` to `stage`, raise `replicas` to 2 and lower the log level. Do it once more for production with bigger resource limits. You now maintain nine files, and these things go wrong:

- **Duplicated structure.** A change to a probe path or the security context has to be made in every copy. Miss one and the environments drift without any error.
- **Values and structure in one file.** The three things that differ between environments (replicas, config, resources) sit inside a larger body that never differs. A reviewer has to diff whole files to find them.
- **No release.** `kubectl apply` has no record of which set of files produced the running state. Deleting a manifest from the directory does not delete the object, and there is no `rollback`.
- **No name for the group.** Nothing ties the ConfigMap, Deployment and Service together as one application, so installing, upgrading or removing the group is a loop in a shell script.

Tools such as `sed` or `envsubst` patch individual values, but they treat YAML as text and know nothing about types, defaults or validation. A chart replaces the copies with one set of templates, one `values.yaml` of defaults, and a per-environment file of overrides, and gives the group a release name and history. Chapter 04 builds that chart from these three files.

## What the cluster does with the objects

The Deployment does not run pods itself. It creates a ReplicaSet for the current pod template, and the ReplicaSet creates the pods. Edit the image tag in `deployment.yaml` and apply again: the Deployment creates a second ReplicaSet and shifts pods across, which is a rolling update, and the old ReplicaSet stays at zero replicas so `kubectl rollout undo` can return to it. The Service never changes; it matches pods by label and updates its endpoint list as readiness probes pass and fail. This is the machinery Helm drives in every later chapter. Helm adds no new Kubernetes behavior, only a way to produce and track these objects, so a Helm upgrade that changes the pod template triggers the same rolling update you can start by hand here. Watch it with `kubectl -n hfd-03 get rs -w` while you re-apply a changed manifest: the replica counts of the two ReplicaSets trade places one pod at a time, limited by the Deployment's default surge and unavailability settings.

## Cross-check

Compare what you applied with what the cluster stored. `kubectl get` returns the live object, including fields the API server defaulted:

```bash
[host]$ kubectl -n hfd-03 get deployment shipping-service -o yaml
```

Fields such as `terminationGracePeriodSeconds`, `dnsPolicy` and `progressDeadlineSeconds` appear in the output though your file never set them. They are defaults, not drift. The same distinction matters later when `helm diff` compares a release with a rendered manifest.

## What you learned

- The shipping service is configured entirely through environment variables, so a ConfigMap, a Deployment and a Service are the whole deployment.
- Probes, resource requests and a non-root security context belong in the manifest from the start, because every later chart inherits them.
- Copying manifests per environment multiplies files, hides the differences and leaves no release record.

Chapter 04 turns these three files into a chart named `shipping-service` and installs it as a release.

## Further reading

- Brendan Burns et al., *Kubernetes: Up and Running* (O'Reilly, 2022), ISBN 9781098110192. Used here for: Deployments, Services and ConfigMaps.
- Bilgin Ibryam, Roland Huß, *Kubernetes Patterns* (O'Reilly, 2023), ISBN 9781098131678. Used here for: the Health Probe, Predictable Demands and Managed Lifecycle patterns.
- William Denniss, *Kubernetes for Developers* (Manning, 2024), ISBN 9781617297175. Used here for: containerizing an application and configuring probes.
- Benjamin Muschko, *Certified Kubernetes Application Developer (CKAD) Study Guide* (O'Reilly, 2024), ISBN 9781098152857. Used here for: securityContext settings and probes.

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/03-raw-manifests.txt`. Observed on Helm 4.3.0: the manifests rolled out one ready pod, `/api/info` returned `storage: memory`, the pod ran with the non-root `securityContext` and a read-only root filesystem, and re-applying a changed image tag created a second ReplicaSet while the old one kept serving.*
