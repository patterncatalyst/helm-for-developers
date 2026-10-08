#!/bin/sh
# helm shipping-env: effective container env per Deployment.
# Helm exports HELM_BIN, HELM_NAMESPACE and HELM_PLUGIN_DIR to subprocess plugins.
set -eu

helm_bin="${HELM_BIN:-helm}"
ns="${HELM_NAMESPACE:-}"
chart=""
release=""
vals=""

usage() {
  echo "usage: helm shipping-env RELEASE [-n NAMESPACE]" >&2
  echo "       helm shipping-env --chart DIR [-f VALUES]... [--release NAME]" >&2
  exit 2
}

[ $# -gt 0 ] || usage
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--namespace) ns="$2"; shift 2 ;;
    --chart) chart="$2"; shift 2 ;;
    -f|--values) vals="$vals -f $2"; shift 2 ;;
    --release) release="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "unknown flag: $1" >&2; usage ;;
    *) release="$1"; shift ;;
  esac
done

if [ -n "$chart" ]; then
  # shellcheck disable=SC2086
  manifest=$("$helm_bin" template "${release:-shipping}" "$chart" $vals)
else
  [ -n "$release" ] || usage
  manifest=$("$helm_bin" get manifest "$release" ${ns:+-n "$ns"})
fi

printf '%s\n' "$manifest" | awk '
  /^---/ { if (name != "") print name "=" val; name = ""; kind = ""; inenv = 0; secret = ""; name = ""; depname = ""; next }
  /^kind: / { kind = $2; next }
  kind == "Deployment" && /^  name: / && depname == "" { depname = $2; printf "# deployment/%s\n", depname; next }
  kind != "Deployment" { next }
  /^ +env:$/ { inenv = 1; next }
  inenv && /^ +envFrom:$/ { if (name != "") print name "=" val; name = ""; inenv = 0; next }
  inenv && /^ +[a-z]+Probe:$/ { if (name != "") print name "=" val; name = ""; inenv = 0; next }
  inenv && /^ +- name: / { if (name != "") print name "=" val; name = $3; gsub(/"/, "", name); val = ""; secret = ""; next }
  inenv && /^ +value: / { v = $0; sub(/^ +value: /, "", v); gsub(/^"|"$/, "", v); val = v; next }
  inenv && /^ +secretKeyRef:$/ { secret = "1"; sname = ""; next }
  inenv && secret != "" && /^ +name: / { sname = $2; next }
  inenv && secret != "" && /^ +key: / { val = "<secret " sname "/" $2 ">"; secret = ""; next }
  inenv && /^ +(envFrom|volumeMounts|resources|ports):/ { if (name != "") print name "=" val; name = ""; inenv = 0; next }
  END { if (name != "") print name "=" val }
'
