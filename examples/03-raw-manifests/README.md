# Raw manifests

Snapshot for chapter 03 ([The shipping service as raw manifests](../../_docs/03-shipping-service-raw-manifests.md)). Release `shipping`, namespace `hfd-03`, in-memory storage.

`manifests/` holds a ConfigMap, a Deployment and a Service for shipping-service with in-memory storage. There is no chart: names, image tag and values are literals.

## Run

```bash
./demo.sh           # offline checks, then a live install on the helm4dev cluster
./demo.sh offline   # no cluster: kubeconform on the three manifests
./demo.sh clean     # remove the release and namespace
```

The live run builds `shipping-service:0.1.0` with `scripts/build-images.sh` and reaches the service on the published NodePort at http://127.0.0.1:30080. Source `scripts/env.sh` first if you run commands by hand; it selects the project-local Helm 4.3.0.

## Verification status

`verified` on 2026-10-08 (`_plans/evidence/03-raw-manifests.txt`): The manifests rolled out one ready pod, `/api/info` returned `storage: memory`, the pod ran with the non-root `securityContext` and a read-only root filesystem, and re-applying a changed image tag created a second ReplicaSet while the old one kept serving.