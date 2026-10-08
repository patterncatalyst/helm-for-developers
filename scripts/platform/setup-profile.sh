#!/usr/bin/env bash
#
# setup-profile.sh - create (or start) the minikube profile "helm4dev".
#
#   scripts/platform/setup-profile.sh
#       Create the profile if missing, start it if stopped, otherwise do nothing.
#   scripts/platform/setup-profile.sh --replace --confirm=helm4dev
#       Delete the helm4dev profile and recreate it. Both flags are required.
#
# Driver docker, runtime containerd, 12g RAM, 8 CPUs, registry addon enabled.
# Every port in HFD_NODE_PORTS (scripts/platform/lib.sh) is published to
# 127.0.0.1 with --ports, so host access needs no tunnel or port-forward.   # forbidden-ok
# An existing profile whose published ports differ is refused: ports are fixed
# at creation, so recreate it with --replace --confirm=helm4dev.
# This script refuses to operate on any profile other than helm4dev.
# Override sizing with MINIKUBE_MEMORY, MINIKUBE_CPUS, MINIKUBE_DISK,
# MINIKUBE_DRIVER, MINIKUBE_RUNTIME.

set -euo pipefail
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

MEMORY="${MINIKUBE_MEMORY:-12g}"
CPUS="${MINIKUBE_CPUS:-8}"
DISK="${MINIKUBE_DISK:-60g}"
RUNTIME="${MINIKUBE_RUNTIME:-containerd}"
DRIVER="${MINIKUBE_DRIVER:-docker}"

REPLACE=0; CONFIRMED=0
for arg in "$@"; do
    case "$arg" in
        --replace)           REPLACE=1 ;;
        --confirm=helm4dev)  CONFIRMED=1 ;;
        -h|--help)           sed -n '3,18p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *)                   fail "unknown argument: $arg (this script only manages the $PROFILE profile)" ;;
    esac
done
if (( REPLACE )) && (( ! CONFIRMED )); then
    fail "--replace deletes the $PROFILE profile. Re-run with: --replace --confirm=helm4dev"
fi
if (( CONFIRMED )) && (( ! REPLACE )); then
    fail "--confirm=helm4dev is only meaningful together with --replace"
fi

require_tools minikube kubectl helm
case "$DRIVER" in
    docker) require_tools docker ;;
    podman) require_tools podman ;;
esac

# ─── Pre-flight: kernel limits ──────────────────────────────────────────────
inotify_instances=$(sysctl -n fs.inotify.max_user_instances 2>/dev/null || echo 0)
if (( inotify_instances < 256 )); then
    printf 'ERROR: fs.inotify.max_user_instances is %d (need >= 256).\n' "$inotify_instances" >&2
    printf '  sudo tee /etc/sysctl.d/99-kubernetes.conf <<EOF\n  fs.inotify.max_user_instances = 512\n  fs.inotify.max_user_watches = 524288\n  EOF\n' >&2
    printf '  sudo sysctl -p /etc/sysctl.d/99-kubernetes.conf\n' >&2
    exit 1
fi

# ─── Pre-flight: other minikube profiles compete for RAM ────────────────────
others=$(minikube profile list -o json 2>/dev/null | python3 -c '
import json, sys
try:
    for p in json.load(sys.stdin).get("valid", []):
        if p["Name"] != "helm4dev" and p.get("Status") == "Running":
            print(p["Name"])
except Exception:
    pass
' 2>/dev/null || true)
if [[ -n "$others" ]]; then
    printf 'WARNING: other minikube profiles are running and compete for RAM (they are not modified):\n' >&2
    printf '%s\n' "$others" | sed 's/^/  - /' >&2
    if [[ -t 0 ]]; then
        printf 'Continue anyway? [y/N] ' >&2; read -r answer
        [[ "$answer" =~ ^[Yy] ]] || exit 1
    elif [[ "${ALLOW_OTHER_PROFILES:-0}" != "1" ]]; then
        fail "non-interactive run with other profiles running. Stop them yourself or set ALLOW_OTHER_PROFILES=1."
    fi
fi

profile_exists() {
    minikube profile list -o json 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
sys.exit(0 if any(p["Name"] == "helm4dev" for p in d.get("valid", []) + d.get("invalid", [])) else 1)
' 2>/dev/null
}

PORTS_ARG=""
for _p in "${HFD_NODE_PORTS[@]}"; do PORTS_ARG+="${PORTS_ARG:+,}${_p}:${_p}"; done

# Host ports currently published by the node container, one per line, sorted.
published_ports() {
    "$DRIVER" inspect -f '{{json .HostConfig.PortBindings}}' "$PROFILE" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin) or {}
except Exception:
    d = {}
ports = set()
for binds in d.values():
    for b in binds or []:
        if b.get("HostPort"):
            ports.add(int(b["HostPort"]))
print("\n".join(str(p) for p in sorted(ports)))
' 2>/dev/null
}

# Refuse to reuse a profile whose published ports differ from HFD_NODE_PORTS.
check_published_ports() {
    local have want missing
    have="$(published_ports | tr '\n' ' ')"
    want="$(printf '%s\n' "${HFD_NODE_PORTS[@]}" | sort -n | tr '\n' ' ')"
    missing="$(comm -13 <(published_ports | sort) <(printf '%s\n' "${HFD_NODE_PORTS[@]}" | sort) | tr '\n' ' ')"
    if [[ -n "$missing" ]]; then
        printf 'ERROR: profile %s does not publish these host ports: %s\n' "$PROFILE" "$missing" >&2
        printf '  published: %s\n  required:  %s\n' "${have:-none}" "$want" >&2
        printf '  Ports are fixed at profile creation. Recreate the profile:\n' >&2
        printf '  scripts/platform/setup-profile.sh --replace --confirm=helm4dev\n' >&2
        exit 1
    fi
}

if profile_exists; then
    if (( ! REPLACE )); then check_published_ports; fi
    if (( REPLACE )); then
        step "Deleting profile $PROFILE (--replace --confirm=helm4dev)"
        minikube delete -p "$PROFILE"
    elif minikube status -p "$PROFILE" >/dev/null 2>&1; then
        step "Profile $PROFILE already running"
        ok "nothing to do"
        kc get nodes
        exit 0
    else
        step "Profile $PROFILE exists but is stopped; starting it"
    fi
fi

step "Publishing NodePorts to 127.0.0.1: $PORTS_ARG"
step "Starting $PROFILE ($MEMORY RAM, $CPUS CPUs, $DISK disk, $DRIVER driver, $RUNTIME runtime)"
minikube start -p "$PROFILE" \
    --driver="$DRIVER" \
    --container-runtime="$RUNTIME" \
    --memory="$MEMORY" \
    --cpus="$CPUS" \
    --disk-size="$DISK" \
    --ports="$PORTS_ARG" \
    --addons=metrics-server

step "Enabling the registry addon"
minikube addons enable registry -p "$PROFILE"
ok "registry reachable from the host at 127.0.0.1:5000 (published node port)"

step "Verifying cluster health"
kc get nodes
kc get pods -n kube-system

printf '\nProfile %s is ready (kubectl context: %s).\n' "$PROFILE" "$PROFILE"
printf 'Next: scripts/platform/bootstrap.sh\n'
