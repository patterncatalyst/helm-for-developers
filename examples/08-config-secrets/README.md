# Configuration and secrets

Snapshot for chapter 08 ([Configuration and secrets](../../_docs/08-config-and-secrets.md)). Release `shipping`, namespace `hfd-08`, in-memory storage.

Version 0.8.0 adds the `API_TOKEN` Secret (`auth.token`, `auth.generate`, `auth.existingSecret`), the `checksum/config` pod annotation and a `lookup` that keeps a generated token across upgrades.

## Run

```bash
./demo.sh           # offline checks, then a live install on the helm4dev cluster
./demo.sh offline   # no cluster: lint, template, kubeconform, Secret, existingSecret and checksum assertions
./demo.sh clean     # remove the release and namespace
```

The live run builds `shipping-service:0.1.0` with `scripts/build-images.sh` and reaches the service through `scripts/tunnel.sh` at http://127.0.0.1:8080. Source `scripts/env.sh` first if you run commands by hand; it selects the project-local Helm 4.3.0.

## Verification status

unverified. A live run must confirm: writes return 401 without the token and 201 with it, a ConfigMap change replaces the pods, and a generated token survives `helm upgrade`.
