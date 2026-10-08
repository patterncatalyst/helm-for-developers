# Helpers and NOTES

Snapshot for chapter 07 ([Helpers and NOTES.txt](../../_docs/07-helpers-and-notes.md)). Release `shipping`, namespace `hfd-07`, in-memory storage.

Version 0.7.0 adds `templates/_helpers.tpl` (name, fullname, labels, selector labels), `templates/NOTES.txt` and `files/support.txt` read with `.Files.Get`.

## Run

```bash
./demo.sh           # offline checks, then a live install on the helm4dev cluster
./demo.sh offline   # no cluster: lint, template, kubeconform, fullname rules and the rendered NOTES
./demo.sh clean     # remove the release and namespace
```

The live run builds `shipping-service:0.1.0` with `scripts/build-images.sh` and reaches the service on the published NodePort at http://127.0.0.1:30080. Source `scripts/env.sh` first if you run commands by hand; it selects the project-local Helm 4.3.0.

## Verification status

`verified` on 2026-10-08 (`_plans/evidence/07-helpers-notes.txt`): `helm get notes` printed the notes, the Service had one endpoint, every resource carried the recommended labels, a 54-character release name was rejected, and a chart `version` bump rolled the pods. Re-run on r1.1 with published NodePorts on 2026-10-08 (helm4dev recreated with `HFD_NODE_PORTS`, host requests at `http://127.0.0.1:30080`, no tunnel); the behaviour above held.