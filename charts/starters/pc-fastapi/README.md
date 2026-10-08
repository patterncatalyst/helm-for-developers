# pc-fastapi starter

A starter for the `helm create --starter` flag. It scaffolds a FastAPI chart on the `pc-lib` library chart.
`<CHARTNAME>` placeholders are replaced with the new chart's name.

    [host]$ helm create --starter $PWD/charts/starters/pc-fastapi charts/inventory-service
    [host]$ cat charts/inventory-service/pc-lib-dependency.yaml >> charts/inventory-service/Chart.yaml
    [host]$ helm dependency build charts/inventory-service

Scaffolding rewrites `Chart.yaml` from its own defaults, so the starter's
dependency block cannot ride along in `Chart.yaml`. It ships as
`pc-lib-dependency.yaml` and gets appended in the second step. The dependency is
`file://../pc-lib`, so create the chart inside `charts/` next to `pc-lib`.

## Testing the starter

`scripts/test-starter.sh` scaffolds a chart from this starter into a temporary directory beside a copy of `pc-lib`, lints it with `--strict`, and runs the helm-unittest suite in `scripts/starter-tests/`. The suite lives outside the starter so it is not copied into every scaffolded chart.
