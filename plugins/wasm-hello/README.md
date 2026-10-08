# wasm-hello

A Helm 4 `cli/v1` plugin on the Extism (`extism/v1`) runtime, written with the Go PDK.

Build and run:

    [host]$ make -C plugins/wasm-hello
    [host]$ helm wasm-hello Helm4

Status: built and run with Go 1.26.8 (`GOOS=wasip1 GOARCH=wasm go build -buildmode=c-shared`)
against Helm 4.3.0; prints `Hello, Helm4! (from a Wasm Helm plugin)`.

Notes from getting it to run:

- The runtime name in `plugin.yaml` is `extism/v1`, and the module must be named `plugin.wasm`
  in the plugin directory.
- The module must export `helm_plugin_main` (`//go:wasmexport`) and return `{}` as JSON output;
  text goes to WASI stdout.
- `runtimeConfig.memory.maxPages` of 16 fails with `section memory: min 42 pages (2 Mi) over
  limit of 16 pages (1 Mi)`; a Go Wasm module needs at least 42 pages, so the plugin sets 256.
- `ignoreFlags: true` drops the command-line arguments (`extraArgs` stays empty); use `false`
  to receive them.
- `helm plugin install <dir>` of a local directory on Helm 4.3.0 links it under
  `$HELM_DATA_HOME/plugins`, not `$HELM_PLUGINS`; symlink it into `$HELM_PLUGINS` when the two differ.
