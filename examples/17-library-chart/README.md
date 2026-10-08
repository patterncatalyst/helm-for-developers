# 17 Library charts

Snapshot for chapter 17 (`_docs/17-library-charts.md`). `charts/pc-lib` is a `type: library` chart; `shipping-service` and `notification-service` depend on it with `file://../pc-lib`. This directory matches the final chart structure. Chart versions are `0.17.0`.

`before/` holds the chapter 16 versions of both services (version `0.16.0`) with helpers copied into each chart. `./demo.sh offline` renders both and diffs them; the only differences filtered out are the `helm.sh/chart` label and `checksum/config`.

## Run

    [host]$ ./demo.sh offline   # build deps, lint, unittest, library not installable, line counts, rendered diff, kubeconform
    [host]$ ./demo.sh           # offline checks, install release platform into hfd-17, helm test
    [host]$ ./demo.sh clean

## Verification status

unverified. A live run must confirm: release `platform` installs from the library-based charts, and the Deployments and Services carry `patterncatalyst.io/domain`, `owner` and `data-product`.
