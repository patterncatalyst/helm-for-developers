# kustomize-postrender

A `postrenderer/v1` subprocess plugin. Helm 4 accepts post-renderers only as plugins, by name:

    [host]$ helm template platform charts/shipping-platform -f charts/shipping-platform/values-dev.yaml --post-renderer kustomize-postrender
    [host]$ helm template platform charts/shipping-platform --post-renderer kustomize-postrender --post-renderer-args staged

It pipes the rendered manifests through `kubectl kustomize`, adds the label
`patterncatalyst.io/post-rendered=<arg or true>` to every object, and adds the pod-template
annotation `patterncatalyst.io/post-rendered-by=kustomize-postrender` to every Deployment.
`kubectl` with a built-in kustomize must be on PATH.
