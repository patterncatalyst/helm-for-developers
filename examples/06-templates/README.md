# Templates

Snapshot for chapter 06 ([Templates](../../_docs/06-templates.md)). Release `shipping`, namespace `hfd-06`, in-memory storage.

Version 0.6.0 adds `required`, `with`, `range`, `tpl`, variables and a conditional `nodePort`, driven by `imagePullSecrets`, `podAnnotations` and `extraEnv` values.

## Run

```bash
./demo.sh           # offline checks, then a live install on the helm4dev cluster
./demo.sh offline   # no cluster: lint, template, kubeconform, `required`, `tpl` and `with` assertions
./demo.sh clean     # remove the release and namespace
```

The live run builds `shipping-service:0.1.0` with `scripts/build-images.sh` and reaches the service on the published NodePort at http://127.0.0.1:30080. Source `scripts/env.sh` first if you run commands by hand; it selects the project-local Helm 4.3.0.

## Verification status

`verified` on 2026-10-08 (`_plans/evidence/06-templates.txt`): The `tpl` annotation reached the running pod with the install namespace, `required` fired only with schema validation skipped, and `lookup` returned an empty map under `helm template` and `--dry-run=client` but the live object under `--dry-run=server` (observed with the chapter 08 chart, `_plans/evidence/08-config-secrets.txt`).