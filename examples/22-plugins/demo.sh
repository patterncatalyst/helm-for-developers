#!/usr/bin/env bash
#
# examples/22-plugins/demo.sh
#
#   ./demo.sh            # full run: lint, build Wasm, install into an isolated plugin dir, run, verify
#   ./demo.sh offline    # same steps; nothing here needs a cluster
#   ./demo.sh clean      # remove the isolated plugin dir (.tmp/) and the built plugin.wasm
#
# Plugins install into ./.tmp/data/plugins through HELM_DATA_HOME and HELM_PLUGINS, so the
# project toolchain in .tools/ is never modified.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/env.sh"

mode="${1:-all}"
if [[ "$mode" == clean ]]; then
  rm -rf .tmp
  make -C plugins/wasm-hello clean >/dev/null
  echo "clean: removed .tmp and plugins/wasm-hello/plugin.wasm"
  exit 0
fi
[[ "$mode" == all || "$mode" == offline ]] || { echo "usage: $0 [offline|clean]" >&2; exit 2; }

# Isolate plugin state. Helm 4.3 links local-directory installs under $HELM_DATA_HOME/plugins,
# so both variables point at the same directory.
export HELM_DATA_HOME="$SCRIPT_DIR/.tmp/data"
export HELM_PLUGINS="$HELM_DATA_HOME/plugins"
rm -rf .tmp
mkdir -p "$HELM_PLUGINS"

echo "== chart: build the pc-lib dependency, then lint"
helm dependency build chart >/dev/null
helm lint chart -f values-demo.yaml
helm template shipping chart -f values-demo.yaml >/dev/null

echo "== wasm-hello: build with GOOS=wasip1"
command -v go >/dev/null 2>&1 || { echo "go 1.25 or newer is required to build the Wasm plugin" >&2; exit 1; }
make -C plugins/wasm-hello
test -s plugins/wasm-hello/plugin.wasm

echo "== install both plugins from local directories"
helm plugin install plugins/helm-shipping-env
helm plugin install plugins/wasm-hello
helm plugin list

echo "== helm shipping-env --chart chart -f values-demo.yaml"
command helm shipping-env --chart chart -f values-demo.yaml | tee .tmp/shipping-env.out
grep -q '^API_TOKEN=<secret ' .tmp/shipping-env.out
grep -q '^OTEL_SERVICE_NAME=' .tmp/shipping-env.out

echo "== helm wasm-hello Helm4"
command helm wasm-hello Helm4 | tee .tmp/wasm.out
grep -q '^Hello, Helm4!' .tmp/wasm.out

echo "== signature policy: a packaged plugin without .prov"
mkdir -p .tmp/pkg
helm plugin package plugins/helm-shipping-env -d .tmp/pkg --sign=false
helm plugin uninstall shipping-env
if helm plugin install .tmp/pkg/shipping-env-0.1.0.tgz; then
  echo "expected the unsigned tarball install to fail" >&2; exit 1
fi
helm plugin install .tmp/pkg/shipping-env-0.1.0.tgz --verify=false
helm plugin list

echo "plugins stay installed under .tmp until ./demo.sh clean"
echo "OK"
