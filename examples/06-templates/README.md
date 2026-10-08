# Templates

Snapshot for chapter 06 ([Templates](../../_docs/06-templates.md)). Release `shipping`, namespace `hfd-06`, in-memory storage.

Version 0.6.0 adds `required`, `with`, `range`, `tpl`, variables and a conditional `nodePort`, driven by `imagePullSecrets`, `podAnnotations` and `extraEnv` values.

## Run

```bash
./demo.sh           # offline checks, then a live install on the helm4dev cluster
./demo.sh offline   # no cluster: lint, template, kubeconform, `required`, `tpl` and `with` assertions
./demo.sh clean     # remove the release and namespace
```

The live run builds `shipping-service:0.1.0` with `scripts/build-images.sh` and reaches the service through `scripts/tunnel.sh` at http://127.0.0.1:8080. Source `scripts/env.sh` first if you run commands by hand; it selects the project-local Helm 4.3.0.

## Verification status

unverified. A live run must confirm: the `tpl`-rendered annotation appears on the running pod.
