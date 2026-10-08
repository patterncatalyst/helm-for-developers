# 22 Plugins

Two Helm 4 `cli/v1` plugins, installed into an isolated plugin directory and run against a chart rendered locally.

- `plugins/helm-shipping-env/` is a subprocess plugin (`runtime: subprocess`). `helm shipping-env` prints the container env of every Deployment.
- `plugins/wasm-hello/` is an Extism plugin (`runtime: extism/v1`) written in Go and compiled with `GOOS=wasip1`.
- `chart/` is a self-contained copy of the `shipping-service` chart with its `pc-lib` dependency vendored.

## Run

    [host]$ ./demo.sh            # full run, no cluster needed
    [host]$ ./demo.sh offline    # same steps
    [host]$ ./demo.sh clean      # remove .tmp/ and plugin.wasm

Plugins install into `./.tmp/data/plugins` through `HELM_DATA_HOME` and `HELM_PLUGINS`. The project toolchain in `.tools/` is not modified. Go 1.25 or newer builds the Wasm module.

The demo also packages `helm-shipping-env` without a signature and shows that `helm plugin install` of the tarball fails until `--verify=false` is given.

## Against a cluster

The first form of the plugin reads a deployed release: install the chart into a namespace, then run `helm shipping-env RELEASE -n NAMESPACE` with the plugin installed. The demo does not do this; the S7 run did (`_plans/evidence/22-plugins.txt`).

## Verification status

`verified` on 2026-10-08 (`_plans/evidence/22-plugins.txt`): the demo ran end to end, the release form matched the `--chart` form on a deployed release, and the Wasm module rebuilt on an empty module cache.
