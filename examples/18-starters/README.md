# 18 Starters and golden paths

Snapshot for chapter 18 (`_docs/18-starters-golden-paths.md`). `charts/starters/pc-fastapi` is the starter; `charts/pc-lib` (version `0.18.0`) is the library it depends on.

The starter ships its dependency block as `pc-lib-dependency.yaml` because `helm create` rewrites `Chart.yaml`. Differences from a plain copy of the library-based service charts: the test pod probes with Python from the chart's own image (`tests.image: ""`), and the schema allows an empty `tests.image`.

## Run

    [host]$ ./demo.sh offline   # starter into $HELM_DATA_HOME/starters, helm create --starter, append dependency, lint, template, kubeconform
    [host]$ ./demo.sh           # offline checks, install the generated chart into hfd-18 using the shipping image
    [host]$ ./demo.sh clean     # also removes the starter from $HELM_DATA_HOME/starters

`HELM_DATA_HOME` is project-local (`scripts/env.sh`). The generated chart lives in a temporary directory.

## Verification status

`verified` on 2026-10-08 (Helm 4.3.0, minikube `helm4dev`), evidence `_plans/evidence/18-starters.txt`. The full demo exits 0: the generated chart installs and its `helm test` pod passes against the shipping image. Re-run on r1.1 with published NodePorts (bound to 127.0.0.1) on 2026-10-08: `./demo.sh` exited 0 and `./demo.sh clean` removed the namespace; the starter-generated chart rendered and installed.
