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

The first form of the plugin reads a deployed release. With the `platform` release from chapter 16 in `hfd-26`, run `helm shipping-env platform -n hfd-26` with the plugin installed. The demo does not do this.

## Verification status

Unverified. A live run must confirm the forms in the chapter against a deployed release.
