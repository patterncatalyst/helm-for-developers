# Raw manifests

Snapshot for chapter 03 ([The shipping service as raw manifests](../../_docs/03-shipping-service-raw-manifests.md)). Release `shipping`, namespace `hfd-03`, in-memory storage.

`manifests/` holds a ConfigMap, a Deployment and a Service for shipping-service with in-memory storage. There is no chart: names, image tag and values are literals.

## Run

```bash
./demo.sh           # offline checks, then a live install on the helm4dev cluster
./demo.sh offline   # no cluster: kubeconform on the three manifests
./demo.sh clean     # remove the release and namespace
```

The live run builds `shipping-service:0.1.0` with `scripts/build-images.sh` and reaches the service through `scripts/tunnel.sh` at http://127.0.0.1:8080. Source `scripts/env.sh` first if you run commands by hand; it selects the project-local Helm 4.3.0.

## Verification status

unverified. A live run must confirm: `kubectl apply` rolls out one ready pod and `/api/info` returns `storage: memory`.
