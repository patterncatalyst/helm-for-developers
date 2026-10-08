#!/usr/bin/env bash
#
# examples/23-post-renderers/demo.sh
#
#   ./demo.sh            # full run: install the plugin into an isolated dir, render with and without it
#   ./demo.sh offline    # same steps; nothing here needs a cluster
#   ./demo.sh clean      # remove the isolated plugin dir (.tmp/)
#
# Needs kubectl on PATH (its built-in `kubectl kustomize`). Plugins install into
# ./.tmp/data/plugins, so the project toolchain in .tools/ is never modified.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/env.sh"
# shellcheck source=../../scripts/kube-context.sh
source "$REPO_ROOT/scripts/kube-context.sh"

mode="${1:-all}"
if [[ "$mode" == clean ]]; then rm -rf .tmp; echo "clean: removed .tmp"; exit 0; fi
[[ "$mode" == all || "$mode" == offline ]] || { echo "usage: $0 [offline|clean]" >&2; exit 2; }
type -P kubectl >/dev/null 2>&1 || { echo "kubectl is required for kubectl kustomize" >&2; exit 1; }

export HELM_DATA_HOME="$SCRIPT_DIR/.tmp/data"
export HELM_PLUGINS="$HELM_DATA_HOME/plugins"
rm -rf .tmp
mkdir -p "$HELM_PLUGINS"

echo "== chart: build the pc-lib dependency, then lint"
helm dependency build chart >/dev/null
helm lint chart -f values-demo.yaml

echo "== install the post-renderer plugin"
helm plugin install plugins/kustomize-postrender
helm plugin list

echo "== baseline render (no post-renderer)"
helm template shipping chart -f values-demo.yaml > .tmp/plain.yaml
echo "post-rendered lines: $(grep -c 'post-rendered' .tmp/plain.yaml || true)"
test "$(grep -c 'post-rendered' .tmp/plain.yaml || true)" -eq 0

echo "== render through the plugin, default argument"
helm template shipping chart -f values-demo.yaml --post-renderer kustomize-postrender > .tmp/default.yaml
grep -n 'post-rendered' .tmp/default.yaml
test "$(grep -c 'post-rendered: "true"' .tmp/default.yaml)" -ge 4

echo "== render through the plugin, --post-renderer-args staged"
helm template shipping chart -f values-demo.yaml --post-renderer kustomize-postrender --post-renderer-args staged > .tmp/staged.yaml
grep -n 'post-rendered' .tmp/staged.yaml
grep -q 'post-rendered: staged' .tmp/staged.yaml
grep -q 'post-rendered-by: kustomize-postrender' .tmp/staged.yaml

echo "== a path is not a plugin name in Helm 4"
script_path=./plugins/kustomize-postrender/postrender.sh
if helm template shipping chart -f values-demo.yaml --post-renderer "$script_path" >/dev/null 2>.tmp/path.err; then
  echo "expected the path form to be rejected" >&2; exit 1
fi
cat .tmp/path.err

helm plugin uninstall kustomize-postrender
echo "OK"
