#!/usr/bin/env bash
#
# publish-charts.sh - build the classic Helm chart repository served by GitHub Pages.
#
#   scripts/publish-charts.sh <outdir>
#
# Packages the reference charts bottom-up into <outdir>/charts/ and writes
# <outdir>/charts/index.yaml with absolute URLs under the Pages site. Needs Helm (4.x),
# curl and sha256sum on PATH; the charts' dependencies are file:// paths inside this repo.
# Override the URL for a local test with HFD_CHARTS_URL.
#
# Published versions are immutable (SemVer). Before building, the script downloads the
# repository that is live at the URL: its index.yaml and every archive the index lists.
# Versions that are not rebuilt now stay in the new repository, and the new index is
# built with `helm repo index --merge`. A chart version that is already published and
# would be republished with different bytes fails the build: bump the version in
# Chart.yaml instead. Unchanged charts package to identical bytes, so they pass.
# If the live index cannot be fetched, the script fails: a fresh index would drop
# every earlier version and could rewrite a published one. For the very first
# publish, set HFD_ALLOW_FRESH_INDEX=1.

set -euo pipefail

BASE_URL="${HFD_CHARTS_URL:-https://patterncatalyst.github.io/helm-for-developers/charts}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ $# -eq 1 ]] || { echo "usage: $0 <outdir>" >&2; exit 2; }
for t in helm curl sha256sum; do command -v "$t" >/dev/null 2>&1 || { echo "ERROR: $t not on PATH (helm: source scripts/env.sh)" >&2; exit 1; }; done

PREV="$(mktemp -d)"
NEW="$(mktemp -d)"
trap 'rm -rf "$PREV" "$NEW"' EXIT

have_prev=0
echo "==> fetching the published repository from $BASE_URL"
if curl -fsS --retry 2 --max-time 30 -o "$PREV/index.yaml" "$BASE_URL/index.yaml" 2>/dev/null; then
    have_prev=1
    # Archive names are the last path element of each `urls:` entry.
    while read -r f; do
        curl -fsS --retry 2 --max-time 60 -o "$PREV/$f" "$BASE_URL/$f" \
            || { echo "ERROR: index lists $f but it cannot be downloaded from $BASE_URL" >&2; exit 1; }
        echo "    kept published $f"
    done < <(grep -oE '[A-Za-z0-9._+-]+\.tgz$' "$PREV/index.yaml" | sort -u)
else
    rm -f "$PREV/index.yaml"
    if [[ "${HFD_ALLOW_FRESH_INDEX:-0}" != "1" ]]; then
        echo "ERROR: $BASE_URL/index.yaml cannot be fetched. Publishing a fresh index would drop" >&2
        echo "       earlier versions. Retry later, or set HFD_ALLOW_FRESH_INDEX=1 for a first publish." >&2
        exit 1
    fi
    echo "WARNING: HFD_ALLOW_FRESH_INDEX=1: building a fresh index without earlier versions." >&2
fi

# Dependencies first: pc-lib, then the service charts that use it, then the umbrella.
for c in pc-lib shipping-service notification-service shipping-postgres shipping-kafka shipping-platform; do
    echo "==> $c"
    helm dependency build "$ROOT/charts/$c" >/dev/null
    helm package "$ROOT/charts/$c" --destination "$NEW"
done

# Content digest of an archive: sha256 over the sorted per-file digests of its extracted
# tree, with nested subchart archives expanded first. `helm package` stores file
# modification times in the tar headers, so the same chart packaged from two checkouts
# differs in bytes but not in content.
content_digest() {
    local t; t="$(mktemp -d)"
    tar xzf "$1" -C "$t"
    local n
    while n="$(find "$t" -name '*.tgz' -print -quit)"; [[ -n "$n" ]]; do
        mkdir "${n%.tgz}.d" && tar xzf "$n" -C "${n%.tgz}.d" && rm -f "$n"
    done
    (cd "$t" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
    rm -rf "$t"
}

# Immutability guard: a published name-version keeps its content. Compare content
# digests; when they match, the published archive (and its index digest) is kept.
changed=0
for f in "$NEW"/*.tgz; do
    n="$(basename "$f")"
    [[ -f "$PREV/$n" ]] || continue
    a="$(content_digest "$f")"; b="$(content_digest "$PREV/$n")"
    if [[ "$a" != "$b" ]]; then
        echo "ERROR: $n is already published with different content (published $b, this build $a)." >&2
        echo "       A published version is never rewritten: bump 'version' in the chart's Chart.yaml." >&2
        changed=1
    else
        echo "    $n unchanged: keeping the published archive"
    fi
done
(( changed == 0 )) || exit 1

mkdir -p "$1"
OUT="$(cd "$1" && pwd)/charts"
rm -rf "$OUT"
mkdir -p "$OUT"
# Earlier versions first, then the archives that are new in this build.
cp --update=none "$PREV"/*.tgz "$OUT"/ 2>/dev/null || true
cp --update=none "$NEW"/*.tgz "$OUT"/

if (( have_prev )); then
    helm repo index "$OUT" --url "$BASE_URL" --merge "$PREV/index.yaml"
else
    helm repo index "$OUT" --url "$BASE_URL"
fi
echo "==> $OUT"
ls -1 "$OUT"
