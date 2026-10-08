# 23 Post-renderers

A `postrenderer/v1` plugin that pipes the rendered manifests through `kubectl kustomize`. It adds a label to every object and an annotation to every Deployment pod template.

- `plugins/kustomize-postrender/` holds `plugin.yaml` and `postrender.sh`.
- `chart/` is a self-contained copy of the `shipping-service` chart with its `pc-lib` dependency vendored.

## Run

    [host]$ ./demo.sh            # full run, no cluster needed
    [host]$ ./demo.sh offline    # same steps
    [host]$ ./demo.sh clean      # remove .tmp/

Needs `kubectl` on PATH. The plugin installs into `./.tmp/data/plugins` through `HELM_DATA_HOME` and `HELM_PLUGINS`; `.tools/` is not modified.

The demo renders the chart three ways (no post-renderer, default argument, `--post-renderer-args staged`) and checks that a script path is rejected by `--post-renderer`.

## Verification status

Unverified. A live `helm install` with `--post-renderer kustomize-postrender` must confirm the label lands on the live objects.
