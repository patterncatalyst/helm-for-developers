# Configuration and secrets

Snapshot for chapter 08 ([Configuration and secrets](../../_docs/08-config-and-secrets.md)). Release `shipping`, namespace `hfd-08`, in-memory storage.

Version 0.8.0 adds the `API_TOKEN` Secret (`auth.token`, `auth.generate`, `auth.existingSecret`), the `checksum/config` pod annotation and a `lookup` that keeps a generated token across upgrades.

## Run

```bash
./demo.sh           # offline checks, a live install on the helm4dev cluster, then the SOPS exercise
./demo.sh offline   # no cluster: lint, template, kubeconform, Secret, existingSecret and checksum assertions
./demo.sh sops      # SOPS + age + helm-secrets: encrypt, render, negative controls, live install (needs network and the cluster)
./demo.sh clean     # remove the release and namespace, and delete .work/
```

The live run builds `shipping-service:0.1.0` with `scripts/build-images.sh` and reaches the service through `scripts/tunnel.sh` at http://127.0.0.1:8080. Source `scripts/env.sh` first if you run commands by hand; it selects the project-local Helm 4.3.0.

## Verification status

`verified` on 2026-10-08 (`_plans/evidence/08-config-secrets.txt`, `_plans/evidence/08-config-secrets-sops.txt`): Writes returned 401 without the token and 201 with it, a ConfigMap change replaced the pods, `auth.generate=true` kept the same token across an upgrade, `existingSecret` rendered no Secret and authenticated with its value, and `helm get values` printed the token. With sops 3.13.3, age 1.3.2 and helm-secrets 4.7.9, `./demo.sh sops` decrypted `secrets.dev.yaml` through `-f secrets://` and `helm secrets template`, delivered the value to the Secret in `hfd-08`, and failed with a wrong key. The plugins live in `.tools/helm/plugins-secrets` and the throwaway key in `.work/` (gitignored); no private key is committed.
