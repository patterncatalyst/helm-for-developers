# Helpers and NOTES

Snapshot for chapter 07 ([Helpers and NOTES.txt](../../_docs/07-helpers-and-notes.md)). Release `shipping`, namespace `hfd-07`, in-memory storage.

Version 0.7.0 adds `templates/_helpers.tpl` (name, fullname, labels, selector labels), `templates/NOTES.txt` and `files/support.txt` read with `.Files.Get`.

## Run

```bash
./demo.sh           # offline checks, then a live install on the helm4dev cluster
./demo.sh offline   # no cluster: lint, template, kubeconform, fullname rules and the rendered NOTES
./demo.sh clean     # remove the release and namespace
```

The live run builds `shipping-service:0.1.0` with `scripts/build-images.sh` and reaches the service through `scripts/tunnel.sh` at http://127.0.0.1:8080. Source `scripts/env.sh` first if you run commands by hand; it selects the project-local Helm 4.3.0.

## Verification status

unverified. A live run must confirm: `helm get notes` prints the NOTES and every resource carries the recommended labels.
