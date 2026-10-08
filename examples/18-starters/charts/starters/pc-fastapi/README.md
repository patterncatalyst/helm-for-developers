# pc-fastapi starter

A starter for `helm create`. It scaffolds a FastAPI chart on the `pc-lib` library chart.
`<CHARTNAME>` placeholders are replaced with the new chart's name.

    [host]$ helm create --starter $PWD/charts/starters/pc-fastapi charts/inventory-service
    [host]$ cat charts/inventory-service/pc-lib-dependency.yaml >> charts/inventory-service/Chart.yaml
    [host]$ helm dependency build charts/inventory-service

Helm rewrites `Chart.yaml` from its own defaults when it creates the chart, so the starter's
dependency block cannot ride along in `Chart.yaml`. It ships as
`pc-lib-dependency.yaml` and gets appended in the second step. The dependency is
`file://../pc-lib`, so create the chart inside `charts/` next to `pc-lib`.
