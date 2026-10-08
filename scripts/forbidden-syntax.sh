#!/usr/bin/env bash
#
# forbidden-syntax.sh - fail on Helm 3 idioms and terms the tutorial must not use.
#
# Searches _docs/ examples/ charts/ presentation/*/deck.js for:
#   --atomic                          (Helm 4: --rollback-on-failure)
#   helm upgrade ... --force          (Helm 4: --force-replace)
#   --post-renderer <path>            (post-renderers are plugins in Helm 4)
#   tiller, helm init, requirements.yaml, helm serve
#   apiVersion: v1 in any Chart.yaml  (charts are apiVersion: v2)
#
# Exemptions: any line containing `<!-- helm3-reference -->`, and every hit in
# _docs/28-appendix-helm3-to-helm4.md. ROOT_DIR overrides the repo root.
# An empty tree passes.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ROOT_DIR:-$(cd "$HERE/.." && pwd)}"
cd "$ROOT" || exit 1

targets=()
for t in _docs examples charts; do [[ -e "$t" ]] && targets+=("$t"); done
for d in presentation/*/deck.js; do [[ -f "$d" ]] && targets+=("$d"); done
if [[ ${#targets[@]} -eq 0 ]]; then
    echo "forbidden-syntax: nothing to scan yet"; exit 0
fi

fail=0
scan() { # <label> <ERE> [--include glob...]
    local label="$1" re="$2"; shift 2
    local hits
    hits="$(grep -rnIE "$@" -e "$re" "${targets[@]}" 2>/dev/null \
        | grep -v '<!-- helm3-reference -->' \
        | grep -v '^_docs/28-appendix-helm3-to-helm4\.md:' || true)"
    if [[ -n "$hits" ]]; then
        printf 'forbidden-syntax: %s\n' "$label"
        printf '%s\n' "$hits" | sed 's/^/    /'
        fail=1
    fi
}

scan 'Helm 3 flag --atomic (use --rollback-on-failure)'      '--atomic'
scan 'helm upgrade with --force (use --force-replace)'       'helm upgrade .*--force( |$)'
scan '--post-renderer with a path (use a postrenderer plugin)' '--post-renderer [./~]'
scan 'Helm 2 term tiller'                                    '\btiller\b' -i
scan 'Helm 2 command helm init'                              'helm init\b'
scan 'Helm 2 file requirements.yaml'                         'requirements\.yaml'
scan 'Helm 2 command helm serve'                             'helm serve\b'

# apiVersion: v1 in any Chart.yaml
cy="$(find "${targets[@]}" -type f -name Chart.yaml 2>/dev/null | sort)"
if [[ -n "$cy" ]]; then
    hits="$(xargs grep -nHE '^apiVersion:[[:space:]]*"?v1"?[[:space:]]*$' <<<"$cy" 2>/dev/null \
        | grep -v '<!-- helm3-reference -->' || true)"
    if [[ -n "$hits" ]]; then
        echo 'forbidden-syntax: Chart.yaml with apiVersion: v1 (use v2)'
        printf '%s\n' "$hits" | sed 's/^/    /'; fail=1
    fi
fi

if (( fail )); then exit 1; fi
echo "forbidden-syntax: OK"
