#!/bin/sh
# Post-renderer: Helm writes the rendered manifests to stdin, this script writes the
# modified manifests to stdout. It adds a label to every object and an annotation to
# every Deployment pod template with `kubectl kustomize`.
#
# Optional argument (helm --post-renderer-args): the label value, default "true".
set -eu

label_value="${1:-true}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat > "$work/all.yaml"

cat > "$work/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - all.yaml
labels:
  - pairs:
      patterncatalyst.io/post-rendered: "${label_value}"
    includeSelectors: false
patches:
  - target:
      kind: Deployment
    patch: |-
      - op: add
        path: /spec/template/metadata/annotations/patterncatalyst.io~1post-rendered-by
        value: kustomize-postrender
EOF

kubectl kustomize "$work"
