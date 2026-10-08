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

`verified` on 2026-10-08 (`_plans/evidence/23-post-renderers.txt`): the demo ran end to end and a live `helm install --post-renderer kustomize-postrender` put the label on the live objects and in the stored manifest. Re-run on r1.1 with published NodePorts (bound to 127.0.0.1) on 2026-10-08: `./demo.sh` exited 0 and `./demo.sh clean` removed the namespace; the post-renderer plugin annotated the rendered objects and the path form was rejected as documented.
