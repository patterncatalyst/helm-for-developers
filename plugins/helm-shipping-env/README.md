# helm-shipping-env

A `cli/v1` subprocess plugin. It prints the container env of every Deployment in a release.

    [host]$ helm shipping-env platform -n hfd-20
    [host]$ helm shipping-env --chart charts/shipping-platform -f charts/shipping-platform/values-dev.yaml --release platform

The first form reads `helm get manifest`; the second renders locally and needs no cluster.
Secret references print as `<secret NAME/KEY>`. Values that arrive through `envFrom` (the
ConfigMap) are not expanded.

Helm passes command-line arguments to a `cli/v1` plugin only when `ignoreFlags: false`.
